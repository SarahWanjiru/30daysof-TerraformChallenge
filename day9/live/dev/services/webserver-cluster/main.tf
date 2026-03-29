provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day8/dev/services/webserver-cluster/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

module "webserver_cluster" {
  source = "github.com/SarahWanjiru/terraform-aws-webserver-cluster?ref=v0.0.2"

  cluster_name  = "webservers-dev"
  instance_type = "t3.micro"
  min_size      = 2
  max_size      = 4
}

output "alb_dns_name" {
  value       = module.webserver_cluster.alb_dns_name
  description = "The DNS name of the dev load balancer"
}
