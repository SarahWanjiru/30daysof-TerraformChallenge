provider "aws" {
  region = var.region
}

# -----------------------------------------------
# locals — ALL conditional logic lives here
# Resources read from locals — never raw ternaries
# is_production is the single source of truth
# -----------------------------------------------
locals {
  is_production = var.environment == "production"

  # Instance sizing — production gets larger instance automatically
  actual_instance_type = local.is_production ? "t3.small" : var.instance_type

  # Cluster sizing — production runs more instances
  actual_min_size = local.is_production ? 3 : var.min_size
  actual_max_size = local.is_production ? 10 : var.max_size

  # Monitoring — always enabled in production
  actual_monitoring = local.is_production ? true : var.enable_detailed_monitoring
}

# -----------------------------------------------
# Conditional data source — brownfield pattern
# use_existing_vpc = true  → use existing default VPC
# use_existing_vpc = false → still use default VPC
# This shows the pattern even with default VPC
# -----------------------------------------------
data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Security group for EC2 instances
resource "aws_security_group" "instance_sg" {
  name        = "${var.cluster_name}-instance-sg"
  description = "Allow HTTP traffic to EC2 instances"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = var.server_port
    to_port     = var.server_port
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Security group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "${var.cluster_name}-alb-sg"
  description = "Allow HTTP traffic to ALB"
  vpc_id      = data.aws_vpc.default.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Launch Template — uses local.actual_instance_type
# production automatically gets t3.small
# dev gets whatever instance_type is passed
resource "aws_launch_template" "web" {
  name_prefix            = "${var.cluster_name}-"
  image_id               = var.ami
  instance_type          = local.actual_instance_type
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from ${var.cluster_name}! Env: ${var.environment}</h1>" > /var/www/html/index.html
EOF
  )
}

# Auto Scaling Group — uses local sizes
# production: min=3, max=10
# dev: min=var.min_size, max=var.max_size
resource "aws_autoscaling_group" "web" {
  name                = "${var.cluster_name}-asg"
  vpc_zone_identifier = data.aws_subnets.default.ids
  min_size            = local.actual_min_size
  max_size            = local.actual_max_size
  desired_capacity    = local.actual_min_size
  target_group_arns   = [aws_lb_target_group.web.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-instance"
    propagate_at_launch = true
  }
}

# Autoscaling policies — count = 0 when disabled
resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# -----------------------------------------------
# CloudWatch alarm — conditional resource
# count = 1 → alarm created
# count = 0 → alarm skipped entirely
# Uses local.actual_monitoring so production
# always gets monitoring regardless of variable
# -----------------------------------------------
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = local.actual_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeded 80% on ${var.cluster_name}"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}

# ALB
resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

# Target Group
resource "aws_lb_target_group" "web" {
  name     = "${var.cluster_name}-tg"
  port     = var.server_port
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id

  health_check {
    path                = "/"
    port                = var.server_port
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }
}

# ALB Listener
resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.web.arn
  }
}
