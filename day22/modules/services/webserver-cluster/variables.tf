variable "cluster_name" {
  description = "Name prefix for all cluster resources"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type — must be t2 or t3 family"
  type        = string
  default     = "t3.micro"

  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be a t2 or t3 family type."
  }
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

variable "project_name" {
  description = "Project name applied to all resource tags"
  type        = string
  default     = "30day-terraform-challenge"
}

variable "team_name" {
  description = "Team or owner name applied to all resource tags"
  type        = string
  default     = "sarahcodes"
}

variable "enable_autoscaling" {
  description = "Enable autoscaling policies for the cluster"
  type        = bool
  default     = false
}

variable "enable_detailed_monitoring" {
  description = "Enable CloudWatch CPU alarm — incurs additional cost"
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

variable "db_secret_name" {
  description = "Name of the Secrets Manager secret containing db credentials"
  type        = string
  default     = "day13/db/credentials"
}

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
