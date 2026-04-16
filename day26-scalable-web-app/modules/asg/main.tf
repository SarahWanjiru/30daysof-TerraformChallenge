data "aws_region" "current" {}

locals {
    common_tags = merge(var.tags, {
        Environment = var.environment
        ManagedBy = "Terraform"
        Project = "scalable-web-app"
    })
}

resource "aws_autoscaling_group" "web" {
    name = "web-asg-${var.environment}"
    min_size = var.min_size
    max_size = var.max_size
    desired_capacity = var.desired_capacity
    vpc_zone_identifier = var.subnet_ids
    target_group_arns = var.target_group_arns
    force_delete = var.environment != "production"

    launch_template {
        id = var.launch_template_id
        version = var.launch_template_version
    }

    health_check_type = "ELB"
    health_check_grace_period = 300

    dynamic "tag" {
        for_each = merge(local.common_tags, {Name = "web-asg-${var.environment}"})
        content {
            key = tag.key
            value = tag.value
            propagate_at_launch = true
        }
      
    }

    lifecycle {
      create_before_destroy = true
    } 
}

resource "aws_autoscaling_policy" "cpu_scale_out" {
    name = "cpu-scale-out-${var.environment}"
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = 1
    cooldown = 300
     autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_autoscaling_policy" "cpu_scale_in" {
    name = "cpu-scale-in-${var.environment}"
    adjustment_type = "ChangeInCapacity"
    scaling_adjustment = -1
    cooldown = 300
     autoscaling_group_name = aws_autoscaling_group.web.name
}

resource "aws_cloudwatch_metric_alarm" "cpu_high" {
    alarm_name = "cpu-high-${var.environment}"
    comparison_operator = "GreaterThanOrEqualToThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 300
    statistic = "Average"
    threshold = var.cpu_scale_out_threshold

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.web.name
    }

    alarm_description = "Scale out when average CPU is >= ${var.cpu_scale_out_threshold}%"
    alarm_actions = [aws_autoscaling_policy.cpu_scale_out.arn]
}

resource "aws_cloudwatch_metric_alarm" "cpu_low" {
    alarm_name = "cpu-low-${var.environment}"
    comparison_operator = "LessThanOrEqualToThreshold"
    evaluation_periods = 2
    metric_name = "CPUUtilization"
    namespace = "AWS/EC2"
    period = 120
    statistic = "Average"
    threshold = var.cpu_scale_in_threshold

    dimensions = {
        AutoScalingGroupName = aws_autoscaling_group.web.name
    }

    alarm_description = "Scale in when average CPU is <= ${var.cpu_scale_in_threshold}%"
    alarm_actions = [aws_autoscaling_policy.cpu_scale_in.arn]
}

resource "aws_cloudwatch_dashboard" "web" {
    dashboard_name = "web-asg-${var.environment}"

    dashboard_body = jsonencode({
        widgets = [
            {
                type = "metric"
                x = 0
                y = 0
                width = 12
                height = 6
                properties = {
                    title = "CPU Utilization"
                    period = 300
                    stat = "Average"
                    region = data.aws_region.current.id
                    annotations = {
                        horizontal = [
                            {
                                label = "Scale Out Threshold"
                                value = var.cpu_scale_out_threshold
                            },
                            {
                                label = "Scale In Threshold"
                                value = var.cpu_scale_in_threshold
                            }
                        ]
                    }
                    metrics = [
                        ["AWS/EC2", "CPUUtilization", "AutoScalingGroupName", aws_autoscaling_group.web.name]
                    ]
                }
            },
            {
                type = "metric"
                x = 0
                y = 6
                width = 12
                height = 6
                properties = {
                    title = "ASG Instance Count"
                    period = 300
                    stat = "Average"
                    region = data.aws_region.current.id
                    annotations = {
                        horizontal = [
                            {
                                label = "Desired Capacity"
                                value = var.desired_capacity
                            }
                        ]
                    }
                    metrics = [
                        ["AWS/AutoScaling", "GroupInServiceInstances", "AutoScalingGroupName", aws_autoscaling_group.web.name]
                    ]
                }
            }
        ]
    })
}
