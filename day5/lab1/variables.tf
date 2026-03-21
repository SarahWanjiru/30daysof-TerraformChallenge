variable "instance_type" {
    description = "The EC2 instance type to use for the server"
    type = string
    default = "t3.micro"
}

variable "region" {
    description = "The AWS region to deploy resources in"
    type = string
    default = "eu-north-1"
}

variable "aws_vpc_id" {
    description = "The ID of the VPC to deploy resources in"
    type = string
    default = "vpc-0b9e1f2a3c4d5e6f"
}

variable "vpc_cidr" {
    description = "The CIDR block for vpc"
    type = string
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    description = "The CIDR block for public subnet"
    type = string
    default = "10.0.1.0/24"
}


