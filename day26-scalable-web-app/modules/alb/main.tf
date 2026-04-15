locals {
    common_tags = merge(var.tags, {
        Environment = var.environment
        ManagedBy = "Terraform"
        Project = "scalable-web-app"
    })
}

resource "aws_security_group" "albsg" {
    name = "${var.name}-alb-sg-${var.environment}"
    description = "Allow HTTP/HTTPS inbound to ALB"
    vpc_id = var.vpc_id

    ingress = {
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }

    ingress {
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }


     egress = {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = local.common_tags
  
}

resource "aws_lb" "alb" {
    name = "${var.name}-alb-${var.environment}"
    internal = false
    load_balancer_type = "application"
    security_groups = [aws_security_group.albsg.id]
    subnets = var.subnet_ids
    tags = local.common_tags
}

resource "aws_lb_target_group" "tg" {
    name = "${var.name}-tg-${var.environment}"
    port = 80
    protocol = "HTTP"
    vpc_id = var.vpc_id

    health_check {
        path = "/"
        protocol = "HTTP"
        interval = 30
        timeout = 5
        healthy_threshold = 2
        unhealthy_threshold = 2
        matcher = "200"
    }

    tags = local.common_tags
}

resource "aws_lb_listener" "http" {
    load_balancer_arn = aws_lb.alb.arn
    port = 80
    protocol = "HTTP"

    default_action {
        type = "forward"
        target_group_arn = aws_lb_target_group.tg.arn
    }
}
    
  
