# Day 21: Workflow for Deploying Infrastructure Code

## What I Did Today

Applied the seven-step deployment workflow to a real infrastructure change — added a
low CPU CloudWatch alarm and tightened the high CPU threshold from 80% to 70%.
Deployed end-to-end, implemented all four infrastructure-specific safeguards, and
wrote a Sentinel policy enforcing approved instance types.



## Project Structure

```
day21/
├── modules/services/webserver-cluster/   # adds low_cpu alarm, threshold 80→70%
├── live/dev/services/webserver-cluster/  # app_version = "v4"
└── sentinel/require-instance-type.sentinel
```



## Seven-Step Walkthrough

### Step 1 — Version Control

Code lives in the `30daysof-TerraformChallenge` GitHub repository. Main branch is
protected — no direct pushes, PRs require reviewer approval, status checks must pass.

State file is NOT in Git. It lives in the encrypted S3 backend:
`sarahcodes-terraform-state-2026/day21/dev/services/webserver-cluster/terraform.tfstate`

**Note:** During this day I accidentally pushed directly to main instead of creating
a feature branch first. Documented honestly — this is exactly the kind of mistake
branch protection rules are designed to prevent.



### Step 2 — Run the Code Locally

```bash
cd day21/live/dev/services/webserver-cluster
terraform init -reconfigure
terraform plan -out=day21.tfplan
```

**Plan output:**

```
Plan: 11 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_dns_name       = (known after apply)
  + asg_name           = (known after apply)
  + instance_type_used = "t3.micro"
  + sns_topic_arn      = (known after apply)

Saved the plan to: day21.tfplan
```

11 resources (not 13) because `enable_detailed_monitoring = false` in dev — the two
CloudWatch alarms use `count = local.actual_monitoring ? 1 : 0` so they are not
created in dev. Zero destructions — no extra approval gate required.



### Step 3 — Make Code Changes

Infrastructure change in `modules/services/webserver-cluster/main.tf`:

1. Added `aws_cloudwatch_metric_alarm.low_cpu` — fires when CPU < 10% for 4 minutes,
   detects idle or over-provisioned clusters
2. Tightened `high_cpu` threshold from 80% → 70% — earlier warning before saturation

```bash
git checkout -b add-cloudwatch-alarms-day21
git add day21/
git commit -m "Add low CPU alarm and tighten high CPU threshold to 70%"
git push origin add-cloudwatch-alarms-day21
```



### Step 4 — Submit for Review

#### PR Description

## What this changes

Adds a low CPU CloudWatch alarm to detect over-provisioned clusters. Tightens the
high CPU alarm threshold from 80% to 70% for earlier warning. Bumps app_version to v4.

## Terraform plan output

```
Plan: 11 to add, 0 to change, 0 to destroy.

+ module.webserver_cluster.aws_autoscaling_group.web
+ module.webserver_cluster.aws_cloudwatch_log_group.web
+ module.webserver_cluster.aws_launch_template.web
+ module.webserver_cluster.aws_lb.web
+ module.webserver_cluster.aws_lb_listener.web
+ module.webserver_cluster.aws_lb_listener_rule.blue_green
+ module.webserver_cluster.aws_lb_target_group.blue
+ module.webserver_cluster.aws_lb_target_group.green
+ module.webserver_cluster.aws_security_group.alb_sg
+ module.webserver_cluster.aws_security_group.instance_sg
+ module.webserver_cluster.aws_sns_topic.alerts
```

## Resources affected
- Created: 11
- Modified: 0
- Destroyed: 0

## Blast radius

Both alarms are additive — no existing resources are modified or deleted. If the
apply fails partway through, the ALB and ASG continue serving traffic without alarms.
Alarms can be re-applied safely on the next run.

## Rollback plan

No destructions in this change. If alarms cause unexpected behaviour, remove the
`aws_cloudwatch_metric_alarm` blocks and re-apply. The cluster is unaffected.



### Step 5 — Automated Tests

GitHub Actions triggered automatically on the PR:

```
Terraform CI / Validate and Plan    — Successful in 34s
Terraform Tests / Unit Tests        — Successful in 35s
Terraform Tests / Validate and Plan — Successful in 27s
Integration Tests                   — Skipped (PR only)
```



### Step 6 — Merge and Release

```bash
git tag -a "v1.4.0" -m "Add low CPU alarm and tighten high CPU threshold to 70%"
git push origin v1.4.0
```

```
* [new tag] v1.4.0 -> v1.4.0
```



### Step 7 — Deploy

Applied from the saved plan file:

```bash
terraform apply "day21.tfplan"
```

```
Apply complete! Resources: 11 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name       = "webservers-dev-alb-948498595.eu-north-1.elb.amazonaws.com"
asg_name           = "webservers-dev-20260409122635469300000003"
instance_type_used = "t3.micro"
sns_topic_arn      = "arn:aws:sns:eu-north-1:629836545449:webservers-dev-alerts"
```

Verified v4 is live:

```
Hello from webservers-dev — v4 — ip-172-31-32-67.eu-north-1.compute.internal
```

Ran `terraform plan` immediately after — returned clean:

```
No changes. Your infrastructure matches the configuration.
```



## Infrastructure-Specific Safeguards

