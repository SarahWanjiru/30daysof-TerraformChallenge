# Environment: Production

## What This Does
Deploys a single EC2 instance into the production environment. Production reads the staging environment's state file via `terraform_remote_state`.

## Backend
State is stored at `environments/production/terraform.tfstate` in the `sarahcodes-terraform-state-2026` S3 bucket.

## Remote State Dependency
Production reads the `instance_id` output from staging's state:

```hcl
data "terraform_remote_state" "staging" {
  backend = "s3"
  config = {
    bucket = "sarahcodes-terraform-state-2026"
    key    = "environments/staging/terraform.tfstate"
    region = "eu-north-1"
  }
}
```

Staging must be deployed before production for this to resolve.

## Variables

| Variable | Default |
|---|---|
| `region` | `eu-north-1` |
| `instance_type` | `t3.micro` |
| `ami` | `ami-0aaa636894689fa47` |
| `environment` | `production` |

## Outputs
- `instance_id`
- `environment`
- `subnet_id`
- `staging_instance_id`

## Usage
```bash
terraform init
terraform apply
terraform destroy
```
