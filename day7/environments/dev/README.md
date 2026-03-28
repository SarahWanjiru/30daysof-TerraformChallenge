# Environment: Dev

## What This Does
Deploys a single EC2 instance into the dev environment. This is the base environment — it has no dependency on any other environment's state.

## Backend
State is stored at `environments/dev/terraform.tfstate` in the `sarahcodes-terraform-state-2026` S3 bucket.

## Variables

| Variable | Default |
|---|---|
| `region` | `eu-north-1` |
| `instance_type` | `t3.micro` |
| `ami` | `ami-0aaa636894689fa47` |
| `environment` | `dev` |

## Outputs
- `instance_id`
- `environment`
- `subnet_id`

## Usage
```bash
terraform init
terraform apply
terraform destroy
```
