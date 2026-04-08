output "alb_dns_name" {
  value       = aws_lb.web.dns_name
  description = "The DNS name of the load balancer"
}

output "asg_name" {
  value       = aws_autoscaling_group.web.name
  description = "The name of the Auto Scaling Group"
}

output "alb_arn" {
  value       = aws_lb.web.arn
  description = "The ARN of the load balancer"
}

output "active_environment" {
  value       = var.active_environment
  description = "Which target group is currently receiving traffic"
}

output "instance_type_used" {
  value       = aws_launch_template.web.instance_type
  description = "The actual instance type used — affected by environment conditional"
}

output "min_size_used" {
  value       = local.actual_min_size
  description = "The actual min size used — affected by environment conditional"
}

output "max_size_used" {
  value       = local.actual_max_size
  description = "The actual max size used — affected by environment conditional"
}

output "log_group_name" {
  value       = aws_cloudwatch_log_group.web.name
  description = "CloudWatch log group name"
}

output "sns_topic_arn" {
  value       = aws_sns_topic.alerts.arn
  description = "ARN of the SNS topic that receives CloudWatch alarm notifications"
}

output "autoscaling_policy_arns" {
  description = "Map of autoscaling policy ARNs — empty when disabled"
  value = {
    for policy in concat(
      aws_autoscaling_policy.scale_out,
      aws_autoscaling_policy.scale_in
    ) : policy.name => policy.arn
  }
}

output "cloudwatch_alarm_arn" {
  description = "The ARN of the CloudWatch CPU alarm — null when monitoring disabled"
  value       = local.actual_monitoring ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
}

output "db_username_used" {
  description = "The database username fetched from Secrets Manager"
  value       = local.db_credentials["username"]
  sensitive   = true
}
