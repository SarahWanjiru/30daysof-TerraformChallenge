# Day 22: Putting It All Together — Completing the Book and Reflecting on the Journey

## What I Did Today

Finished the book. Combined the application and infrastructure deployment workflows
into one integrated pipeline. Wrote three Sentinel policies. Reflected honestly on
22 days of building real infrastructure.



## Project Structure

```
day22/
├── modules/services/webserver-cluster/   # final production-grade module
├── live/dev/services/webserver-cluster/  # calling config
└── sentinel/
    ├── require-instance-type.sentinel    # blocks unapproved instance types
    ├── require-terraform-tag.sentinel    # requires ManagedBy = "terraform" tag
    └── cost-check.sentinel               # blocks cost increases over $50/month
```



## Integrated CI Pipeline

```yaml
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
```

**How the jobs connect:**
- `validate` runs on every PR and every push — format, syntax, unit tests
- `plan` runs after validate passes — generates the plan against real AWS
- `integration-tests` runs only on merge to main — deploys real infrastructure

This is the full pipeline from Day 16 (CI), Day 18 (automated testing), and Day 20
(seven-step workflow) combined into one coherent system.



## Sentinel Policies

### Policy 1 — Require Approved Instance Types

```python
import "tfplan/v2" as tfplan

allowed_instance_types = ["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_instance" or
    rc.change.after.instance_type in allowed_instance_types
  }
}
```

**What it blocks:** Any `aws_instance` with an instance type outside the approved list.
An engineer who accidentally writes `instance_type = "m5.4xlarge"` gets blocked before
the apply runs — not after a surprise AWS bill arrives.

**Why it matters:** `terraform validate` cannot check the value of `instance_type`.
Sentinel checks the actual value in the generated plan and blocks server-side.



### Policy 2 — Require ManagedBy Tag

```python
import "tfplan/v2" as tfplan

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.change.after.tags["ManagedBy"] is "terraform"
  }
}
```

**What it blocks:** Any resource missing the `ManagedBy = "terraform"` tag. Without
this policy, an engineer could create resources without the tag and they would be
invisible to cost attribution and compliance audits.

**Why it matters:** In a large AWS account with hundreds of resources, untagged
resources cannot be attributed to a team, a project, or a cost centre. This policy
enforces the tagging standard from Day 16's production-grade checklist at the
infrastructure level — not just as a code review comment.



### Policy 3 — Cost Estimation Gate

```python
import "tfrun"

maximum_monthly_increase = 50.0

main = rule {
  tfrun.cost_estimate.delta_monthly_cost < maximum_monthly_increase
}
```

**What it blocks:** Any plan where the estimated monthly cost increase exceeds $50.
An engineer who accidentally provisions an RDS Multi-AZ instance or an NAT Gateway
gets blocked before the apply runs.

**Cost threshold rationale:** $50/month is a reasonable gate for a dev environment.
A single EC2 t3.micro costs ~$7/month. An ALB costs ~$16/month. A plan that adds
more than $50/month to dev is worth a second look.



## Cost Estimation Gate

Terraform Cloud's cost estimation runs automatically after every plan. It shows:
- Current monthly cost of existing resources
- Projected monthly cost after the plan is applied
- Delta — the increase or decrease

For the webserver cluster dev environment:
- Current: $0 (no resources deployed)
- After plan: ~$30-40/month (ALB + EC2 + ASG)
- Delta: ~$30-40/month — under the $50 threshold, apply permitted

The cost-check Sentinel policy reads `tfrun.cost_estimate.delta_monthly_cost` and
blocks the apply if the delta exceeds the threshold.



## Side-by-Side Comparison Table

| Component | Application Code | Infrastructure Code |
|---|---|---|
| Source of truth | Git repository | Git repository |
| Local run | `npm start` / `python app.py` | `terraform plan` |
| Artifact | Docker image / binary | Saved `.tfplan` file |
| Versioning | Semantic version tag | Semantic version tag |
| Automated tests | Unit + integration tests | `terraform test` + Terratest |
| Policy enforcement | Linting / SAST | Sentinel policies |
| Cost gate | N/A | Cost estimation policy |
| Promotion | Image promoted across envs | Plan promoted across envs |
| Deployment | CI/CD pipeline | `terraform apply <plan>` |
| Rollback | Redeploy previous image | `terraform apply <previous plan>` |

**The key insight — immutable artifact promotion:**

In application code, a Docker image is built once, tested, and promoted through
environments. The same image that passed staging tests is the one deployed to
production — not a freshly built image.

In infrastructure code, the saved `.tfplan` file is the equivalent artifact. It is
generated once, reviewed, and applied. The same plan that was reviewed is the one
that gets applied — not a freshly generated plan that might differ.



## Journey Reflection

### What I Built

Over 22 days I deployed:

- EC2 instances, security groups, VPCs (Days 3-7)
- Auto Scaling Groups with ELB health checks (Days 8-9)
- Application Load Balancers with blue/green target groups (Days 12-13)
- Multi-region S3 replication across eu-north-1 and eu-west-1 (Day 14)
- Docker containers managed by Terraform (Day 15)
- A full EKS cluster with Kubernetes nginx deployment (Day 15)
- CloudWatch alarms, SNS topics, log groups (Days 11, 16, 21)
- AWS Secrets Manager integration (Day 13)
- Terraform state infrastructure — S3 + DynamoDB (Days 6, 19)
- GitHub Actions CI/CD pipeline with unit tests and integration tests (Days 16-18)
- Terratest integration tests that deploy real infrastructure (Day 18)
- terraform import of existing resources (Day 19)

That list is longer than most engineers build in their first year of cloud work.

### What Changed in How I Think

Before this challenge I thought about infrastructure as something you configure.
After this challenge I think about infrastructure as something you test.

The mental model shift: every infrastructure change has a blast radius. Before
applying anything, the first question is not "will this work?" — it is "what breaks
if this fails halfway through?" That question changes how you design modules, how
you write PRs, and how you think about rollback.

### What Was Harder Than Expected

State management. Not the mechanics of it — the S3 backend and DynamoDB locking
are straightforward. The hard part is understanding what the state file actually
represents and what happens when it gets out of sync with reality.

The terraform import exercise on Day 19 made this concrete. Two simple resources.
Revealed drift I did not know existed. Required investigation and a fix. Imagine
doing that for hundreds of resources at once.

### What I Would Do Differently

Start with modules from Day 1. The first week I wrote everything in a single
`main.tf` file. By Day 8 I was refactoring everything into modules. If I had
started with the module structure from the beginning, the refactoring work would
not have been necessary.

The second thing: commit the `.terraform.lock.hcl` file from the very first day.
I learned this on Day 14 but it should have been in the `.gitignore` discussion
on Day 1.

### What Comes Next

The new migration project coming up. Everything I built in this challenge — modules,
CI/CD, Secrets Manager integration, blue/green deployments, automated testing —
is exactly what that project needs. The challenge was the preparation.



## Chapter 10 Final Learnings

The single most important insight: **the plan file is the artifact**.

In application code, the Docker image is the immutable artifact that gets promoted
through environments. In infrastructure code, the saved `.tfplan` file is the
equivalent. It is generated once, reviewed, and applied. The same plan that was
reviewed is the one that gets applied.

Most teams skip this. They run `terraform apply` directly, which generates a fresh
plan at apply time. The review and the apply are disconnected. What was reviewed
is not what gets applied.

Plan file pinning closes that gap. It is one extra flag — `-out=reviewed.tfplan` —
and it is the difference between a workflow that is safe and one that only looks safe.
