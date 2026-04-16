variable "app_name" {
  description = "Name of the application"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod."
  }
}

# Primary Region Variables
variable "primary_ami_id" {
  description = "AMI ID for EC2 instances in primary region"
  type        = string
}

variable "primary_vpc_cidr" {
  description = "CIDR block for the primary region VPC"
  type        = string
}

variable "primary_public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets in primary region"
  type        = list(string)
}

variable "primary_private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets in primary region"
  type        = list(string)
}

variable "primary_availability_zones" {
  description = "List of availability zones in primary region"
  type        = list(string)
}

# Secondary Region Variables
variable "secondary_ami_id" {
  description = "AMI ID for EC2 instances in secondary region"
  type        = string
}

variable "secondary_vpc_cidr" {
  description = "CIDR block for the secondary region VPC"
  type        = string
}

variable "secondary_public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets in secondary region"
  type        = list(string)
}

variable "secondary_private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets in secondary region"
  type        = list(string)
}

variable "secondary_availability_zones" {
  description = "List of availability zones in secondary region"
  type        = list(string)
}

# EC2 Variables
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of EC2 instances in ASG"
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of EC2 instances in ASG"
  type        = number
  default     = 4
}

variable "desired_capacity" {
  description = "Desired number of EC2 instances in ASG"
  type        = number
  default     = 2
}

# RDS Variables
variable "db_name" {
  description = "Name of the initial database"
  type        = string
}

variable "db_username" {
  description = "Master database username"
  type        = string
  sensitive   = true
}

variable "db_password" {
  description = "Master database password"
  type        = string
  sensitive   = true
}

# Route53 Variables - Uncomment if you have a real domain
# variable "hosted_zone_id" {
#   description = "Route53 hosted zone ID for your domain"
#   type        = string
# }

# variable "domain_name" {
#   description = "Domain name for the application"
#   type        = string
# }