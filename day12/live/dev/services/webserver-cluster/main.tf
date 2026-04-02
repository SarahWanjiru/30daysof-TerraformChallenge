provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day12/dev/services/webserver-cluster/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

variable "environment" {
  description = "Deployment environment passed through to module validation"
  type        = string
  default     = "dev"
}

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name               = "webservers-dev"
  instance_type              = "t3.micro"
  environment                = var.environment
  enable_autoscaling         = false
  enable_detailed_monitoring = false

  # DAY 12 — change app_version to "v2" to trigger zero-downtime rolling update
  # DAY 12 — change active_environment to "green" to do blue/green switch
  app_version        = "v2"
  active_environment = "green"
}

output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}

output "instance_type_used" {
  value = module.webserver_cluster.instance_type_used
}

output "min_size_used" {
  value = module.webserver_cluster.min_size_used
}

output "max_size_used" {
  value = module.webserver_cluster.max_size_used
}

output "active_environment" {
  value = module.webserver_cluster.active_environment
}

output "asg_name" {
  value       = module.webserver_cluster.asg_name
  description = "Changes each deploy — proof that name_prefix and create_before_destroy worked"
}