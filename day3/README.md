# Day 3 — First Terraform Deployment

## What This Does
Deploys a basic EC2 instance on AWS using Terraform — no variables, no security groups, just a raw instance to get familiar with the Terraform workflow.

## Resources Created
- `aws_instance` — a single EC2 instance (`t3.micro`) in `eu-north-1`

## Usage
```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## Key Learnings
- How Terraform's `init → plan → apply` workflow works
- Writing a basic `provider` and `resource` block
- Understanding the AWS provider configuration
