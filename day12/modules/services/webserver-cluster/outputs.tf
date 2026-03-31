output "alb_dns_name" {
  value       = aws_lb.web.dns_name
  description = "The DNS name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.web.name
  description = "ASG name — changes every deploy because of name_prefix, proves create_before_destroy worked"
}

output "alb_arn" {
  value       = aws_lb.web.arn
  description = "The ARN of the load balancer"
}

output "alb_security_group_id" {
  value       = aws_security_group.alb_sg.id
  description = "The security group ID of the ALB"
}

output "instance_type_used" {
  value       = aws_launch_template.web.instance_type
  description = "The actual instance type — affected by environment conditional"
}

output "environment" {
  value       = var.environment
  description = "The environment this cluster is deployed in"
}

output "min_size_used" {
  value       = local.actual_min_size
  description = "The actual min size used — affected by environment conditional"
}

output "max_size_used" {
  value       = local.actual_max_size
  description = "The actual max size used — affected by environment conditional"
}

# DAY 12 outputs
output "active_environment" {
  value       = var.active_environment
  description = "Which target group is currently receiving traffic: blue or green"
}

output "blue_tg_arn" {
  value       = aws_lb_target_group.blue.arn
  description = "ARN of the blue target group"
}

output "green_tg_arn" {
  value       = aws_lb_target_group.green.arn
  description = "ARN of the green target group"
}
# Returns ARN when enabled, null when disabled
# Without the ternary guard this crashes when count = 0
# -----------------------------------------------
output "autoscaling_policy_arns" {
  description = "Map of autoscaling policy ARNs — empty when disabled"
  value = {
    for policy in concat(
      aws_autoscaling_policy.scale_out,
      aws_autoscaling_policy.scale_in
    ) : policy.name => policy.arn
  }
}

# -----------------------------------------------
# SAFE conditional output — CloudWatch alarm
# Returns ARN when monitoring enabled, null when not
# [0] accesses the single instance when count = 1
# null is returned safely when count = 0
# -----------------------------------------------
output "cloudwatch_alarm_arn" {
  description = "The ARN of the CloudWatch CPU alarm — null when monitoring disabled"
  value       = local.actual_monitoring ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
}