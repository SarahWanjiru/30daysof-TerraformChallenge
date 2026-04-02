provider "aws" {
  region = "eu-north-1"
}

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day13/global/secrets/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

# fetch the secret that was created manually via AWS CLI
# never create bootstrap secrets through Terraform — chicken and egg problem
data "aws_secretsmanager_secret" "db_credentials" {
  name = "day13/db/credentials"
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = data.aws_secretsmanager_secret.db_credentials.id
}

locals {
  db_credentials = jsondecode(
    data.aws_secretsmanager_secret_version.db_credentials.secret_string
  )
}

# sensitive = true — Terraform shows (sensitive value) in plan/apply output
# the value is still stored in state but never printed to terminal or logs
variable "db_password" {
  description = "Database password — passed via TF_VAR_db_password environment variable"
  type        = string
  sensitive   = true
  default     = null
}

output "db_username" {
  description = "Database username fetched from Secrets Manager"
  value       = local.db_credentials["username"]
  sensitive   = true
}

output "secret_arn" {
  description = "ARN of the Secrets Manager secret"
  value       = data.aws_secretsmanager_secret.db_credentials.arn
}
