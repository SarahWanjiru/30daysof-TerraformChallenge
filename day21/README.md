# Day 21: Workflow for Deploying Infrastructure Code

## What I Did Today

Applied the seven-step deployment workflow to infrastructure code, ran a complete
end-to-end deployment of a real infrastructure change (added low CPU CloudWatch alarm
and tightened high CPU threshold from 80% to 70%), implemented all four
infrastructure-specific safeguards, and wrote a Sentinel policy enforcing approved
instance types.



## Project Structure

```
day21/
├── modules/services/webserver-cluster/   # module — adds low_cpu alarm, threshold 80→70%
├── live/dev/services/webserver-cluster/  # calling config — app_version = "v4"
└── sentinel/require-instance-type.sentinel
```



## Seven-Step Walkthrough

### Step 1 — Version Control

Code lives in the `30daysof-TerraformChallenge` GitHub repository. Main branch is
protected — no direct pushes, PRs require at least one reviewer approval, and status
checks must pass before merge.

State file is NOT in Git. It lives in the encrypted S3 backend:
`sarahcodes-terraform-state-2026/day21/dev/services/webserver-cluster/terraform.tfstate`



### Step 2 — Run the Code Locally

```bash
cd day21/live/dev/services/webserver-cluster
terraform init
terraform plan -out=day21.tfplan
```

Reviewed the plan output carefully:
- Resources to create: 13
- Resources to modify: 0
- Resources to destroy: 0

No destructions — safe to proceed without extra approval gate.

Plan output summary:
```
Plan: 13 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alb_dns_name       = (known after apply)
  + asg_name           = (known after apply)
  + instance_type_used = "t3.micro"
  + sns_topic_arn      = (known after apply)

Saved the plan to: day21.tfplan
```



### Step 3 — Make Code Changes

Infrastructure change: added `aws_cloudwatch_metric_alarm.low_cpu` to detect idle
clusters, and tightened the high CPU threshold from 80% to 70% for earlier warning.

```bash
git checkout -b add-cloudwatch-alarms-day21
# made changes to modules/services/webserver-cluster/main.tf and outputs.tf
terraform plan -out=day21.tfplan
git add .
git commit -m "Add low CPU alarm and tighten high CPU threshold to 70%"
git push origin add-cloudwatch-alarms-day21
```



### Step 4 — Submit for Review

Opened a pull request with the full plan output in the description.

#### PR Description

## What this changes

Adds a low CPU CloudWatch alarm to detect over-provisioned clusters. Tightens the
high CPU alarm threshold from 80% to 70% for earlier warning before instances saturate.
Bumps app_version to v4.

## Terraform plan output

```
Plan: 13 to add, 0 to change, 0 to destroy.
+ aws_cloudwatch_metric_alarm.high_cpu[0]
+ aws_cloudwatch_metric_alarm.low_cpu[0]
+ aws_autoscaling_group.web
+ aws_autoscaling_policy.scale_in (disabled)
+ aws_autoscaling_policy.scale_out (disabled)
+ aws_cloudwatch_log_group.web
+ aws_lb.web
+ aws_lb_listener.web
+ aws_lb_listener_rule.blue_green
+ aws_lb_target_group.blue
+ aws_lb_target_group.green
+ aws_security_group.alb_sg
+ aws_security_group.instance_sg
+ aws_sns_topic.alerts
```

## Resources affected
- Created: 13
- Modified: 0
- Destroyed: 0

## Blast radius

Both alarms are additive — no existing resources are modified or deleted. If the
apply fails partway through, the ALB and ASG may exist without alarms attached.
The cluster continues serving traffic. Alarms can be re-applied safely.

## Rollback plan

No destructions in this change. If alarms cause unexpected behaviour, remove the
`aws_cloudwatch_metric_alarm` blocks and re-apply. The cluster is unaffected.



### Step 5 — Run Automated Tests

GitHub Actions runs automatically on every PR:

```
 Terraform CI / Validate and Plan    — terraform validate + terraform fmt --check
 Terraform Tests / Unit Tests        — terraform test (unit)
 Terraform Tests / Validate and Plan — plan against dev state
 Terraform Tests / Integration Tests — skipped on PR, runs on merge to main
```

All checks green before merge.



### Step 6 — Merge and Release

```bash
git tag -a "v1.4.0" -m "Add low CPU alarm and tighten high CPU threshold to 70%"
git push origin v1.4.0
```

```
* [new tag] v1.4.0 -> v1.4.0
```



### Step 7 — Deploy

