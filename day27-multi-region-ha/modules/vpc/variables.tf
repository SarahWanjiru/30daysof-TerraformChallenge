variable "vpc_cidr" {
    description = "CIDR block for the VPC"
    type = string
}

variable "public_subnet_cidrs" {
  description = "List of CIDR blocks for public subnets (one per AZ)"
  type        = list(string)
}

variable "private_subnet_cidrs" {
  description = "List of CIDR blocks for private subnets (one per AZ)"
  type        = list(string)
}

variable "availability_zones" {
  description = "List of availability zones to use for subnets into"
  type        = list(string)
}

variable "environment" {
    description = "Deployment environment (e.g., dev, staging, prod)"
    type = string
}

variable "region" {
    description = "Aws region this vpcwill be deployed in"
    type = string 
}

variable "tags" {
    description = "Additional tags to apply to all resources"
    type = map(string)
    default = {}
}

