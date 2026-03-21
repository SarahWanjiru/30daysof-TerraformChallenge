provider "aws" {
  region = var.region
}

# Data blocks
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_ami" "amazon_linux" {
  most_recent = true

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  owners = ["amazon"]
}

# VPC
resource "aws_vpc" "day5vpc" {
  cidr_block           = var.vpc_cidr
  enable_dns_hostnames = true
  enable_dns_support   = true
  tags = {
    Name = "day5VPC"
  }
}

# Public Subnet 1
resource "aws_subnet" "day5publicsubnet1" {
  vpc_id                  = aws_vpc.day5vpc.id
  cidr_block              = var.public_subnet_cidr
  availability_zone       = data.aws_availability_zones.available.names[0]
  map_public_ip_on_launch = true
  tags = {
    Name = "day5PublicSubnet1"
  }
}

# Public Subnet 2 — ALB needs at least 2 subnets in different AZs
resource "aws_subnet" "day5publicsubnet2" {
  vpc_id                  = aws_vpc.day5vpc.id
  cidr_block              = var.public_subnet_cidr2
  availability_zone       = data.aws_availability_zones.available.names[1]
  map_public_ip_on_launch = true
  tags = {
    Name = "day5PublicSubnet2"
  }
}

# Internet Gateway
resource "aws_internet_gateway" "day5igw" {
  vpc_id = aws_vpc.day5vpc.id
  tags = {
    Name = "day5IGW"
  }
}

# Route Table
resource "aws_route_table" "day5rt" {
  vpc_id = aws_vpc.day5vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.day5igw.id
  }

  tags = {
    Name = "day5RouteTable"
  }
}

# Route Table Associations
resource "aws_route_table_association" "day5rta1" {
  subnet_id      = aws_subnet.day5publicsubnet1.id
  route_table_id = aws_route_table.day5rt.id
}

resource "aws_route_table_association" "day5rta2" {
  subnet_id      = aws_subnet.day5publicsubnet2.id
  route_table_id = aws_route_table.day5rt.id
}

# Security Group for ALB
resource "aws_security_group" "alb_sg" {
  name        = "day5-alb-sg"
  description = "Allow HTTP to ALB"
  vpc_id      = aws_vpc.day5vpc.id

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

  tags = {
    Name = "day5ALBSecurityGroup"
  }
}

# Security Group for EC2 instances
resource "aws_security_group" "ec2_sg" {
  name        = "day5-ec2-sg"
  description = "Allow HTTP from ALB only"
  vpc_id      = aws_vpc.day5vpc.id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb_sg.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "day5EC2SecurityGroup"
  }
}

# Launch Template
resource "aws_launch_template" "day5lt" {
  name_prefix            = "day5-lt-"
  image_id               = data.aws_ami.amazon_linux.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.ec2_sg.id]

  user_data = base64encode(<<-EOF
#!/bin/bash
dnf update -y
dnf install -y httpd
systemctl start httpd
systemctl enable httpd
echo "<h1>Hello from SarahCanCode! Instance $(hostname)</h1>" > /var/www/html/index.html
EOF
  )

  tags = {
    Name = "day5LaunchTemplate"
  }
}

# Auto Scaling Group
resource "aws_autoscaling_group" "day5asg" {
  name                = "day5-asg"
  min_size            = 2
  max_size            = 5
  desired_capacity    = 2
  vpc_zone_identifier = [aws_subnet.day5publicsubnet1.id, aws_subnet.day5publicsubnet2.id]
  target_group_arns   = [aws_lb_target_group.day5tg.arn]
  health_check_type   = "ELB"

  launch_template {
    id      = aws_launch_template.day5lt.id
    version = "$Latest"
  }

  tag {
    key                 = "Name"
    value               = "day5ASGInstance"
    propagate_at_launch = true
  }
}

# Application Load Balancer
resource "aws_lb" "day5alb" {
  name               = "day5-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb_sg.id]
  subnets            = [aws_subnet.day5publicsubnet1.id, aws_subnet.day5publicsubnet2.id]

  tags = {
    Name = "day5ALB"
  }
}

# Target Group
resource "aws_lb_target_group" "day5tg" {
  name     = "day5-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.day5vpc.id

  health_check {
    path                = "/"
    port                = 80
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 10
  }

  tags = {
    Name = "day5TargetGroup"
  }
}

# ALB Listener
resource "aws_lb_listener" "day5listener" {
  load_balancer_arn = aws_lb.day5alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.day5tg.arn
  }
}

# Outputs
output "alb_dns_name" {
  value       = aws_lb.day5alb.dns_name
  description = "Paste this in your browser to test"
}

output "ami_used" {
  value = data.aws_ami.amazon_linux.id
}
