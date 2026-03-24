provider "aws" {
  region = var.region
}

# Read outputs from the dev state file
data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "sarahcodes-terraform-state-2026"
    key    = "environments/dev/terraform.tfstate"
    region = "eu-north-1"
  }
}

resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type

  tags = {
    Name        = "web-${var.environment}"
    Environment = var.environment
    DevInstance = data.terraform_remote_state.dev.outputs.instance_id
  }
}

output "dev_instance_id" {
  value       = data.terraform_remote_state.dev.outputs.instance_id
  description = "Instance ID pulled from dev state via remote_state data source"
}