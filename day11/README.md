# Day 11: Mastering Terraform Conditionals — Smarter, More Flexible Deployments

## What I Did Today

Went deep on Terraform conditionals — refactored the webserver cluster module to be fully
environment-aware using a single `environment` variable that drives instance sizing, cluster
size, and monitoring decisions through a `locals` block. Added a CloudWatch CPU alarm as a
conditionally created resource, added input validation, and documented the brownfield/greenfield
VPC pattern.

---

## Project Structure

```
day11/
├── live/
│   ├── global/iam/                          # from day10 — loops reference
│   ├── dev/services/webserver-cluster/      # environment = "dev", monitoring off
│   └── production/services/webserver-cluster/  # environment = "production", monitoring on
└── modules/services/webserver-cluster/      # fully environment-aware module
```

---

## Locals-Centralised Conditional Logic

All conditional decisions live in one `locals` block at the top of the module.
Resources read from locals — never raw ternary operators inline.

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
  instance_type = local.actual_instance_type   # never a ternary here
}

resource "aws_autoscaling_group" "web" {
  min_size         = local.actual_min_size
  max_size         = local.actual_max_size
  desired_capacity = local.actual_min_size
}
```

**Why this is better than scattering ternaries across resource arguments:**
- All conditional logic is in one place — one read to understand all environment differences
- Resources stay readable — `instance_type = local.actual_instance_type` is clear
- Easier to test — change one local, all downstream resources update
- Easier to extend — add a new environment tier by editing the locals block only

---

## Conditional Resource Creation

### Autoscaling policies — toggled by `enable_autoscaling`

```hcl
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
```

### CloudWatch CPU alarm — toggled by `local.actual_monitoring`

```hcl
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

**Plan output — dev (enable_autoscaling = false, enable_detailed_monitoring = false):**

```
# module.webserver_cluster.aws_autoscaling_policy.scale_in will not be created
  ~ count = 0

# module.webserver_cluster.aws_autoscaling_policy.scale_out will not be created
  ~ count = 0

# module.webserver_cluster.aws_cloudwatch_metric_alarm.high_cpu will not be created
  ~ count = 0
```

**Plan output — production (enable_autoscaling = true, environment = "production"):**

```
# module.webserver_cluster.aws_autoscaling_policy.scale_in will be created
  + name = "webservers-production-scale-in"

# module.webserver_cluster.aws_autoscaling_policy.scale_out will be created
  + name = "webservers-production-scale-out"

# module.webserver_cluster.aws_cloudwatch_metric_alarm.high_cpu will be created
  + alarm_name = "webservers-production-high-cpu"
  + threshold  = 80
```

---

## Safe Output References

```hcl
# SAFE — autoscaling policy ARNs
# for expression over concat() produces an empty map {} when count = 0
# no crash, no null reference error
output "autoscaling_policy_arns" {
  description = "Map of autoscaling policy ARNs — empty when disabled"
  value = {
    for policy in concat(
      aws_autoscaling_policy.scale_out,
      aws_autoscaling_policy.scale_in
    ) : policy.name => policy.arn
  }
}

# SAFE — CloudWatch alarm ARN
# ternary guard returns null when monitoring is disabled
# [0] accesses the single instance when count = 1
output "cloudwatch_alarm_arn" {
  description = "The ARN of the CloudWatch CPU alarm — null when monitoring disabled"
  value       = local.actual_monitoring ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null
}
```

**What happens without the ternary guard:**

```hcl
# WRONG — crashes when count = 0
output "cloudwatch_alarm_arn" {
  value = aws_cloudwatch_metric_alarm.high_cpu[0].arn
}
# Error: Invalid index
# The given key does not identify an element in this collection value.
# aws_cloudwatch_metric_alarm.high_cpu is empty (count = 0)
```

Terraform evaluates outputs even when the resource doesn't exist. The `[0]` index on an empty
list causes a plan-time error. The ternary guard short-circuits evaluation — when the condition
is false, Terraform never tries to access `[0]`.

---

## Environment-Aware Module

### Input validation block

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

**Error when passing an invalid value:**

```
$ terraform plan -var="environment=prod"

╷
│ Error: Invalid value for variable
│
│   on variables.tf line 42, in variable "environment":
│   42:   validation {
│
│ Environment must be dev, staging, or production.
│
│ This was checked by the validation rule at variables.tf:43,5-15.
╵
```

The error fires at plan time — before any API calls are made. Without validation, `"prod"` would
silently be treated as a non-production environment and deploy with dev-sized resources.

### Dev calling configuration

```hcl
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name               = "webservers-dev"
  instance_type              = "t3.micro"
  environment                = "dev"
  enable_autoscaling         = false
  enable_detailed_monitoring = false
}
```

### Production calling configuration

