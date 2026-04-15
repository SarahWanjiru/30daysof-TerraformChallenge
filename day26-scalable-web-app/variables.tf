variable "app_name" {
  description = "The name of the application"
  type        = string
}

variable "environment" {
  description = "The environment for the deployment"
  type        = string
}

variable "ami_id" {
  description = "The AMI ID for the instances"
  type        = string
}

variable "vpc_id" {
  description = "The VPC ID"
  type        = string
}

variable "public_subnet_ids" {
  description = "List of public subnet IDs"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "List of private subnet IDs"
  type        = list(string)
}

variable "min_size" {
  description = "Minimum size of the auto scaling group"
  type        = number
}

variable "max_size" {
  description = "Maximum size of the auto scaling group"
  type        = number
}

variable "desired_capacity" {
  description = "Desired capacity of the auto scaling group"
  type        = number
}