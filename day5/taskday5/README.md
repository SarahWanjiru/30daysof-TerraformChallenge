# Day 5 — Scaled Infrastructure with ALB + ASG

## What This Does
Deploys a production-ready, highly available web application on a custom VPC. An Application Load Balancer sits in front of an Auto Scaling Group spread across two availability zones. EC2 instances are only reachable through the ALB — direct access is blocked at the security group level.

## Architecture
```
Internet → ALB (port 80)
             ↓
        Target Group
             ↓
   ASG (2–5 EC2 instances)
   AZ[0] subnet + AZ[1] subnet
```

## Resources Created

| Resource | Purpose |
|---|---|
| `aws_vpc` | Custom VPC with DNS support enabled |
| `aws_subnet` x2 | Public subnets in two different AZs (required by ALB) |
| `aws_internet_gateway` | Enables outbound internet access |
| `aws_route_table` + associations | Routes `0.0.0.0/0` traffic through the IGW for both subnets |
| `aws_security_group.alb_sg` | Allows inbound HTTP (80) from the internet to the ALB |
| `aws_security_group.ec2_sg` | Allows inbound HTTP (80) from the ALB only — no direct public access |
| `aws_launch_template` | Defines instance spec, AMI, and Apache user data for the ASG |
| `aws_autoscaling_group` | Maintains 2–5 instances across both subnets |
| `aws_lb` | Public-facing Application Load Balancer |
| `aws_lb_target_group` | Routes ALB traffic to instances on port 80 with health checks |
| `aws_lb_listener` | Listens on port 80 and forwards to the target group |

## Data Sources Used
- `aws_availability_zones` — dynamically fetches available AZs so no AZ names are hardcoded
- `aws_ami` — always resolves to the latest Amazon Linux 2023 HVM x86_64 AMI

## Variables

| Variable | Description | Default |
|---|---|---|
| `region` | AWS region | `eu-north-1` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `vpc_cidr` | VPC CIDR block | `10.0.0.0/16` |
| `public_subnet_cidr` | Subnet 1 CIDR (AZ[0]) | `10.0.1.0/24` |
| `public_subnet_cidr2` | Subnet 2 CIDR (AZ[1]) | `10.0.2.0/24` |

## Outputs
- `alb_dns_name` — paste this in your browser to confirm the cluster is serving traffic
- `ami_used` — the AMI ID that was dynamically resolved and deployed

## Usage
```bash
terraform init
terraform plan
terraform apply
# copy alb_dns_name from output and open in browser
terraform destroy
```

## How the Resources Connect
1. The **Launch Template** defines what each EC2 instance looks like — AMI, instance type, security group, and the Apache install script via `user_data`
2. The **ASG** uses the launch template to spin up 2 instances across the two public subnets, replacing any unhealthy ones automatically
3. The **Target Group** is the bridge between the ALB and the ASG — the ASG registers its instances into it
4. The **ALB Listener** receives traffic on port 80 and forwards it to the target group
5. **Security groups** enforce that instances only accept traffic from the ALB, not directly from the internet

## Terraform Block Comparison Table

| Block | Purpose | When to Use | Example |
|---|---|---|---|
| `provider` | Configures the cloud provider | Once per provider | `provider "aws" { region = "eu-north-1" }` |
| `resource` | Defines infrastructure to create | Every piece of infrastructure | `resource "aws_instance" "web" { ... }` |
| `variable` | Declares an input variable | To avoid hardcoding values | `variable "instance_type" { default = "t3.micro" }` |
| `output` | Exposes values after apply | To surface IPs, DNS names, IDs | `output "alb_dns" { value = aws_lb.day5alb.dns_name }` |
| `data` | Reads existing or dynamic resources | To reference things not managed by this config | `data "aws_ami" "amazon_linux" { most_recent = true }` |

## Why State Must Not Be Committed to Git
- `terraform.tfstate` contains resource IDs, IPs, and potentially sensitive attribute values
- Committing it causes merge conflicts in team environments and exposes infrastructure details
- The solution is a **remote backend** (e.g. S3 + DynamoDB) which stores state centrally and enables **state locking** — preventing two engineers from running `apply` simultaneously and corrupting state
