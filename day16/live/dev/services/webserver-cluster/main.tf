provider "aws" {
  region = "eu-north-1"
}

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day16/dev/services/webserver-cluster/terraform.tfstate"
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
  project_name               = "30day-terraform-challenge"
  team_name                  = "sarahcodes"
  enable_autoscaling         = false
  enable_detailed_monitoring = false
  app_version                = "v1"
  active_environment         = "blue"
  db_secret_name             = "day13/db/credentials"
}

output "alb_dns_name" {
  value = module.webserver_cluster.alb_dns_name
}

output "instance_type_used" {
  value = module.webserver_cluster.instance_type_used
}

output "sns_topic_arn" {
  value = module.webserver_cluster.sns_topic_arn
}
