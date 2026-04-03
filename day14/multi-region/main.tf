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
    key            = "day14/multi-region/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

# default provider — used by all resources unless overridden with provider = aws.<alias>
provider "aws" {
  region = "eu-north-1"
}

# aliased provider — resources in eu-west-1 reference this with provider = aws.eu_west
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}

# IAM role that grants S3 permission to replicate objects between buckets
resource "aws_iam_role" "replication" {
  name = "sarahcodes-s3-replication-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "s3.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# policy scoped to read from primary and write to replica only
resource "aws_iam_role_policy" "replication" {
  name = "sarahcodes-s3-replication-policy"
  role = aws_iam_role.replication.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetReplicationConfiguration", "s3:ListBucket"]
        Resource = aws_s3_bucket.primary.arn
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObjectVersionForReplication", "s3:GetObjectVersionAcl", "s3:GetObjectVersionTagging"]
        Resource = "${aws_s3_bucket.primary.arn}/*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:ReplicateObject", "s3:ReplicateDelete", "s3:ReplicateTags"]
        Resource = "${aws_s3_bucket.replica.arn}/*"
      }
    ]
  })
}

# primary bucket in eu-north-1 — versioning required for replication to work
resource "aws_s3_bucket" "primary" {
  bucket = "sarahcodes-primary-bucket-day14"
  tags   = { Name = "primary" }
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

# replica bucket in eu-west-1 — provider = aws.eu_west routes this to the aliased provider
resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west
  bucket   = "sarahcodes-replica-bucket-day14"
  tags     = { Name = "replica" }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.eu_west
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration { status = "Enabled" }
}

# replication rule — copies all objects from primary to replica automatically
resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.replica
  ]
}
