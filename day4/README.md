# Day 4 — Configurable Web Server

## What This Does
Refactors the Day 3 server using input variables — nothing is hardcoded. Deploys a single EC2 instance running Apache (`httpd`) behind a security group, with all config driven by `variables.tf`.

## Resources Created
- `aws_security_group` — allows HTTP (80) and SSH (22) inbound
- `aws_instance` — EC2 instance running Apache, serving a custom HTML page

## Variables

| Variable | Description | Default |
|---|---|---|
| `server_port` | HTTP port the server listens on | `80` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `ami` | AMI ID for the instance | `ami-0aaa636894689fa47` |
| `region` | AWS region to deploy into | `eu-north-1` |

## Usage
```bash
terraform init
terraform plan
terraform apply
# grab the output IP and hit it in your browser
terraform destroy
```

## Output
- `instance_public_ip` — public IP of the deployed instance

## DRY Principle in Practice
Before variables, every value (AMI, instance type, port) was hardcoded directly in `main.tf`. With `variables.tf`, you change one value and it propagates everywhere. In a team, hardcoded values cause drift — different engineers deploy with different values and there's no single source of truth.