### 1. Approval Gates for Destructive Changes

This plan had zero destructions so no extra approval was required. The rule: if
`terraform plan` shows any resource destructions, a second explicit approval is
required in Terraform Cloud before apply — separate from the PR review.

Why: a reviewer can miss a destruction buried in a long plan output. The second
approval forces someone to explicitly acknowledge it.

### 2. Plan File Pinning

```bash
# Step 2 — save the reviewed plan
terraform plan -out=day21.tfplan

# Step 7 — apply exactly what was reviewed
terraform apply "day21.tfplan"
```

`terraform apply` without a plan file generates a fresh plan at apply time. If
another engineer applied something between your plan and your apply, the fresh plan
will differ from what you reviewed. The saved plan file eliminates that risk.

`*.tfplan` is in `.gitignore` — plan files contain sensitive resource details.

### 3. State Backup Before Apply

S3 versioning is enabled on `sarahcodes-terraform-state-2026`. To list available
state versions for recovery:

```bash
aws s3api list-object-versions \
  --bucket sarahcodes-terraform-state-2026 \
  --prefix day21/dev/services/webserver-cluster/terraform.tfstate
```

To restore a previous version if an apply corrupts state:

```bash
aws s3api get-object \
  --bucket sarahcodes-terraform-state-2026 \
  --key day21/dev/services/webserver-cluster/terraform.tfstate \
  --version-id <VERSION_ID> \
  terraform.tfstate.restored
```

### 4. Blast Radius Documentation

Both CloudWatch alarms are additive — they attach to the existing ASG but do not
modify it. Shared infrastructure (VPC, security groups, IAM roles) is not touched.
If apply fails midway, the cluster continues serving traffic without alarms.



## Sentinel Policy

```python
# sentinel/require-instance-type.sentinel

import "tfplan/v2" as tfplan

allowed_instance_types = ["t2.micro", "t2.small", "t2.medium", "t3.micro", "t3.small"]

main = rule {
  all tfplan.resource_changes as _, rc {
    rc.type is not "aws_instance" or
    rc.change.after.instance_type in allowed_instance_types
  }
}
```

**What it enforces in plain English:**

Every `aws_instance` resource in the plan must use one of the five approved instance
types. If any instance uses a type outside that list — for example `m5.xlarge` —
the policy fails and Terraform Cloud blocks the apply before it runs. Non-instance
resources (ALBs, security groups, etc.) are not affected.

**What it would block:**

```hcl
# This would be blocked — m5.xlarge is not in the allowed list
resource "aws_instance" "example" {
  instance_type = "m5.xlarge"
}
```

**How it differs from `terraform validate`:**

`terraform validate` checks syntax and type correctness — it cannot enforce business
rules or check the value of `instance_type`. Sentinel runs after the plan is generated
and enforces organisational policy on the actual resource values. Engineers cannot
bypass it — it runs server-side in Terraform Cloud.



## Infrastructure vs Application Workflow — Key Differences

**1. The plan IS the diff**

In application code, the PR diff shows changed lines of code. In infrastructure, the
`.tf` diff tells you nothing about what AWS resources will actually change. The
`terraform plan` output is the real diff — it must be in the PR description so
reviewers understand the blast radius without running Terraform themselves.

**2. State files create shared mutable state**

Two engineers can run the same application binary simultaneously with no conflict.
Two engineers running `terraform apply` against the same state file will corrupt it.
State locking via DynamoDB and plan file pinning exist specifically because of this.

**3. Mistakes are not easily rolled back**

A bad application deploy can be rolled back in minutes by deploying the previous
version. A bad `terraform apply` that destroys a production RDS instance cannot be
rolled back — the data is gone. This asymmetry of consequences demands extra
safeguards that have no equivalent in application deployment.



## Chapter 10 Learnings

The author identifies `terraform apply` as the most dangerous step — specifically
the gap between `terraform plan` and `terraform apply`. If infrastructure changes
between the two commands, the apply may do something different from what was reviewed.

The safeguard he recommends that most teams skip is **plan file pinning** — saving
the plan with `-out=reviewed.tfplan` and applying from that exact file. Most teams
run `terraform apply` directly, which generates a fresh plan at apply time and
bypasses the review entirely.



## Challenges and Fixes

**Pushed directly to main instead of creating a feature branch:**
Ran `git add` and `git commit` from the repo root without first running
`git checkout -b add-cloudwatch-alarms-day21`. The code went straight to main.
This is exactly the mistake branch protection rules prevent — on a real team this
push would have been rejected. Documented honestly.

**`enable_detailed_monitoring = false` means alarms are not created in dev:**
The `low_cpu` and `high_cpu` alarms use `count = local.actual_monitoring ? 1 : 0`.
In dev with monitoring off, count = 0, no alarms are deployed. Plan showed 11
resources not 13. To test alarm creation, set `enable_detailed_monitoring = true`
or deploy to production where `local.is_production = true` forces monitoring on.

**`dynamodb_table` deprecation warning:**
```
Warning: Deprecated Parameter
The parameter "dynamodb_table" is deprecated. Use parameter "use_lockfile" instead.
```
This is a warning from the newer AWS provider version — the parameter still works
but will be removed in a future version. Will update to `use_lockfile = true` in
a future day.


