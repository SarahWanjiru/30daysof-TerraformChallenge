# Day 7 Part 1 — State Isolation via Workspaces

## What This Does
Demonstrates Terraform workspace isolation. A single configuration directory manages dev, staging, and production environments. Each workspace gets its own isolated state file in S3 automatically, while sharing the same Terraform code.

## Resources Created
- `aws_instance` — EC2 instance, sized and named dynamically based on the active workspace

## How Workspaces Work
The `terraform.workspace` built-in variable returns the name of the active workspace. It is used as a map key to select the correct instance type per environment and to tag resources with their environment name.

## Workspace Commands
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new production
terraform workspace list
terraform workspace select dev
terraform apply
```

## S3 State Paths
Terraform automatically stores each workspace state under a separate key:
```
day7/env:/dev/terraform.tfstate
day7/env:/staging/terraform.tfstate
day7/env:/production/terraform.tfstate
```

## Variables

| Variable | Description | Default |
|---|---|---|
| `region` | AWS region | `eu-north-1` |
| `ami` | AMI ID | `ami-0aaa636894689fa47` |
| `instance_type` | Map of env to instance type | `t3.micro` for all |

## Outputs
- `instance_id` — ID of the deployed instance
- `environment` — active workspace name
- `instance_type_used` — instance type selected for this environment

## Limitation
All environments share the same code. A change to `main.tf` affects every workspace. For stronger isolation, see the `environments/` file layout approach.
