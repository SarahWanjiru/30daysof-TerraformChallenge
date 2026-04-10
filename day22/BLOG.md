TITLE (paste into Medium title field):
Putting It All Together: Application and Infrastructure Workflows with Terraform

SUBTITLE (paste into Medium subtitle field):
22 days. One integrated pipeline. Three Sentinel policies. And the single insight that changes how you think about every infrastructure deployment forever.

---

BODY (paste everything below into Medium):

---

Introduction

I finished the book today.

22 days ago I did not know what a Terraform provider was. Today I have a fully integrated CI/CD pipeline that runs format checks, unit tests, integration tests, Sentinel policy enforcement, and cost estimation gates — automatically, on every pull request.

This post is two things. A technical walkthrough of the integrated pipeline. And an honest reflection on what 22 days of building real infrastructure actually taught me.


Prerequisites

- Days 1-21 of this series
- GitHub Actions CI pipeline from Day 18
- Terraform Cloud account for Sentinel and cost estimation


1. The Integrated Pipeline

The final pipeline combines everything from the last three weeks into one coherent system.

name: Infrastructure CI

on:
  pull_request:
    branches: [main]
  push:
    branches: [main]

jobs:
  validate:
    steps:
      - name: Format check
        run: terraform fmt -check -recursive
      - name: Init
        run: terraform init -backend=false
      - name: Validate
        run: terraform validate
      - name: Unit tests
        run: terraform test

  plan:
    needs: validate
    steps:
      - name: Init
        run: terraform init
      - name: Plan
        run: terraform plan -no-color

  integration-tests:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    needs: validate
    steps:
      - name: Run Integration Tests
        run: go test -v -timeout 30m ./...

Three jobs. One dependency chain.

validate runs on every PR — format, syntax, unit tests. Fast, free, catches most bugs.
plan runs after validate — generates the plan against real AWS.
integration-tests runs only on merge to main — deploys real infrastructure, costs money.

📸 Screenshot here — GitHub Actions showing all three jobs in the pipeline
Caption: The integrated pipeline — validate → plan → integration tests, each job depends on the previous


2. The Key Insight — The Plan File Is the Artifact

In application code, a Docker image is built once, tested, and promoted through environments. The same image that passed staging tests is the one deployed to production.

In infrastructure code, the saved .tfplan file is the equivalent artifact.

terraform plan -out=reviewed.tfplan   # generated once, reviewed
terraform apply "reviewed.tfplan"     # applied exactly as reviewed

Most teams skip this. They run terraform apply directly, which generates a fresh plan at apply time. The review and the apply are disconnected. What was reviewed is not what gets applied.

Plan file pinning closes that gap. One extra flag. The difference between a workflow that is safe and one that only looks safe.


3. Sentinel Policies

Three policies enforcing organisational standards before every apply.

Policy 1 — Approved Instance Types

import "tfplan/v2" as tfplan

allowed_instance_types = ["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_instance" or
    rc.change.after.instance_type in allowed_instance_types
  }
}

Blocks any aws_instance with an unapproved instance type. An engineer who writes instance_type = "m5.4xlarge" gets blocked before the apply runs — not after a surprise AWS bill.

Policy 2 — Require ManagedBy Tag

import "tfplan/v2" as tfplan

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.change.after.tags["ManagedBy"] is "terraform"
  }
}

Blocks any resource missing the ManagedBy = "terraform" tag. Without this, resources created by Terraform are invisible to cost attribution and compliance audits. This enforces the tagging standard from Day 16 at the infrastructure level — not just as a code review comment.

Policy 3 — Cost Gate

import "tfrun"

maximum_monthly_increase = 50.0

main = rule {
  tfrun.cost_estimate.delta_monthly_cost < maximum_monthly_increase
}

Blocks any plan where the estimated monthly cost increase exceeds $50. An engineer who accidentally provisions an RDS Multi-AZ instance gets blocked before the apply runs.

📸 Screenshot here — Terraform Cloud showing cost estimation on a recent run
Caption: Cost estimation in Terraform Cloud — delta monthly cost shown before every apply


4. The Side-by-Side Comparison

Application Code vs Infrastructure Code — final state:

Source of truth: Git repository → Git repository
Local run: npm start → terraform plan
Artifact: Docker image → Saved .tfplan file
Versioning: Semantic version tag → Semantic version tag
Automated tests: Unit + integration → terraform test + Terratest
Policy enforcement: Linting / SAST → Sentinel policies
Cost gate: N/A → Cost estimation policy
Promotion: Image promoted across envs → Plan promoted across envs
Deployment: CI/CD pipeline → terraform apply plan
Rollback: Redeploy previous image → terraform apply previous plan

The workflows are converging. Infrastructure code is becoming software engineering.


5. The Reflection

What I built over 22 days:

- EC2 instances, security groups, VPCs
- Auto Scaling Groups with ELB health checks
- Application Load Balancers with blue/green target groups
- Multi-region S3 replication across two AWS regions
- Docker containers managed by Terraform
- A full EKS cluster with Kubernetes nginx deployment
- CloudWatch alarms, SNS topics, log groups
- AWS Secrets Manager integration
- Terraform state infrastructure — S3 + DynamoDB
- GitHub Actions CI/CD pipeline with unit and integration tests
- Terratest integration tests that deploy real infrastructure
- terraform import of existing resources

That list is longer than most engineers build in their first year of cloud work.

What changed in how I think:

Before this challenge I thought about infrastructure as something you configure. After this challenge I think about infrastructure as something you test.

The mental model shift: every infrastructure change has a blast radius. Before applying anything, the first question is not "will this work?" — it is "what breaks if this fails halfway through?" That question changes how you design modules, how you write PRs, and how you think about rollback.

What was harder than expected:

State management. Not the mechanics — the S3 backend and DynamoDB locking are straightforward. The hard part is understanding what the state file actually represents and what happens when it gets out of sync with reality.

The terraform import exercise on Day 19 made this concrete. Two simple resources. Revealed drift I did not know existed. Required investigation and a fix. Imagine doing that for hundreds of resources at once.

What I would do differently:

Start with modules from Day 1. The first week I wrote everything in a single main.tf file. By Day 8 I was refactoring everything into modules. If I had started with the module structure from the beginning, the refactoring work would not have been necessary.

What comes next:

The Gotham Enterprise migration. Everything I built in this challenge — modules, CI/CD, Secrets Manager integration, blue/green deployments, automated testing — is exactly what that project needs. The challenge was the preparation.


Key Lessons Learned

- The plan file is the artifact — generate once, review, apply exactly that plan
- Sentinel enforces policy server-side — engineers cannot bypass it
- Cost estimation gates catch expensive mistakes before they become AWS bills
- The integrated pipeline is the sum of every day's work — nothing was wasted
- Infrastructure code is becoming software engineering — same discipline, higher stakes
- The blast radius question changes everything — ask it before every apply
- State management is the hardest concept — not the syntax, the mental model


Final Thoughts

22 days ago I started this challenge to learn Terraform.

I learned Terraform. But I also learned something more important — how to think about infrastructure the way a senior engineer thinks about it. Not as a collection of resources to configure, but as a system to design, test, version, and deploy safely.

The book is finished. The challenge is not.

I am currently doing the 30-Day Terraform Challenge while building Cloud and DevOps skills in public. Open to opportunities — using this time to build real-world skills by actually doing and breaking things.

If you are also learning Terraform or DevOps, let's connect and grow together.

#30DayTerraformChallenge #TerraformChallenge #Terraform #DevOps #IaC #AWSUserGroupKenya #EveOps #WomenInTech #BuildInPublic #CloudComputing #AWS #Andela
