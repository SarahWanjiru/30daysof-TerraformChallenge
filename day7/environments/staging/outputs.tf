output "instance_id" {
  value       = aws_instance.web.id
  description = "The ID of the EC2 instance"
}

output "environment" {
  value       = var.environment
  description = "The environment name"
}

output "subnet_id" {
  value       = aws_instance.web.subnet_id
  description = "The subnet ID of the EC2 instance"
}