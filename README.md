# 30 Days of Terraform Challenge

A 27-day hands-on Terraform challenge covering everything from first EC2 instance to production-grade infrastructure, automated testing, multi-cloud deployments, and Terraform Associate exam preparation.


## What This Repository Contains

Each day folder contains:
- **Terraform code** — the actual infrastructure built that day
- **README.md** — full documentation, commands run, outputs, and learnings
- **BLOG.md** — the Medium blog post for that day (where applicable)



## Progress

| Day | Topic | Key Concepts |
|---|---|---|
| [Day 3](./day3/) | First EC2 Instance | Provider, resource, terraform init/plan/apply |
| [Day 4](./day4/) | Variables and Outputs | Input variables, output values, tfvars |
| [Day 5](./day5/) | Loops and Conditionals | count, for_each, ternary expressions |
| [Day 6](./day6/) | Remote State | S3 backend, DynamoDB locking, state encryption |
| [Day 7](./day7/) | Workspaces | Terraform workspaces, environment isolation |
| [Day 8](./day8/) | Modules — Part 1 | Module structure, inputs, outputs, reuse |
| [Day 9](./day9/) | Modules — Part 2 | Module versioning, Git tags, multi-environment |
| [Day 10](./day10/) | Loops and Conditionals Deep Dive | count vs for_each, for expressions |
| [Day 11](./day11/) | Conditionals | is_production local, validation blocks, sensitive outputs |
| [Day 12](./day12/) | Zero-Downtime Deployments | create_before_destroy, blue/green, name_prefix |
| [Day 13](./day13/) | Secrets Management | AWS Secrets Manager, sensitive variables, state encryption |
| [Day 14](./day14/) | Multiple Providers — Part 1 | Provider aliases, multi-region, lock file |
| [Day 15](./day15/) | Multiple Providers — Part 2 | Multi-provider modules, Docker, EKS, Kubernetes |
| [Day 16](./day16/) | Production-Grade Infrastructure | Tagging, lifecycle rules, CloudWatch, Terratest, GitHub Actions CI |
| [Day 17](./day17/) | Manual Testing | Seven-step test checklist, blast radius, cleanup verification |
| [Day 18](./day18/) | Automated Testing | terraform test, Terratest, integration tests, CI/CD pipeline |
| [Day 19](./day19/) | IaC Adoption Strategy | terraform import, four-phase adoption plan, Terraform Cloud |
| [Day 20](./day20/) | Application Deployment Workflow | Seven-step workflow, plan file pinning, immutable artifacts |
| [Day 21](./day21/) | Infrastructure Deployment Workflow | Safeguards, Sentinel policies, blast radius documentation |
| [Day 22](./day22/) | Putting It All Together | Integrated pipeline, Sentinel, cost estimation, journey reflection |
| [Day 23](./day23/) | Exam Preparation | Domain audit, CLI commands, practice questions, study plan |
| [Day 24](./day24/) | Final Exam Review | Simulation score 121/200, flash cards, exam-day strategy |
| [Day 25](./day25-static-website/) | Static Website on S3 | S3 static hosting, CloudFront CDN, modular design, DRY principle |
| [Day 26](./day26-scalable-web-app/) | Scalable Web Application with Auto Scaling | EC2 Launch Templates, ALB, ASG, CloudWatch monitoring, modular architecture |
| [Day 27](./day27-multi-region-ha/) | 3-Tier Multi-Region High Availability | Multi-region VPC, ALB, ASG, RDS Multi-AZ, Route53 failover, five modules |



## Infrastructure Built

Over 27 days this repository deployed and destroyed:

- EC2 instances, security groups, VPCs
- Auto Scaling Groups with ELB health checks and blue/green target groups
- Application Load Balancers with zero-downtime deployment patterns
- **Static Website Infrastructure** — S3 static hosting with CloudFront CDN (Day 25)
- **Modular Auto Scaling Architecture** — Three-module design (EC2, ALB, ASG) with CloudWatch monitoring
- **3-Tier Multi-Region HA** — Five modules across two regions (eu-north-1 + eu-west-1), RDS Multi-AZ, Route53 failover
- Multi-region S3 replication (eu-north-1 → eu-west-1)
- Docker containers managed by Terraform
- A full EKS cluster with Kubernetes nginx deployment
- CloudWatch alarms, SNS topics, CloudWatch log groups, **CloudWatch dashboards**
- AWS Secrets Manager secrets and data source integration
- Terraform state infrastructure — S3 + DynamoDB
- Multi-provider modules with configuration_aliases



## CI/CD Pipeline

GitHub Actions workflows run automatically on every PR and push to main:

