provider "aws" {
  region = var.region
}

# Read outputs from the staging state file
data "terraform_remote_state" "staging" {
  backend = "s3"
  config = {
    bucket = "sarahcodes-terraform-state-2026"
    key    = "environments/staging/terraform.tfstate"
    region = "eu-north-1"
  }
}

resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type

  tags = {
    Name           = "web-${var.environment}"
    Environment    = var.environment
    StagingInstance = data.terraform_remote_state.staging.outputs.instance_id
  }
}

output "staging_instance_id" {
  value       = data.terraform_remote_state.staging.outputs.instance_id
  description = "Instance ID pulled from staging state via remote_state data source"
}