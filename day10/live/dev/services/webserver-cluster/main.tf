provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day10/dev/services/webserver-cluster/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
  environment = "dev"
  enable_autoscaling = false
}

output "alb_dns_name" {
  value       = module.webserver_cluster.alb_dns_name
  description = "The DNS name of the dev load balancer"
}

output "instance_type_used" {
  value = module.webserver_cluster.instance_type_used
  description = "The actual instance type used in dev environment"
}

output "autoscaling_policy_arns" {
  value = module.webserver_cluster.autoscaling_policy_arns
  description = "The ARNs of the autoscaling policies in dev environment"
}
