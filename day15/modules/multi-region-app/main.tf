terraform {
  required_providers {
    aws = {
      source                = "hashicorp/aws"
      version               = "~> 6.0"
      configuration_aliases = [aws.primary, aws.replica]
    }
  }
}

# primary bucket — uses aws.primary provider passed in by the caller
resource "aws_s3_bucket" "primary" {
  provider = aws.primary
  bucket   = "${var.app_name}-primary-day15"
  tags     = { Name = "primary" }
}

resource "aws_s3_bucket_versioning" "primary" {
  provider = aws.primary
  bucket   = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

# replica bucket — uses aws.replica provider passed in by the caller
resource "aws_s3_bucket" "replica" {
  provider = aws.replica
  bucket   = "${var.app_name}-replica-day15"
  tags     = { Name = "replica" }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.replica
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration { status = "Enabled" }
}
