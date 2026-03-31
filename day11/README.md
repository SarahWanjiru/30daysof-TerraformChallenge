# Day 11: Mastering Terraform Conditionals — Smarter, More Flexible Deployments

## What I Did Today

Went deep on Terraform conditionals — refactored the webserver cluster module to be fully
environment-aware using a single `environment` variable that drives instance sizing, cluster
size, and monitoring decisions through a `locals` block. Added a CloudWatch CPU alarm as a
conditionally created resource, added input validation, and documented the brownfield/greenfield
VPC pattern. Deployed both dev and production and confirmed the conditional logic works correctly.

---

## Project Structure

```
day11/
├── live/
│   ├── global/iam/                              # day10 loops reference
│   ├── dev/services/webserver-cluster/          # environment = "dev"
│   └── production/services/webserver-cluster/  # environment = "production"
└── modules/services/webserver-cluster/          # fully environment-aware module
```

---

## Pattern 1 — Locals-Centralised Conditional Logic

All conditional decisions live in one `locals` block. Resources read from locals — no raw
ternary operators inside resource arguments.

```hcl
locals {
  is_production = var.environment == "production"

  # instance sizing — production gets t3.small automatically
  actual_instance_type = local.is_production ? "t3.small" : var.instance_type

  # cluster sizing — production runs more instances
  actual_min_size = local.is_production ? 3 : var.min_size
  actual_max_size = local.is_production ? 10 : var.max_size

  # monitoring — always on in production regardless of the variable
  actual_monitoring = local.is_production ? true : var.enable_detailed_monitoring
}
```

Resources then reference locals cleanly:

```hcl
resource "aws_launch_template" "web" {
  instance_type = local.actual_instance_type
}

resource "aws_autoscaling_group" "web" {
  min_size         = local.actual_min_size
  max_size         = local.actual_max_size
  desired_capacity = local.actual_min_size
}
```

Why this matters — if the production instance type needs to change, one line in `locals` updates
it everywhere. No hunting through resource arguments.

---

## Pattern 2 — Input Validation Block

```hcl
variable "environment" {
  description = "Deployment environment: dev, staging, or production"
  type        = string
  default     = "dev"

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}
```

To make the validation testable from the command line, a root-level `environment` variable was
added to the dev calling config that passes through to the module:

```hcl
# live/dev/services/webserver-cluster/main.tf
variable "environment" {
  description = "Deployment environment passed through to module validation"
  type        = string
  default     = "dev"
}

module "webserver_cluster" {
  source      = "../../../../modules/services/webserver-cluster"
  environment = var.environment   # now overridable via -var
  ...
}
```

**Validation error when passing an invalid value:**

```
$ terraform plan -var="environment=prod"

╷
│ Error: Invalid value for variable
│
│   on ../../../../modules/services/webserver-cluster/variables.tf line 42,
│   in variable "environment":
│   42:   validation {
│
│ Environment must be dev, staging, or production.
│
│ This was checked by the validation rule at variables.tf:43,5-15.
╵
```

Fires at plan time — before any API calls. Without this, `"prod"` would silently deploy with
dev-sized resources.

**First attempt error — before the fix:**

```
$ terraform plan -var="environment=prod"

╷
│ Error: Value for undeclared variable
│
│ A variable named "environment" was assigned on the command line, but the root
│ module does not declare a variable of that name.
╵
```

Fix: added the root-level `variable "environment"` block so `-var` has somewhere to land.

---

## Pattern 3 — Conditional Resource Creation

```hcl
# autoscaling policies — skipped entirely when enable_autoscaling = false
resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

resource "aws_autoscaling_policy" "scale_in" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-in"
  autoscaling_group_name = aws_autoscaling_group.web.name
  policy_type            = "SimpleScaling"
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = -1
  cooldown               = 300
}

# CloudWatch alarm — uses local.actual_monitoring so production always gets it
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count = local.actual_monitoring ? 1 : 0

  alarm_name          = "${var.cluster_name}-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "CPU utilization exceeded 80% on ${var.cluster_name}"

  dimensions = {
    AutoScalingGroupName = aws_autoscaling_group.web.name
  }
}
```

**Dev plan — 7 resources, no alarm, no scaling policies:**

```
Plan: 7 to add, 0 to change, 0 to destroy.

instance_type_used = "t3.micro"
min_size_used      = 1
max_size_used      = 3
cloudwatch_alarm_arn = null
```

**Production plan — 10 resources, alarm created, scaling policies created:**

```
Plan: 10 to add, 0 to change, 0 to destroy.

instance_type_used   = "t3.small"
min_size_used        = 3
max_size_used        = 10
cloudwatch_alarm_arn = "arn:aws:cloudwatch:eu-north-1:629836545449:alarm:webservers-production-high-cpu"
```

---

## Pattern 4 — Safe Output References

```hcl
# SAFE — for expression over concat() returns empty map {} when count = 0
output "autoscaling_policy_arns" {
  description = "Map of autoscaling policy ARNs — empty when disabled"
  value = {
    for policy in concat(
      aws_autoscaling_policy.scale_out,
      aws_autoscaling_policy.scale_in
    ) : policy.name => policy.arn
  }
}

# SAFE — ternary guard returns null when monitoring is disabled
output "cloudwatch_alarm_arn" {
  description = "The ARN of the CloudWatch CPU alarm — null when monitoring disabled"
  value       = local.actual_monitoring ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
}
```

