provider "aws" {
  region = var.region
}

# all conditional logic lives here — resources read from locals, never raw ternaries
locals {
  is_production        = var.environment == "production"
  actual_instance_type = local.is_production ? "t3.small" : var.instance_type
  actual_min_size      = local.is_production ? 3 : var.min_size
  actual_max_size      = local.is_production ? 10 : var.max_size
  actual_monitoring    = local.is_production ? true : var.enable_detailed_monitoring
}

data "aws_vpc" "default" {
  default = true
}

data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

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

# name_prefix lets old and new templates coexist during updates — create_before_destroy reverses destroy order so new instances are healthy before old ones are removed
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
echo "<h1>Hello from ${var.cluster_name} — ${var.app_version} — $(hostname)</h1>" > /var/www/html/index.html
EOF
  )

  lifecycle {
    create_before_destroy = true
  }
}

# name_prefix generates a unique ASG name each deploy so old and new can coexist — required for create_before_destroy to work
resource "aws_autoscaling_group" "web" {
  name_prefix         = "${var.cluster_name}-"
  vpc_zone_identifier = data.aws_subnets.default.ids
  min_size            = local.actual_min_size
  max_size            = local.actual_max_size
  desired_capacity    = local.actual_min_size
  target_group_arns   = [
    var.active_environment == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  ]
  health_check_type = "ELB"

  launch_template {
    id      = aws_launch_template.web.id
    version = "$Latest"
  }

  lifecycle {
    create_before_destroy = true
  }

  tag {
    key                 = "Name"
    value               = "${var.cluster_name}-${var.app_version}"
    propagate_at_launch = true
  }
}

resource "aws_autoscaling_policy" "scale_out" {
  count                  = var.enable_autoscaling ? 1 : 0
  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  count                  = var.enable_autoscaling ? 1 : 0
  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = local.actual_monitoring ? 1 : 0
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

resource "aws_lb" "web" {
  name               = "${var.cluster_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = data.aws_subnets.default.ids
}

# blue and green target groups both exist — active_environment controls which one receives traffic
resource "aws_lb_target_group" "blue" {
  name     = "${var.cluster_name}-blue-tg"
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

resource "aws_lb_target_group" "green" {
  name     = "${var.cluster_name}-green-tg"
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

resource "aws_lb_listener" "web" {
  load_balancer_arn = aws_lb.web.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = var.active_environment == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  }
}

# changing active_environment and running terraform apply shifts all traffic in a single API call — no downtime
resource "aws_lb_listener_rule" "blue_green" {
  listener_arn = aws_lb_listener.web.arn
  priority     = 100

  action {
    type             = "forward"
    target_group_arn = var.active_environment == "blue" ? aws_lb_target_group.blue.arn : aws_lb_target_group.green.arn
  }

  condition {
    path_pattern {
      values = ["/*"]
    }
  }
}
