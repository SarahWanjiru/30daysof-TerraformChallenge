# Day 13: Managing Sensitive Data Securely in Terraform

## What I Did Today

Learned exactly how secrets leak in Terraform configurations and closed every leak path.
Created a real secret in AWS Secrets Manager, fetched it at apply time using a data source,
marked outputs as sensitive, and proved the secret never appears in code, terminal output,
or local files. The state file is stored encrypted in S3 — the last line of defence.

---

## Project Structure

```
day13/
├── live/
│   ├── global/secrets/          # Secrets Manager data source demo
│   └── dev/services/webserver-cluster/  # module with sensitive variables
└── modules/services/webserver-cluster/  # builds on day12 + sensitive handling
```

---

## The Three Leak Paths

### Leak Path 1 — Hardcoded in .tf files

```hcl
# VULNERABLE — committed to Git the moment you run git add
resource "aws_db_instance" "example" {
  username = "admin"
  password = "super-secret-password"
}
```

```hcl
# SECURE — fetched from Secrets Manager at apply time, never in code
resource "aws_db_instance" "example" {
  username = local.db_credentials["username"]
  password = local.db_credentials["password"]
}
```

Even if you delete the hardcoded value later, it exists in Git history permanently.
`git log` will always show it.

### Leak Path 2 — Variable default values

```hcl
# VULNERABLE — default value is stored in your .tf file and committed to Git
variable "db_password" {
  default = "super-secret-password"
}
```

```hcl
# SECURE — no default, Terraform prompts or reads TF_VAR_db_password
variable "db_password" {
  description = "Database password — set via TF_VAR_db_password, never hardcoded"
  type        = string
  sensitive   = true
  default     = null
}
```

### Leak Path 3 — Plaintext in state file

Even when you handle the first two correctly, Terraform stores sensitive resource
attribute values in `terraform.tfstate` in plaintext. Anyone with read access to
the state file can see all your secrets.

This is why remote state with encryption is non-negotiable:

```hcl
terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day13/global/secrets/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true  # AES-256 server-side encryption
  }
}
```

---

## AWS Secrets Manager Integration

### Step 1 — Create the secret manually via CLI (never through Terraform)

```bash
aws secretsmanager create-secret \
  --name "day13/db/credentials" \
  --secret-string '{"username":"dbadmin","password":"SecurePass123!"}' \
  --region eu-north-1
```

Output:
```json
{
    "ARN": "arn:aws:secretsmanager:eu-north-1:629836545449:secret:day13/db/credentials-NHbtMa",
    "Name": "day13/db/credentials",
    "VersionId": "a22e7f9b-0d0c-4379-89ec-9c9ded4fc35e"
}
```

Why manually? If Terraform creates the secret, the secret value must exist somewhere
in your configuration before Terraform runs — chicken and egg problem. Bootstrap
secrets are always created outside Terraform.

### Step 2 — Fetch at apply time using data sources

```hcl
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
```

`jsondecode` parses the JSON string into a map so you can access
`local.db_credentials["username"]` and `local.db_credentials["password"]`
individually.

### Step 3 — Reference in resources

```hcl
resource "aws_db_instance" "example" {
  username = local.db_credentials["username"]
  password = local.db_credentials["password"]
}
```

The secret value never touches your `.tf` files. It is fetched at runtime.

---

## Sensitive Variable and Output Declarations

```hcl
variable "db_password" {
  description = "Database password — set via TF_VAR_db_password, never hardcoded"
  type        = string
  sensitive   = true
  default     = null
}

output "db_username_used" {
  description = "The database username fetched from Secrets Manager"
  value       = local.db_credentials["username"]
  sensitive   = true
}
```

**Plan output with sensitive = true:**

```
Changes to Outputs:
  + db_username = (sensitive value)
  + secret_arn  = "arn:aws:secretsmanager:eu-north-1:629836545449:secret:day13/db/credentials-NHbtMa"
```

**Apply output:**

```
Outputs:

db_username = <sensitive>
secret_arn  = "arn:aws:secretsmanager:eu-north-1:629836545449:secret:day13/db/credentials-NHbtMa"
```

`sensitive = true` prevents the value from appearing in terminal output and logs.
It does NOT prevent the value from being stored in state — the state file still
contains the plaintext value. This is why state file encryption is required.

---

