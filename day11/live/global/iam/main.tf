provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day10/global/iam/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

variable "user_names" {
  description = "List of IAM usernames to create"
  type        = list(string)
  default     = ["alice", "bob", "charlie"]
}

variable "safe_user_names" {
  description = "Set of IAM usernames — safe for for_each"
  type        = set(string)
  default     = ["dave", "eve", "frank"]
}

variable "users" {
  description = "Map of users with their department and admin status"
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

# count example 3 identical users
resource "aws_iam_user" "count_example" {
  count = 3
  name  = "sarahcodes-user-${count.index}"
}

# count with list fragile pattern
resource "aws_iam_user" "list_example" {
  count = length(var.user_names)
  name  = var.user_names[count.index]
}

# for_each with set safe pattern
resource "aws_iam_user" "foreach_set_example" {
  for_each = var.safe_user_names
  name     = each.value
}

# for_each with map extra data per user
resource "aws_iam_user" "foreach_map_example" {
  for_each = var.users
  name     = each.key
  tags = {
    Department = each.value.department
    Admin      = each.value.admin
  }
}

# for expressions in outputs
output "upper_names" {
  description = "All user names in uppercase"
  value       = [for name in var.user_names : upper(name)]
}

output "user_arns" {
  description = "Map of username to ARN for map users"
  value       = { for name, user in aws_iam_user.foreach_map_example : name => user.arn }
}

output "set_user_arns" {
  description = "Map of username to ARN for set users"
  value       = { for name, user in aws_iam_user.foreach_set_example : name => user.arn }
}
