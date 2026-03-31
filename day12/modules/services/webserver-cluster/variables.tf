variable "cluster_name" {
  description = "The name to use for all cluster resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type for the cluster"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of EC2 instances in the ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the ASG"
  type        = number
  default     = 3
}

variable "server_port" {
  description = "Port the server uses for HTTP"
  type        = number
  default     = 80
}

variable "ami" {
  description = "AMI ID for EC2 instances"
  type        = string
  default     = "ami-0aaa636894689fa47"
}

variable "region" {
  description = "AWS region to deploy resources"
  type        = string
  default     = "eu-north-1"
}

# Validation block — catches invalid values at plan time
# before anything gets deployed
variable "environment" {
  description = "Deployment environment: dev, staging, or production"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

# Toggle for autoscaling policies
variable "enable_autoscaling" {
  description = "Enable autoscaling policy for the cluster"
  type        = bool
  default     = false
}

# Toggle for CloudWatch detailed monitoring
# incurs additional AWS cost — disabled by default
variable "enable_detailed_monitoring" {
  description = "Enable CloudWatch CPU alarm — incurs additional cost"
  type        = bool
  default     = false
}

# Toggle for conditional VPC pattern
# false = create a new VPC (greenfield)
# true  = use an existing VPC (brownfield)
variable "use_existing_vpc" {
  description = "Use an existing VPC instead of the default"
  type        = bool
  default     = false
}

# DAY 12 — change this from "v1" to "v2" to trigger a zero-downtime rolling update
# Terraform sees the user_data changed → creates new Launch Template → rolls ASG
variable "app_version" {
  description = "Application version — shown in HTML response. Change to trigger zero-downtime update."
  type        = string
  default     = "v1"
}

# DAY 12 — blue/green switch
# Change from "blue" to "green" to shift 100% of traffic atomically at the ALB
variable "active_environment" {
  description = "Which target group is currently active: blue or green"
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_environment)
    error_message = "active_environment must be blue or green."
  }
}