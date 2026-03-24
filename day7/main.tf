provider "aws" {
  region = var.region
}

resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type[terraform.workspace]

  tags = {
    Name        = "web-${terraform.workspace}"
    Environment = terraform.workspace
  }
}

output "instance_id" {
  value       = aws_instance.web.id
  description = "The ID of the EC2 instance"
}

output "environment" {
  value       = terraform.workspace
  description = "The current workspace environment"
}

output "instance_type_used" {
  value       = var.instance_type[terraform.workspace]
  description = "The instance type used in this environment"
}
