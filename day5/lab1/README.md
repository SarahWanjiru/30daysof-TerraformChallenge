# Day 5 — Lab: Benefits of Terraform State

## What This Does
Hands-on lab exploring how Terraform state works. Deploys a VPC, public subnet, internet gateway, and an EC2 instance using a dynamically fetched Amazon Linux 2023 AMI, then experiments with state to understand what Terraform tracks and how it detects drift.

## Resources Created

| Resource | Purpose |
|---|---|
| `aws_vpc` | Custom VPC (`10.0.0.0/16`) |
| `aws_subnet` | Public subnet in AZ[0], auto-assigns public IPs |
| `aws_internet_gateway` | Enables internet access for the VPC |
| `aws_instance` | EC2 instance using the latest Amazon Linux 2023 AMI |

## Data Sources Used
- `aws_availability_zones` — fetches available AZs dynamically
- `aws_ami` — fetches the latest Amazon Linux 2023 HVM x86_64 AMI automatically

## Variables

| Variable | Description | Default |
|---|---|---|
| `region` | AWS region | `eu-north-1` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `public_subnet_cidr` | Public subnet CIDR | `10.0.1.0/24` |

## Outputs
- `instance_public_ip` — public IP of the EC2 instance
- `instance_id` — EC2 instance ID
- `ami_used` — AMI ID that was resolved and used

## Usage
```bash
terraform init
terraform plan
terraform apply
terraform destroy
```

## State Experiments

### Experiment 1 — Manual State Tampering
Manually edited a value inside `terraform.tfstate` (changed the instance type tag). Running `terraform plan` immediately detected the mismatch between state and config and proposed correcting it — even though the real infrastructure hadn't changed.

### Experiment 2 — State Drift
Changed a tag directly on the EC2 instance in the AWS Console without touching any Terraform code. Running `terraform plan` detected the drift and proposed reverting the tag back to what's defined in the config. This is how Terraform reconciles real-world changes made outside of IaC.

## Key Takeaways
- `terraform.tfstate` is Terraform's source of truth — it stores every attribute of every managed resource
- Terraform detects drift by comparing state against the real infrastructure on every `plan`
- Never manually edit the state file — use `terraform state` commands instead
- Never commit `terraform.tfstate` to Git — it can contain sensitive values like IPs, IDs, and secrets
