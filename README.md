# 30 Days of Terraform Challenge

A 25-day hands-on Terraform challenge covering everything from first EC2 instance to production-grade infrastructure, automated testing, multi-cloud deployments, and Terraform Associate exam preparation.


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



## Infrastructure Built

Over 24 days this repository deployed and destroyed:

- EC2 instances, security groups, VPCs
- Auto Scaling Groups with ELB health checks and blue/green target groups
- Application Load Balancers with zero-downtime deployment patterns
- Multi-region S3 replication (eu-north-1 → eu-west-1)
- Docker containers managed by Terraform
- A full EKS cluster with Kubernetes nginx deployment
- CloudWatch alarms, SNS topics, CloudWatch log groups
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

The production-grade webserver cluster module evolved across Days 8–22:

```
modules/services/webserver-cluster/
├── main.tf        # ASG, ALB, security groups, CloudWatch, SNS
├── variables.tf   # all inputs with validation blocks
└── outputs.tf     # all outputs including sensitive values
```

Key features built into the module:
- `create_before_destroy` on Launch Template and ASG
- `name_prefix` for unique resource names per deploy
- `common_tags` with `merge()` applied to every resource
- `is_production` local driving instance type, cluster size, and monitoring
- `sensitive = true` on database credentials
- IMDSv2 enforced via `metadata_options`
- CloudWatch log group with 30-day retention



## Sentinel Policies

Three Sentinel policies in [`day22/sentinel/`](./day22/sentinel/):

- `require-instance-type.sentinel` — blocks unapproved instance types
- `require-terraform-tag.sentinel` — requires `ManagedBy = "terraform"` on all resources
- `cost-check.sentinel` — blocks plans with monthly cost increase over $50



## Key Learnings

**The most important insight:** The plan file is the artifact. Generate once, review, apply exactly that plan. `terraform apply` without `-out` generates a fresh plan at apply time — what you reviewed is not what gets applied.

**The mental model shift:** Infrastructure is something you test, not just configure. Every change has a blast radius. The first question before any apply is not "will this work?" — it is "what breaks if this fails halfway through?"

**State is not infrastructure.** Every state command (`state rm`, `state mv`, `import`) operates on the record, not on real AWS resources. Only `apply` and `destroy` touch real infrastructure.



## Exam Score

Terraform Associate knowledge assessment: **121/200 — Established range, better than 66% of assessed learners.**



## Blog Posts

All blog posts published on Medium: [@SarahCanCode](https://medium.com/@sarahcancode)



## Resources

- [Terraform Associate Study Guide](https://developer.hashicorp.com/terraform/tutorials/certification-003/associate-study-003)
- [Official Sample Questions](https://developer.hashicorp.com/terraform/tutorials/certification-003/associate-questions)
- [Terraform Documentation](https://developer.hashicorp.com/terraform/docs)
- [AWS Pricing Calculator](https://calculator.aws)

