# Day 10: Terraform Loops and Conditionals — Dynamic Infrastructure at Scale

## What I Did Today

Replaced static, copy-pasted resource blocks with dynamic infrastructure using `count`, `for_each`, `for` expressions, and ternary conditionals. Added an `enable_autoscaling` toggle and environment-based instance sizing to the webserver cluster module. Created a global IAM configuration that demonstrates all four loop/conditional patterns side by side.



## Project Structure


day10/
├── live/
│   ├── global/iam/          # count, for_each, for expression demos
│   ├── dev/services/webserver-cluster/     # enable_autoscaling = false
│   └── production/services/webserver-cluster/  # enable_autoscaling = true
└── modules/services/webserver-cluster/    # refactored with conditionals




## count Example

`count` creates N copies of a resource. `count.index` gives the zero-based position of each instance.

```hcl
# 3 identical users — count.index gives 0, 1, 2
resource "aws_iam_user" "count_example" {
  count = 3
  name  = "sarahcodes-user-${count.index}"
}
# creates: sarahcodes-user-0, sarahcodes-user-1, sarahcodes-user-2


### The breakage scenario

hcl
variable "user_names" {
  type    = list(string)
  default = ["alice", "bob", "charlie"]
}

resource "aws_iam_user" "list_example" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}


Resources are addressed by index: `aws_iam_user.list_example[0]` = alice, `[1]` = bob, `[2]` = charlie.

Remove `"alice"` from position 0 and Terraform sees:
- `[0]` was alice → now bob → **update** (rename)
- `[1]` was bob → now charlie → **update** (rename)
- `[2]` was charlie → no longer exists → **destroy**

Two users get renamed and one gets destroyed — none of that was intended. This is the core `count` problem with mutable lists.



## for_each Example

`for_each` keys each resource on a stable value (the set element or map key) rather than a position. Removing one entry only touches that one resource.

### With a set

hcl
variable "safe_user_names" {
  type    = set(string)
  default = ["dave", "eve", "frank"]
}

resource "aws_iam_user" "foreach_set_example" {
  for_each = var.safe_user_names
  name     = each.value
}
# resources addressed as: aws_iam_user.foreach_set_example["dave"] etc.
# removing "dave" only destroys dave — eve and frank are untouched


### With a map (extra data per user)

hcl
variable "users" {
  type = map(object({
    department = string
    admin      = bool
  }))
  default = {
    grace = { department = "engineering", admin = true  }
    henry = { department = "marketing",   admin = false }
    iris  = { department = "devops",      admin = true  }
  }
}

resource "aws_iam_user" "foreach_map_example" {
  for_each = var.users
  name     = each.key
  tags = {
    Department = each.value.department
    Admin      = each.value.admin
  }
}


`each.key` is the map key (`"grace"`, `"henry"`, `"iris"`). `each.value` is the object. This is safer than `count` because identity is tied to the key, not a position that shifts when the collection changes.



## for Expression

`for` expressions transform collections inline — they don't create resources, they reshape data for outputs and locals.

hcl
# List of uppercase names from a plain list variable
output "upper_names" {
  description = "All user names in uppercase"
  value       = [for name in var.user_names : upper(name)]
}
# result: ["ALICE", "BOB", "CHARLIE"]

# Map of username → ARN from the for_each map resource
output "user_arns" {
  description = "Map of username to ARN for map users"
  value       = { for name, user in aws_iam_user.foreach_map_example : name => user.arn }
}
# result: { grace = "arn:aws:iam::...", henry = "arn:...", iris = "arn:..." }

# Map of username → ARN from the for_each set resource
output "set_user_arns" {
  description = "Map of username to ARN for set users"
  value       = { for name, user in aws_iam_user.foreach_set_example : name => user.arn }
}


The `user_arns` output is useful because it gives callers a single structured value to look up any user's ARN by name — much cleaner than outputting a raw list and having to remember which index maps to which user.



## Conditional Logic

### enable_autoscaling toggle

Added to the webserver cluster module. When `false`, neither scaling policy is created. When `true`, both are created.

hcl
# modules/services/webserver-cluster/variables.tf
variable "enable_autoscaling" {
  description = "Enable autoscaling for the cluster"
  type        = bool
  default     = true
}

# modules/services/webserver-cluster/main.tf
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


**Plan output — enable_autoscaling = false (dev):**

# module.webserver_cluster.aws_autoscaling_policy.scale_in will not be created (count = 0)
# module.webserver_cluster.aws_autoscaling_policy.scale_out will not be created (count = 0)


**Plan output — enable_autoscaling = true (production):**

# module.webserver_cluster.aws_autoscaling_policy.scale_in will be created
# module.webserver_cluster.aws_autoscaling_policy.scale_out will be created


### Environment-based instance sizing

hcl
# modules/services/webserver-cluster/variables.tf
variable "environment" {
  description = "Environment - affects instance sizing"
  type        = string
  default     = "dev"
}


The `instance_type` passed in from the caller already handles this — production passes `t3.small`, dev passes `t3.micro`. The module exposes `instance_type_used` as an output so callers can confirm what was actually applied:

hcl
# modules/services/webserver-cluster/outputs.tf
output "instance_type_used" {
  value       = aws_launch_template.web.instance_type
  description = "The actual instance type used — affected by environment conditional"
}


Callers can also centralise the logic in a local if they prefer not to hardcode it:

hcl
locals {
  instance_type = var.environment == "production" ? "t3.small" : "t3.micro"
}




## Refactored Infrastructure

Changes made to the webserver cluster module from Days 8–9:

| What changed | How |
|---|---|
| Autoscaling policies | Were absent entirely — added as `count = var.enable_autoscaling ? 1 : 0` |
| `enable_autoscaling` variable | New input, defaults to `true` |
| `environment` variable | New input, used for tagging and instance sizing decisions |
| `autoscaling_policy_arns` output | New — `for` expression over `concat(scale_out, scale_in)` produces a name→ARN map |
| `instance_type_used` output | New — confirms what instance type was actually applied |

The security groups were already using inline blocks consistently (Day 9 gotcha fix), so no change needed there.



## count vs for_each — My Verdict

Use `count` when:
- You need a fixed number of identical resources (`count = 3`)
- The resource is toggled on/off with a bool (`count = var.enable_x ? 1 : 0`)
- The collection will never have items removed from the middle

Use `for_each` for everything else involving a list or map of named things. The moment you have a collection where items can be added or removed independently, `for_each` is the right choice. The index-shifting problem with `count` is subtle enough that it won't show up in a plan until you actually remove an item — by which time you're looking at unexpected destroys in production.

`count` is genuinely better for the toggle pattern (`? 1 : 0`) because it's more readable than a single-element `for_each` on a set.



## Chapter 5 Learnings

**When you use `count` to create a list of resources**, Terraform creates them as a list addressed by index: `aws_iam_user.example[0]`, `aws_iam_user.example[1]`, etc. You reference a specific one with `aws_iam_user.example[0].arn`.

**To access a specific resource from a `for_each` collection in an output**, use the key:

hcl
output "grace_arn" {
  value = aws_iam_user.foreach_map_example["grace"].arn
}

# or produce the full map with a for expression
output "all_arns" {
  value = { for name, user in aws_iam_user.foreach_map_example : name => user.arn }
}
`



