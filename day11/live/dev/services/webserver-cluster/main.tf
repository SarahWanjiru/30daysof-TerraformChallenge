provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day11/dev/services/webserver-cluster/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name               = "webservers-dev"
  instance_type              = "t3.micro"
  environment                = "dev"
  enable_autoscaling         = false
  enable_detailed_monitoring = false
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

output "cloudwatch_alarm_arn" {
  value = module.webserver_cluster.cloudwatch_alarm_arn
}