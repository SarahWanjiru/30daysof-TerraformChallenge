# Day 6 — Remote Backend with S3 and DynamoDB

## What This Does
Sets up the remote backend infrastructure that all future days depend on. Creates an S3 bucket to store Terraform state remotely and a DynamoDB table to handle state locking, preventing two engineers from running apply at the same time.

## Resources Created

| Resource | Purpose |
|---|---|
| `aws_s3_bucket` | Stores terraform.tfstate remotely |
| `aws_s3_bucket_versioning` | Keeps history of every state change |
| `aws_s3_bucket_server_side_encryption_configuration` | Encrypts state at rest with AES256 |
| `aws_s3_bucket_public_access_block` | Blocks all public access to the bucket |
| `aws_dynamodb_table` | Provides state locking via LockID hash key |

## Variables

| Variable | Description | Default |
|---|---|---|
| `region` | AWS region | `eu-north-1` |
| `day6-s3-bucket` | S3 bucket name | `sarahcodes-terraform-state-2026` |

## Backend
Once the S3 bucket and DynamoDB table exist, the backend block points Terraform at them:

```hcl
terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "global/s3/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}
```

## Outputs
- `s3_bucket_name` — name of the state bucket
- `dynamodb_table_name` — name of the lock table

## Usage
```bash
terraform init
terraform apply
# after apply, all other configs can use this bucket as their backend
```

## Why This Matters
Local state is fine for solo work but breaks in a team. Remote state in S3 means everyone shares the same source of truth. DynamoDB locking means no two applies can run simultaneously and corrupt the state file. The `prevent_destroy` lifecycle rule on the bucket prevents accidental deletion of all your state history.
