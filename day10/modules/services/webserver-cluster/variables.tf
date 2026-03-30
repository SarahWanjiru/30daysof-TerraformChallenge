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
}

variable "max_size" {
  description = "Maximum number of EC2 instances in the ASG"
  type        = number
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

# conditions part controls wheather autoscaling policy is created or not
variable "enable_autoscaling" {
  description = "enable autoscaling for the cluster"
  type        = bool
  default     = true
}

#controls instance scaling up and down via conditional 
#production = t3.small, anything else = t3.micro
variable "environment" {
  description = "Environment - affects instance sizing"
  type = string
  default = "dev"
}