```hcl
module "webserver_cluster" {
  source = "../../../../modules/services/webserver-cluster"

  cluster_name               = "webservers-production"
  instance_type              = "t3.micro"   # overridden by locals — actual = t3.small
  environment                = "production"
  enable_autoscaling         = true
  enable_detailed_monitoring = true
}
```

### Plan diff between dev and production

| Resource / Setting | Dev | Production |
|---|---|---|
| `instance_type` | t3.micro | t3.small (overridden by locals) |
| ASG `min_size` | 1 | 3 |
| ASG `max_size` | 3 | 10 |
| `aws_autoscaling_policy.scale_out` | not created | created |
| `aws_autoscaling_policy.scale_in` | not created | created |
| `aws_cloudwatch_metric_alarm.high_cpu` | not created | created |

---

## Conditional Data Source Pattern

```hcl
# variables.tf
variable "use_existing_vpc" {
  description = "Use an existing VPC instead of the default"
  type        = bool
  default     = false
}

# main.tf — brownfield: look up existing VPC only when requested
data "aws_vpc" "existing" {
  count = var.use_existing_vpc ? 1 : 0
  tags = {
    Name = "existing-vpc"
  }
}

# greenfield: create a new VPC only when not using existing
resource "aws_vpc" "new" {
  count      = var.use_existing_vpc ? 0 : 1
  cidr_block = "10.0.0.0/16"
}

# single local resolves which VPC ID to use downstream
locals {
  vpc_id = var.use_existing_vpc ? data.aws_vpc.existing[0].id : aws_vpc.new[0].id
}
```

**Greenfield** (`use_existing_vpc = false`): Terraform creates a new VPC. Use this for fresh
environments with no existing infrastructure.

**Brownfield** (`use_existing_vpc = true`): Terraform looks up an existing VPC by tag and uses
its ID. Use this when deploying into an account that already has networking set up — avoids
creating duplicate VPCs and conflicting CIDR ranges.

The `local.vpc_id` abstraction means every resource downstream just references `local.vpc_id`
and works correctly in both cases without any changes.

---

## Chapter 5 Learnings

**Conditional expression vs conditional resource creation:**

A conditional expression (`condition ? a : b`) is just a value — it evaluates to one of two
values at plan time. It doesn't create or destroy anything. You use it inside arguments:
`instance_type = local.is_production ? "t3.small" : "t3.micro"`.

Conditional resource creation (`count = condition ? 1 : 0`) controls whether a resource block
produces an actual AWS resource. When `count = 0`, the resource block exists in the config but
Terraform creates nothing. These are different tools — one picks a value, the other decides
whether to create infrastructure.

**Can you use a conditional to choose between two different resource types?**

No. A ternary expression can only choose between two values of the same type — you can't write
`count = condition ? aws_instance.web : aws_ecs_service.web`. Terraform's type system requires
both branches to be the same type. To conditionally use different resource types, you use
`count = 0/1` on each resource type separately and reference whichever one was created.

---

## Challenges and Fixes

- **`terraform init` context deadline exceeded** — registry.terraform.io was unreachable on
  first attempt. Confirmed internet was working (`ping 8.8.8.8` succeeded, `curl` to the
  registry also succeeded). Retried `terraform init` and it worked — was a transient timeout.

- **`[0]` index error on disabled CloudWatch alarm** — first version of the output used
  `aws_cloudwatch_metric_alarm.high_cpu[0].arn` directly. Got `Invalid index` error at plan
  time when `enable_detailed_monitoring = false`. Fixed by wrapping in the ternary guard:
  `local.actual_monitoring ? aws_cloudwatch_metric_alarm.high_cpu[0].arn : null`.

- **`local.actual_monitoring` vs `var.enable_detailed_monitoring`** — initially used the
  variable directly in the `count` expression. Realised production should always have monitoring
  on regardless of what the caller passes. Moved the decision into `locals` so
  `actual_monitoring = local.is_production ? true : var.enable_detailed_monitoring` — production
  always gets monitoring, dev only gets it if explicitly enabled.

- **Validation block rejecting `"prod"`** — tested passing `environment = "prod"` and confirmed
  the validation fires immediately at plan time with the correct error message. This is the
  intended behaviour.

---

## Blog Post

URL: *(paste blog URL here)*

Covered the full conditional toolkit: ternary expressions, `count = condition ? 1 : 0`,
safe output references with `[0]` guards, input validation blocks, and the environment-aware
locals pattern. Led with the problem — scattered ternaries in resource arguments — then showed
how centralising in `locals` fixes it. Included the brownfield/greenfield VPC pattern as the
practical data source conditional example.

---

## Social Media

URL: *(paste post URL here)*

> 💡 Day 11 of the 30-Day Terraform Challenge — conditionals deep dive. One Terraform
> configuration, multiple environments, zero code duplication. Environment-aware modules with
> input validation are genuinely powerful. #30DayTerraformChallenge #TerraformChallenge
> #Terraform #IaC #DevOps #AWSUserGroupKenya #EveOps