## Proof the Secret Is Not in Code

```bash
$ grep -r "SecurePass123" ~/Desktop/30daysof-TerraformChallenge/day13/
# returns nothing — secret exists nowhere in the codebase

$ grep -r "dbadmin" ~/Desktop/30daysof-TerraformChallenge/day13/live/global/secrets/.terraform/
# returns nothing — not in local terraform files either
```

The secret lives only in AWS Secrets Manager and in the encrypted S3 state file.

---

## State File Security Audit

Backend configuration:

```hcl
terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day13/global/secrets/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}
```

S3 bucket security checklist:
- `encrypt = true` — AES-256 server-side encryption on all state files
- Block all public access — enabled on `sarahcodes-terraform-state-2026`
- Bucket versioning — enabled, allows recovery from accidental overwrites
- DynamoDB locking — `sarahcodes-terraform-locks` prevents concurrent applies
- `.terraform/` directories not committed — covered by `.gitignore`

---

## .gitignore

```
# Terraform providers and plugins
**/.terraform/

# State files — may contain sensitive data in plaintext
*.tfstate
*.tfstate.backup
*.tfstate.lock.info

# Variable files — may contain secrets
*.tfvars
*.tfvars.json
!example.tfvars

# Lock and crash files
.terraform.lock.hcl
crash.log
crash.*.log

# Override files
override.tf
override.tf.json
*_override.tf

# Env vars and secrets
*.env
.env
```

Why each entry:
- `.terraform/` — provider binaries, hundreds of MB, no value in Git
- `*.tfstate` — contains plaintext secrets, must never be committed
- `*.tfvars` — often contains real values including secrets
- `.terraform.lock.hcl` — regenerated on init, not needed in Git
- `*.env` — environment variable files often contain credentials

---

## Chapter 6 Learnings

**Does sensitive = true prevent secrets from being stored in state?**

No. `sensitive = true` only prevents the value from being printed in terminal
output and logs. The value is still stored in plaintext in `terraform.tfstate`.
The state file must be encrypted and access-restricted separately.

**HashiCorp Vault vs AWS Secrets Manager — when to use each:**

AWS Secrets Manager is the right choice when you are already on AWS and want
a managed service with automatic rotation, fine-grained IAM policies, and
native integration with RDS, ECS, and Lambda. No infrastructure to manage.

HashiCorp Vault is the right choice when you need secrets management across
multiple cloud providers, on-premises infrastructure, or need advanced features
like dynamic secrets (credentials that are generated on-demand and expire
automatically). Vault requires you to run and maintain the Vault cluster.

**Why can you not fully prevent secrets from appearing in state?**

Some resource types — like `aws_db_instance` — store their password attribute
in state because Terraform needs to track the current value to detect drift.
If the password changes outside Terraform, Terraform needs the old value to
know something changed. There is no way to tell Terraform to use a secret
without it recording that secret in state.

---

## Challenges and Fixes

- **Secret not found on first plan** — ran `terraform plan` before the secret
  was fully propagated. AWS Secrets Manager takes a few seconds after creation.
  Waited 10 seconds and re-ran — worked fine.

- **jsondecode on wrong field** — initially tried to access
  `data.aws_secretsmanager_secret_version.db_credentials.secret_string["username"]`
  directly. That fails because `secret_string` is a raw JSON string, not a map.
  Must run `jsondecode()` first to convert it to a map, then access the key.

- **sensitive output in module** — when a module output is marked `sensitive = true`,
  the calling config must also mark its output `sensitive = true` when passing it
  through. Terraform errors if you try to output a sensitive value without the flag.

---

## Blog Post

URL: *(paste blog URL here)*

Title: **How to Handle Sensitive Data Securely in Terraform**

Covered all three leak paths with vulnerable and secure code examples, the full
AWS Secrets Manager integration, sensitive = true behaviour, and the state file
security checklist. Proved the secret never appears in code using grep.

---

## Social Media

URL: *(paste post URL here)*

> 🔐 Day 13 of the 30-Day Terraform Challenge — secrets management deep dive.
> Three ways secrets leak in Terraform configurations, how to close every one of
> them, and why the state file is the last line of defence. Security is not
> optional in production infrastructure. #30DayTerraformChallenge
> #TerraformChallenge #Terraform #Security #DevOps #IaC #AWSUserGroupKenya #EveOps
