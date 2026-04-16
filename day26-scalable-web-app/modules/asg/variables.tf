variable "launch_template_id" {
    description = "ID of the launch template to use for the Auto Scaling Group"
    type = string
}

variable "launch_template_version" {
    description = "Version of the launch template to use for the Auto Scaling Group"
    type = string
}

variable "subnet_ids" {
    description = "List of subnet IDs for the Auto Scaling Group (should be private subnets)"
    type = list(string)
}

variable "target_group_arns" {
    description = "ARN of the target group to attach to the Auto Scaling Group"
    type = list(string)
}

variable "min_size" {
    description = "Minimum number of instances in the Auto Scaling Group"
    type = number
    default = 1
}

variable "max_size" {
    description = "Maximum number of instances in the Auto Scaling Group"
    type = number
    default = 4
}

variable "desired_capacity" {
    description = "Desired number of instances in the Auto Scaling Group"
    type = number
    default = 2
}

variable "cpu_scale_out_threshold" {
    description = "CPU utilization percentage to trigger scale-out"
    type = number
    default = 70
}

variable "cpu_scale_in_threshold" {
    description = "CPU utilization percentage to trigger scale-in"
    type = number
    default = 30
}

variable "environment" {
    description = "Deployment environment (e.g., dev, staging, prod)"
    type = string
}

variable "tags" {
    description = "Additional tags to apply to all resources"
    type = map(string)
    default = {}
}