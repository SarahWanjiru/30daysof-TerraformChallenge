# Environment: Staging

## What This Does
Deploys a single EC2 instance into the staging environment. Staging reads the dev environment's state file via `terraform_remote_state` to demonstrate cross-state output sharing.

## Backend
State is stored at `environments/staging/terraform.tfstate` in the `sarahcodes-terraform-state-2026` S3 bucket.

## Remote State Dependency
Staging reads the `instance_id` output from dev's state:

```hcl
data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "sarahcodes-terraform-state-2026"
    key    = "environments/dev/terraform.tfstate"
    region = "eu-north-1"
  }
}
```

Dev must be deployed before staging for this to resolve.

## Variables

| Variable | Default |
|---|---|
| `region` | `eu-north-1` |
| `instance_type` | `t3.micro` |
| `ami` | `ami-0aaa636894689fa47` |
| `environment` | `staging` |

## Outputs
- `instance_id`
- `environment`
- `subnet_id`
- `dev_instance_id`

## Usage
```bash
terraform init
terraform apply
terraform destroy
```
