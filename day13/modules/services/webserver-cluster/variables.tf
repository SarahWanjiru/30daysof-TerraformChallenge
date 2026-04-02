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

variable "environment" {
  description = "Deployment environment: dev, staging, or production"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "enable_autoscaling" {
  description = "Enable autoscaling policy for the cluster"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable CloudWatch CPU alarm"
  type        = bool
  default     = false
}

variable "app_version" {
  description = "Application version — change to trigger zero-downtime update"
  type        = string
  default     = "v1"
}

variable "active_environment" {
  description = "Which target group is currently active: blue or green"
  type        = string
  default     = "blue"

  validation {
    condition     = contains(["blue", "green"], var.active_environment)
    error_message = "active_environment must be blue or green."
  }
}

# DAY 13 — sensitive variables
# no default — Terraform will prompt or require TF_VAR_ environment variable
# sensitive = true prevents the value appearing in plan/apply output and logs
variable "db_username" {
  description = "Database username — set via TF_VAR_db_username, never hardcoded"
  type        = string
  sensitive   = true
  default     = null
}

variable "db_password" {
  description = "Database password — set via TF_VAR_db_password, never hardcoded"
  type        = string
  sensitive   = true
  default     = null
}

# DAY 13 — Secrets Manager secret name to fetch at apply time
variable "db_secret_name" {
  description = "Name of the Secrets Manager secret containing db credentials"
  type        = string
  default     = "day13/db/credentials"
}
