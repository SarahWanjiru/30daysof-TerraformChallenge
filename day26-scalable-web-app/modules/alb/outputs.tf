output "alb_dns_name" {
  value = aws_lb.alb.dns_name
  description = "DNS name of the Application Load Balancer"
}

output "target_group_arn" {
  value = aws_lb_target_group.tg.arn
  description = "ARN of the target group for the ALB consumed by ASG module"
}

output "alb_security_group_id" {
  value = aws_security_group.albsg.id
  description = "ID of the security group for the ALB"
}



