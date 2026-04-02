provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day13/dev/services/webserver-cluster/terraform.tfstate"
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
  app_version                = "v1"
  active_environment         = "blue"
  db_secret_name             = "day13/db/credentials"
}

output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}

output "active_environment" {
  value = module.webserver_cluster.active_environment
}

output "db_username_used" {
  value     = module.webserver_cluster.db_username_used
  sensitive = true
}
