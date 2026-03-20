# Day 4 — Clustered Web Server (ASG + ALB)

## What This Does
Extends the configurable web server into a production-ready, highly available cluster. An Auto Scaling Group manages multiple EC2 instances and an Application Load Balancer distributes traffic across them. Availability zones and subnets are fetched dynamically using data sources — no hardcoding.

## Architecture
```
Internet → ALB (port 80) → Target Group → ASG (2–5 EC2 instances)
```

## Resources Created

| Resource | Purpose |
|---|---|
| `aws_launch_template` | Defines instance spec and user data for the ASG |
| `aws_autoscaling_group` | Maintains 2–5 instances across availability zones |
| `aws_lb` | Application Load Balancer (public-facing) |
| `aws_lb_target_group` | Routes ALB traffic to ASG instances on `server_port` |
| `aws_lb_listener` | Listens on port 80 and forwards to the target group |
| `aws_security_group.web_sg` | Allows inbound traffic on `server_port` to EC2 instances |
| `aws_security_group.alb_sg` | Allows inbound HTTP (80) to the ALB |

## Data Sources Used
- `aws_availability_zones` — dynamically fetches all AZs in the region
- `aws_vpc` — fetches the default VPC
- `aws_subnets` — fetches all subnets in the default VPC

Using data sources means the config adapts to any region without hardcoding AZ names or subnet IDs.

## Variables

| Variable | Description | Default |
|---|---|---|
| `server_port` | Port EC2 instances serve HTTP on | `80` |
| `instance_type` | EC2 instance type | `t3.micro` |
| `ami` | AMI ID for instances | `ami-0aaa636894689fa47` |
| `region` | AWS region | `eu-north-1` |

## Usage
```bash
terraform init
terraform plan
terraform apply
# test the ALB DNS from the output
terraform destroy
```

## Output
- `alb_dns_name` — DNS name of the ALB; paste this in your browser to confirm the cluster is serving traffic

## Configurable vs Clustered — Key Difference
Day 4's single server is a single point of failure — if the instance goes down, the app is down. The clustered setup solves this with:
- **High availability** — instances spread across multiple AZs
- **Auto recovery** — ASG replaces unhealthy instances automatically
- **Scalability** — instance count scales between 2 and 5 based on demand
- **No direct instance exposure** — traffic enters only through the ALB