- `terraform fmt -check` — format validation
- `terraform validate` — syntax and consistency check
- `terraform test` — native unit tests
- `terraform plan` — plan against real AWS
- Terratest integration tests — deploy real infrastructure on merge to main

See [`.github/workflows/`](./.github/workflows/) for the full pipeline configuration.



## Module Structure

### Production-Grade Webserver Cluster (Days 8-22)
The webserver cluster module evolved across Days 8–22:

```
modules/services/webserver-cluster/
├── main.tf        # ASG, ALB, security groups, CloudWatch, SNS
├── variables.tf   # all inputs with validation blocks
└── outputs.tf     # all outputs including sensitive values
```

Key features:
- `create_before_destroy` on Launch Template and ASG
- `name_prefix` for unique resource names per deploy
- `common_tags` with `merge()` applied to every resource
- `is_production` local driving instance type, cluster size, and monitoring
- `sensitive = true` on database credentials
- IMDSv2 enforced via `metadata_options`
- CloudWatch log group with 30-day retention

### Multi-Region HA Architecture (Day 27)
Five-module 3-tier architecture across two AWS regions:

```
day27-multi-region-ha/modules/
├── vpc/      # VPC, subnets, NAT gateways, route tables
├── alb/      # Application Load Balancer, target groups
├── asg/      # Auto Scaling Group, launch template, CloudWatch
├── rds/      # RDS MySQL Multi-AZ
└── route53/  # DNS failover routing
```

Key features:
- **Two Regions**: eu-north-1 (primary) + eu-west-1 (secondary)
- **Multi-AZ RDS**: Protects against AZ failure within primary region
- **Route53 Failover**: Health-check-based DNS failover between regions
- **Multi-Provider**: Same modules deployed to both regions via provider aliases
- **59 Resources**: Deployed and destroyed with a single terraform apply/destroy

### Modular Auto Scaling Architecture (Day 26)
Three-module separation of concerns:

```
day26-scalable-web-app/modules/
├── ec2/     # Launch Template + Security Group
├── alb/     # Load Balancer + Target Group + Listener
└── asg/     # Auto Scaling + Policies + CloudWatch
```

Key features:
- **Data Flow Integration**: `module.ec2.launch_template_id` → ASG, `module.alb.target_group_arn` → ASG
- **CPU-Based Scaling**: 70% scale-out, 30% scale-in thresholds
- **ELB Health Checks**: `health_check_type = "ELB"` for application-level health
- **CloudWatch Dashboard**: Real-time monitoring with threshold annotations
- **Security Hardening**: Header injection prevention, least-privilege security groups

### Static Website Module (Day 25)
S3 static website hosting with CloudFront CDN:

```
day25-static-website/modules/s3-static-website/
├── main.tf      # S3 bucket, website config, CloudFront, IAM policy
├── variables.tf # Bucket name, environment, documents
└── outputs.tf   # Website endpoint, CloudFront domain
```

Key features:
- **Global CDN**: CloudFront distribution for worldwide content delivery
- **Public Access**: S3 bucket policy for public read access
- **Environment Isolation**: Dev/staging/production configurations
- **DRY Principle**: 13-line calling configuration vs 150+ line flat file



## Sentinel Policies

Three Sentinel policies in [`day22/sentinel/`](./day22/sentinel/):

- `require-instance-type.sentinel` — blocks unapproved instance types
- `require-terraform-tag.sentinel` — requires `ManagedBy = "terraform"` on all resources
- `cost-check.sentinel` — blocks plans with monthly cost increase over $50



## Key Learnings

**The most important insight:** The plan file is the artifact. Generate once, review, apply exactly that plan. `terraform apply` without `-out` generates a fresh plan at apply time — what you reviewed is not what gets applied.

**The mental model shift:** Infrastructure is something you test, not just configure. Every change has a blast radius. The first question before any apply is not "will this work?" — it is "what breaks if this fails halfway through?"

**State is not infrastructure.** Every state command (`state rm`, `state mv`, `import`) operates on the record, not on real AWS resources. Only `apply` and `destroy` touch real infrastructure.

**Multi-region is not the same as Multi-AZ.** Day 27 made this concrete. Multi-AZ protects against a single data center failure — automatic, synchronous, zero data loss. Multi-region protects against a full regional outage — manual promotion, asynchronous replication, possible data loss. Most applications need both, and they solve different problems at different scales.





## Blog Posts

All blog posts published on Medium: [@SarahCanCode](https://medium.com/@sarahcancode)



## Resources

- [Terraform Associate Study Guide](https://developer.hashicorp.com/terraform/tutorials/certification-003/associate-study-003)
- [Official Sample Questions](https://developer.hashicorp.com/terraform/tutorials/certification-003/associate-questions)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [AWS Pricing Calculator](https://calculator.aws)

