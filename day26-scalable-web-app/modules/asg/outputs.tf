output "asg_name" {
    value = aws_autoscaling_group.web.name
    description = "Name of the Auto Scaling Group for the web servers"
}

output "asg_arn" {
    value = aws_autoscaling_group.web.arn
    description = "ARN of the Auto Scaling Group for the web servers"
}

output  "scaling_policy_out_arn" {
    value = aws_autoscaling_policy.cpu_scale_out.arn
    description = "ARN of the CPU scale-out policy for the Auto Scaling Group"
}

output "scaling_policy_in_arn" {
    value = aws_autoscaling_policy.cpu_scale_in.arn
    description = "ARN of the CPU scale-in policy for the Auto Scaling Group"
}

output "dashboard_url" {
    value = "https://console.aws.amazon.com/cloudwatch/home?region=${data.aws_region.current.id}#dashboards:name=${aws_cloudwatch_dashboard.web.dashboard_name}"
    description = "URL to the CloudWatch dashboard for monitoring ASG metrics"
}