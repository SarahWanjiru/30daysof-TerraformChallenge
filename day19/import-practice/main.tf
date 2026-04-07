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
    key            = "day19/import-practice/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

provider "aws" {
  region = "eu-north-1"
}

resource "aws_s3_bucket" "state_bucket" {
  bucket = "sarahcodes-terraform-state-2026"

  tags = {
    Name        = "sarahcodes-terraform-state-2026"
    ManagedBy   = "terraform"
    Environment = "production"
    Project     = "30day-terraform-challenge"
    Owner       = "sarahcodes"
  }
}

resource "aws_dynamodb_table" "state_locks" {
  name         = "sarahcodes-terraform-locks"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = "sarahcodes-terraform-locks"
    ManagedBy   = "terraform"
    Environment = "production"
    Project     = "30day-terraform-challenge"
    Owner       = "sarahcodes"
  }
}
