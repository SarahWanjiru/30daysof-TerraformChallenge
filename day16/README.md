# Day 16: Building Production-Grade Infrastructure

## What I Did Today

Audited the webserver cluster module against the full production-grade checklist from
Chapter 8. Identified every gap and closed them: added consistent tagging with `merge()`,
`prevent_destroy` on the ALB, SNS alerts wired to CloudWatch alarms, input validation on
every constrained variable, and wrote a Terratest function for automated testing.

---

## Project Structure

```
day16/
├── modules/services/webserver-cluster/
│   ├── main.tf        # production-grade refactor — tagging, lifecycle, SNS
│   ├── variables.tf   # validation on every constrained variable
│   └── outputs.tf     # all outputs documented
├── live/dev/services/webserver-cluster/
│   └── main.tf        # calling config with project_name and team_name
└── test/
    └── webserver_cluster_test.go  # Terratest automated test
```

---

## Production-Grade Checklist Audit

### Code Structure
- [x] Configuration broken into small, single-purpose modules
- [x] Modules have clear interfaces — all inputs typed, described, validated
- [x] All outputs defined and documented
- [x] No hardcoded values in resource blocks — all from variables or locals
- [x] locals used to centralise repeated expressions

### Reliability
- [x] ASG health check type = "ELB"
- [x] `create_before_destroy = true` on Launch Template and ASG
- [x] `name_prefix` used on ASG and Launch Template — unique per deploy
- [x] `prevent_destroy = true` added to ALB — **added today**

### Security
- [x] No secrets in .tf files — Secrets Manager integration from Day 13
- [x] All sensitive variables and outputs marked `sensitive = true`
- [x] State stored remotely with encryption — S3 + `encrypt = true`
- [x] IAM roles scoped to minimum required permissions
- [ ] Security groups still use `0.0.0.0/0` on port 80 — acceptable for a public web server, would restrict for internal services

### Observability
- [x] Consistent tagging on every resource using `merge(local.common_tags, {...})` — **added today**
- [x] CloudWatch CPU alarm exists — from Day 11
- [x] SNS topic wired to alarm actions — **added today**
- [ ] Log groups with retention periods — not yet implemented

### Maintainability
- [x] Every module has a README.md
- [x] Provider versions pinned in `required_providers`
- [x] `.terraform.lock.hcl` committed to version control
- [x] `.gitignore` excludes state files, `.terraform/`, `*.tfvars`

---

## Top 3 Refactors

### Refactor 1 — Consistent Tagging with merge()

**Before — tags scattered or missing:**

```hcl
resource "aws_security_group" "instance_sg" {
  name = "${var.cluster_name}-instance-sg"
  # no tags
}

resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"
  tags = { Name = "${var.cluster_name}-alb" }
  # missing Environment, ManagedBy, Project, Owner
}
```

**After — common_tags applied to every resource:**

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Owner       = var.team_name
  }
}

resource "aws_security_group" "instance_sg" {
  name = "${var.cluster_name}-instance-sg"
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-instance-sg" })
}

resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-alb" })
}
```

`merge()` combines the common tags with the resource-specific `Name` tag. Change `project_name`
or `team_name` once in the calling config — every resource updates automatically.

---

### Refactor 2 — prevent_destroy on the ALB

**Before:**

```hcl
resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"
}
```

**After:**

```hcl
resource "aws_lb" "web" {
  name = "${var.cluster_name}-alb"

  lifecycle {
    prevent_destroy = true
  }
}
```

Without `prevent_destroy`, a misconfigured `terraform destroy` or a variable change that
forces ALB recreation would take down the load balancer — and all traffic with it. With
`prevent_destroy`, Terraform errors before touching the ALB. You must explicitly remove the
lifecycle block to destroy it.

---

### Refactor 3 — SNS Topic Wired to CloudWatch Alarm

**Before — alarm existed but fired silently:**

```hcl
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count     = local.actual_monitoring ? 1 : 0
  threshold = 80
  # no alarm_actions — alarm fires but nobody is notified
}
```

**After — alarm notifies SNS topic:**

```hcl
resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-alerts"
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-alerts" })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count         = local.actual_monitoring ? 1 : 0
  threshold     = 80
  alarm_actions = [aws_sns_topic.alerts.arn]
}
```

When CPU exceeds 80% for 4 minutes, the alarm fires and publishes to the SNS topic.
Subscribe an email address or a Lambda function to the topic to receive the notification.

---

## Tagging Implementation

```hcl
locals {
  common_tags = {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = var.project_name
    Owner       = var.team_name
  }
}
```

Applied to security groups:

```hcl
resource "aws_security_group" "instance_sg" {
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-instance-sg" })
}
```

Applied to the ALB:

```hcl
resource "aws_lb" "web" {
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-alb" })
}
```

Applied to ASG instances via `tag` blocks with `propagate_at_launch = true`:

```hcl
resource "aws_autoscaling_group" "web" {
  tag {
    key                 = "Environment"
    value               = var.environment
    propagate_at_launch = true
  }
  tag {
    key                 = "ManagedBy"
    value               = "terraform"
    propagate_at_launch = true
  }
}
```

---

## Lifecycle Rules

```hcl
# create_before_destroy — on Launch Template and ASG
# without this: old ASG destroyed first → instances terminate → app goes down
# with this: new ASG created and healthy before old is destroyed
lifecycle {
  create_before_destroy = true
}

# prevent_destroy — on ALB
# without this: a misconfigured apply could destroy the load balancer and take down all traffic
# with this: Terraform errors before touching the ALB — must explicitly remove to destroy
lifecycle {
  prevent_destroy = true
}
```

---

## CloudWatch Alarms

```hcl
resource "aws_sns_topic" "alerts" {
  name = "${var.cluster_name}-alerts"
  tags = merge(local.common_tags, { Name = "${var.cluster_name}-alerts" })
}

resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = local.actual_monitoring ? 1 : 0
  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeded 80% for 4 minutes on ${var.cluster_name}"
  alarm_actions       = [aws_sns_topic.alerts.arn]

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}
```

Threshold of 80% — chosen because sustained CPU above 80% indicates the cluster is under
real load and needs attention. `evaluation_periods = 2` with `period = 120` means the alarm
fires only after 4 consecutive minutes above 80% — avoids false alarms from brief spikes.

When the alarm fires: publishes a message to the SNS topic. Subscribe an email or a PagerDuty
endpoint to the topic to receive the notification.

---

## Input Validation

```hcl
variable "environment" {
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "instance_type" {
  validation {
    condition     = can(regex("^t[23]\\.", var.instance_type))
    error_message = "Instance type must be a t2 or t3 family type."
  }
}

variable "active_environment" {
  validation {
    condition     = contains(["blue", "green"], var.active_environment)
    error_message = "active_environment must be blue or green."
  }
}
```

Passing `instance_type = "m5.large"` returns:

```
Error: Invalid value for variable
Instance type must be a t2 or t3 family type.
```

Fires at plan time — before any API calls.

---

## GitHub Actions CI Pipeline

Instead of Terratest (which requires Go), a GitHub Actions workflow runs automated
checks on every push to main and every pull request.

```yaml
name: Terraform CI

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    env:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
      AWS_DEFAULT_REGION: eu-north-1
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: "1.11.0"
      - name: Terraform Format Check
        run: terraform fmt -check -recursive
      - name: Validate day16 module
        working-directory: day16/modules/services/webserver-cluster
        run: |
          terraform init -backend=false
          terraform validate
      - name: Plan day16 dev
        id: plan
        working-directory: day16/live/dev/services/webserver-cluster
        run: |
          terraform init
          terraform plan -no-color | tee plan.txt
          echo "stdout<<EOF" >> $GITHUB_OUTPUT
          cat plan.txt >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
        continue-on-error: true
```

What each step does:
- `terraform fmt -check -recursive` — fails if any file is not formatted correctly
- `terraform init -backend=false` — initialises the module without connecting to S3
- `terraform validate` — checks syntax and internal consistency without calling AWS
- `terraform plan` — runs a real plan against AWS using the credentials from GitHub secrets

**Error fixed during setup:**

The original `Plan day16 dev` step had no `id` field. The `Post plan to PR` step referenced
`${{ steps.plan.outputs.stdout }}` but GitHub Actions could not find the step because it had
no id to reference. Fixed by adding `id: plan` to the plan step and capturing the output
properly using `$GITHUB_OUTPUT`.

**GitHub secrets required:**
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Add these under: GitHub repo → Settings → Secrets and variables → Actions

---

## Terratest

```go
package test

import (
    "fmt"
    "testing"
    "time"

    http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
    "github.com/gruntwork-io/terratest/modules/terraform"
)

func TestWebserverCluster(t *testing.T) {
    t.Parallel()

    terraformOptions := terraform.WithDefaultRetryableErrors(t, &terraform.Options{
        TerraformDir: "../modules/services/webserver-cluster",
        Vars: map[string]interface{}{
            "cluster_name":  "test-cluster",
            "instance_type": "t3.micro",
            "min_size":      1,
            "max_size":      2,
            "environment":   "dev",
            "project_name":  "terratest",
            "team_name":     "sarahcodes",
        },
    })

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    albDnsName := terraform.Output(t, terraformOptions, "alb_dns_name")
    url := fmt.Sprintf("http://%s", albDnsName)

    http_helper.HttpGetWithRetry(t, url, nil, 200, "Hello", 30, 10*time.Second)
}
```

What it does:
1. Runs `terraform init` and `terraform apply` with test variables
2. Gets the ALB DNS name from outputs
3. Hits the URL and retries for up to 5 minutes until it gets a 200 response containing "Hello"
4. `defer terraform.Destroy` runs destroy after the test — even if the test fails

`defer` is critical. Without it, a failed assertion would leave real AWS resources running
and incurring cost. `defer` guarantees cleanup regardless of test outcome.

---

## Chapter 8 Learnings

The most important item I had not thought about before today: **consistent tagging**.

I had been adding `Name` tags to some resources and nothing to others. In a real AWS account
with hundreds of resources, untagged resources are impossible to attribute to a team, a
project, or a cost centre. The `merge(local.common_tags, {...})` pattern costs almost nothing
to implement and makes the entire infrastructure auditable.

The biggest surprise: how many items on the checklist I was already passing from previous days.
`create_before_destroy`, `name_prefix`, `sensitive = true`, encrypted remote state, validation
blocks — all of those came from Days 11-15. The checklist is not a new set of things to learn.
It is a way of verifying that the things you have been learning are actually applied consistently.

---

## Challenges and Fixes

- **`prevent_destroy` blocks terraform destroy during testing** — added `prevent_destroy = true`
  to the ALB then immediately tried to run `terraform destroy` to clean up. Terraform errored.
  This is the intended behaviour — had to temporarily remove the lifecycle block to destroy.
  In production this is a feature, not a bug.

- **ASG does not support `tags = merge(...)` syntax** — ASG uses individual `tag {}` blocks
  with `propagate_at_launch`, not a `tags` map argument. Had to add separate `tag {}` blocks
  for each common tag instead of using `merge()`.

- **`can(regex(...))` syntax for instance_type validation** — the `can()` function returns
  true if the expression does not error. `regex()` errors when there is no match, so
  `can(regex("^t[23]\\.", var.instance_type))` returns true only when the instance type
  starts with `t2.` or `t3.`.

---

## Blog Post

URL: *(paste blog URL here)*

Title: **Creating Production-Grade Infrastructure with Terraform**

---

## Social Media

URL: *(paste post URL here)*

> 🚀 Day 16 of the 30-Day Terraform Challenge — production-grade infrastructure deep dive.
> Audited my existing code against the full production checklist: consistent tagging,
> lifecycle rules, CloudWatch alarms, input validation, Terratest. The gap between
> "it works" and "it's production-ready" is significant.
> #30DayTerraformChallenge #TerraformChallenge #Terraform #DevOps #IaC #AWSUserGroupKenya #EveOps
