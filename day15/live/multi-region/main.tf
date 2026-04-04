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
    key            = "day15/multi-region/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

# providers are defined in the root config — never inside the module
provider "aws" {
  alias  = "primary"
  region = "eu-north-1"
}

provider "aws" {
  alias  = "replica"
  region = "eu-west-1"
}

# providers map wires root providers to the module's expected aliases
module "multi_region_app" {
  source   = "../../modules/multi-region-app"
  app_name = "sarahcodes"

  providers = {
    aws.primary = aws.primary
    aws.replica = aws.replica
  }
}

output "primary_bucket_region" {
  value = module.multi_region_app.primary_bucket_region
}

output "replica_bucket_region" {
  value = module.multi_region_app.replica_bucket_region
}
