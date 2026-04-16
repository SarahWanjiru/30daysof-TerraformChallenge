variable "instance_type" {
    description = "The type of EC2 instance to use"
    type = string
    default = "t3.micro"
}


variable "ami_id" {
    description = "The ID of the AMI to use for the EC2 instance"
    type = string
}

variable "key_name" {
    description = "The name of the key pair to use for SSH access to the EC2 instance"
    type = string
    default = null
}

variable "environment" {
    description = "Deployment environment (e.g., dev, staging, prod)"
    type = string
    
    validation {
        condition = contains(["dev", "staging", "prod"], var.environment)
        error_message = "Environment must be one of 'dev', 'staging', or 'prod'."
    }
}

variable "tags" {
    description = "Additional tags to apply to all resources"
    type = map(string)
    default = {}
}