Without the ternary guard:

```hcl
# BROKEN — crashes at plan time when count = 0
output "cloudwatch_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.high_cpu[0].arn
}
# Error: Invalid index
# aws_cloudwatch_metric_alarm.high_cpu is empty tuple
```

Terraform evaluates outputs even when the resource doesn't exist. The `[0]` on an empty list
causes a plan-time crash. The ternary guard short-circuits — when false, Terraform never
evaluates `[0]`.

---

## Pattern 5 — Conditional Data Source Lookups

```hcl
variable "use_existing_vpc" {
  description = "Use an existing VPC instead of the default"
  type        = bool
  default     = false
}

# brownfield — look up existing VPC only when requested
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  tags  = { Name = "existing-vpc" }
}

# greenfield — create new VPC only when not using existing
resource "aws_vpc" "new" {
  count      = var.use_existing_vpc ? 0 : 1
  cidr_block = "10.0.0.0/16"
}

# single local — all downstream resources just use local.vpc_id
locals {
  vpc_id = var.use_existing_vpc ? data.aws_vpc.existing[0].id : aws_vpc.new[0].id
}
```

- Greenfield (`use_existing_vpc = false`) — fresh AWS account, Terraform creates the VPC
- Brownfield (`use_existing_vpc = true`) — existing account, Terraform looks up the VPC by tag

Same module, one boolean toggle, works in both scenarios.

---

## Real Deployment Outputs

### Dev (`environment = "dev"`, `enable_autoscaling = false`, `enable_detailed_monitoring = false`)

```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name         = "webservers-dev-alb-1330238721.eu-north-1.elb.amazonaws.com"
instance_type_used   = "t3.micro"
min_size_used        = 1
max_size_used        = 3
cloudwatch_alarm_arn = null
```

### Production (`environment = "production"`, `enable_autoscaling = true`, `enable_detailed_monitoring = true`)

```
Apply complete! Resources: 10 added, 0 changed, 0 destroyed.

Outputs:

alb_dns_name         = "webservers-production-alb-1211147999.eu-north-1.elb.amazonaws.com"
instance_type_used   = "t3.small"
min_size_used        = 3
max_size_used        = 10
cloudwatch_alarm_arn = "arn:aws:cloudwatch:eu-north-1:629836545449:alarm:webservers-production-high-cpu"
```

Key differences proven by the real outputs:
- Instance type: `t3.micro` → `t3.small` (driven by `is_production` local, not the caller)
- Min size: `1` → `3`
- Max size: `3` → `10`
- CloudWatch alarm: `null` → real ARN
- Resource count: `7` → `10` (3 extra: scale_out policy, scale_in policy, CloudWatch alarm)

---

## Chapter 5 Learnings

**Conditional expression vs conditional resource creation:**

A conditional expression (`condition ? a : b`) picks a value — it doesn't create or destroy
anything. `instance_type = local.is_production ? "t3.small" : "t3.micro"` just selects a string.

Conditional resource creation (`count = condition ? 1 : 0`) controls whether AWS infrastructure
gets created at all. When `count = 0` the block exists in config but Terraform creates nothing.

**Can you use a conditional to choose between two different resource types?**

No. Both branches of a ternary must be the same type. You can't write
`count = condition ? aws_instance.web : aws_ecs_service.app`. To conditionally use different
resource types, use `count = 0/1` on each separately and reference whichever was created.

---

## Challenges and Fixes

- **`Value for undeclared variable` when testing validation** — ran
  `terraform plan -var="environment=prod"` expecting the module validation to fire. Got
  `Value for undeclared variable` because `environment` was hardcoded in the module call.
  Fix: added a root-level `variable "environment"` block with `default = "dev"` and changed
  the module call to `environment = var.environment`. The `-var` flag now passes through to
  the module and triggers the validation correctly.

- **Production needed `terraform init` before `terraform plan`** — forgot that each environment
  directory needs its own `terraform init` since they have separate backends. Ran `terraform init`
  then `terraform apply` and it worked.

- **`cloudwatch_alarm_arn` output missing from dev** — dev outputs didn't show
  `cloudwatch_alarm_arn` at first. Confirmed it returns `null` when `enable_detailed_monitoring
  = false` — this is correct behaviour, not a bug.

---

## Blog Post

URL: *(paste blog URL here)*

Title: **How Conditionals Make Terraform Infrastructure Dynamic and Efficient**

Covered all five conditional patterns with real code and real deployment outputs. Led with the
problem — scattered ternaries in resource arguments — then showed how centralising in `locals`
with `is_production` as a single source of truth fixes it. Included the actual dev vs production
output diff as proof the conditionals work. Documented both real errors hit during the day —
the `[0]` index crash and the `Value for undeclared variable` error — with the exact terminal
output and the fix for each.

---

## Social Media

URL: *(paste post URL here)*

> 💡 Day 11 of the 30-Day Terraform Challenge — conditionals deep dive. One Terraform
> configuration, multiple environments, zero code duplication. Environment-aware modules with
> input validation are genuinely powerful. #30DayTerraformChallenge #TerraformChallenge
> #Terraform #IaC #DevOps #AWSUserGroupKenya #EveOps