Applied from the saved plan file — exactly what was reviewed:

```bash
terraform apply day21.tfplan
```

```
Apply complete! Resources: 13 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name       = "webservers-dev-alb-xxxxxxxxx.eu-north-1.elb.amazonaws.com"
asg_name           = "webservers-dev-xxxxxxxxx"
instance_type_used = "t3.micro"
sns_topic_arn      = "arn:aws:sns:eu-north-1:629836545449:webservers-dev-alerts"
```

Verified in AWS Console — CloudWatch shows both `webservers-dev-high-cpu` and
`webservers-dev-low-cpu` alarms in OK state.

Ran `terraform plan` immediately after — returned clean (0 changes).



## Infrastructure-Specific Safeguards

### 1. Approval Gates for Destructive Changes

This plan had zero destructions so no extra approval was required. The rule:
if `terraform plan` shows any resource destructions, a second explicit approval
is required in Terraform Cloud before apply is permitted — separate from the PR review.

### 2. Plan File Pinning

Always apply from the saved plan file, never from a fresh plan:

```bash
# Step 2 — save the reviewed plan
terraform plan -out=day21.tfplan

# Step 7 — apply exactly what was reviewed
terraform apply day21.tfplan
```

The gap between `terraform plan` and `terraform apply` can introduce drift if
infrastructure changes between the two commands. The saved plan file eliminates that risk.

`*.tfplan` is in `.gitignore` — plan files contain sensitive resource details and
must never be committed to Git.

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

Both CloudWatch alarms are additive resources — they attach to the existing ASG but
do not modify it. Shared infrastructure (VPC, security groups, IAM roles) is not
touched by this change. If the apply fails midway, the cluster continues serving
traffic without alarms. No other environments or resources depend on these alarms.



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
types. If any instance uses a type outside that list — for example `m5.xlarge` or
`c5.2xlarge` — the policy fails and Terraform Cloud blocks the apply before it runs.
Non-instance resources (security groups, ALBs, etc.) are not affected by this policy.

**What it would block:**

```hcl
# This would be blocked — m5.xlarge is not in the allowed list
resource "aws_instance" "example" {
  instance_type = "m5.xlarge"
}
```

**How it differs from `terraform validate`:**

`terraform validate` checks syntax and type correctness — it cannot enforce business
rules. Sentinel runs after the plan is generated and enforces organisational policy
on the actual resource values. `terraform validate` cannot block a valid but
expensive instance type. Sentinel can.

---

## Infrastructure vs Application Workflow — Key Differences

**1. The plan IS the diff**

In application code, the PR diff shows what lines of code changed. In infrastructure,
the PR diff shows `.tf` file changes but that tells you nothing about what AWS
resources will actually change. The `terraform plan` output is the real diff — it
must be pasted into the PR description so reviewers understand the blast radius
without running Terraform themselves.

**2. State files create shared mutable state**

Application code has no equivalent of the state file. Two engineers can run the same
application binary simultaneously with no conflict. Two engineers running
`terraform apply` simultaneously against the same state file will corrupt it.
State locking via DynamoDB and the saved plan file workflow exist specifically because
of this problem.

**3. Mistakes are not easily rolled back**

A bad application deploy can be rolled back by deploying the previous version in
minutes. A bad `terraform apply` that destroys a production RDS instance cannot be
rolled back — the data is gone. This is why approval gates for destructive changes,
plan file pinning, and state backups have no equivalent in application deployment.
The asymmetry of consequences demands extra safeguards.



## Chapter 10 Learnings

The author identifies `terraform apply` as the most dangerous step — specifically
the gap between `terraform plan` and `terraform apply`. If infrastructure changes
between the two commands (another engineer applies something, a resource drifts),
the apply may do something different from what was reviewed. The safeguard he
recommends that most teams skip is **plan file pinning** — saving the plan with
`-out=reviewed.tfplan` and applying from that exact file. Most teams run
`terraform apply` directly, which generates a fresh plan at apply time and bypasses
the review entirely.



## Challenges and Fixes

**`*.tfplan` not in `.gitignore`:**
Plan files contain sensitive resource attribute values. Added `*.tfplan` to
`.gitignore` before committing.

**`enable_detailed_monitoring = false` means alarms are not created:**
The `low_cpu` and `high_cpu` alarms use `count = local.actual_monitoring ? 1 : 0`.
In dev with `enable_detailed_monitoring = false`, alarms are not deployed.
To test alarm creation, set `enable_detailed_monitoring = true` in the module call
or use a production environment where `local.is_production = true` forces monitoring on.

