# Day 7 — Terraform State Isolation: Workspaces vs File Layouts

## What This Does
Implements and compares two approaches to managing multiple environments (dev, staging, production) in Terraform without them interfering with each other — Workspaces and File Layout isolation. Also demonstrates the `terraform_remote_state` data source to share outputs across separate state files.

---

## Approach 1 — Workspaces (`day7/`)

A single configuration directory with a single S3 backend. Each workspace gets its own isolated state file automatically stored under a different key path in S3.

### Workspace Commands
```bash
terraform workspace new dev
terraform workspace new staging
terraform workspace new production
terraform workspace list
terraform workspace select dev
terraform apply
terraform workspace select staging
terraform apply
```

### How It Works
`terraform.workspace` is a built-in variable that returns the current workspace name. The config uses it to look up the right instance type from a map and tag resources with the environment name:

```hcl
variable "instance_type" {
  type = map(string)
  default = {
    dev        = "t3.micro"
    staging    = "t3.micro"
    production = "t3.micro"
  }
}

resource "aws_instance" "web" {
  instance_type = var.instance_type[terraform.workspace]
  tags = {
    Name        = "web-${terraform.workspace}"
    Environment = terraform.workspace
  }
}
```

### S3 State Key Paths (Workspaces)
Terraform automatically namespaces workspace state under:
```
day7/env:/dev/terraform.tfstate
day7/env:/staging/terraform.tfstate
day7/env:/production/terraform.tfstate
```

### Backend (`day7/backend.tf`)
```hcl
terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day7/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}
```

---

## Approach 2 — File Layout (`day7/environments/`)

Each environment lives in its own directory with its own `backend.tf` pointing to a unique S3 key. Completely separate state files, completely separate code.

### Directory Structure
```
environments/
├── dev/
│   ├── backend.tf
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
├── staging/
│   ├── backend.tf      ← includes terraform_remote_state from dev
│   ├── main.tf
│   ├── outputs.tf
│   └── variables.tf
└── production/
    ├── backend.tf
    ├── main.tf
    ├── outputs.tf
    └── variables.tf
```

### S3 State Key Paths (File Layout)
Each environment's `backend.tf` points to a unique key:
```
environments/dev/terraform.tfstate
environments/staging/terraform.tfstate
environments/production/terraform.tfstate
```

### Deploying Each Environment Independently
```bash
cd environments/dev && terraform init && terraform apply
cd environments/staging && terraform init && terraform apply
cd environments/production && terraform init && terraform apply
```
Changes in one directory have zero effect on the others.

---

## Remote State Data Source

Staging reads the `instance_id` output directly from the dev state file without any shared code:

```hcl
data "terraform_remote_state" "dev" {
  backend = "s3"
  config = {
    bucket = "sarahcodes-terraform-state-2026"
    key    = "environments/dev/terraform.tfstate"
    region = "eu-north-1"
  }
}

# Reference dev output in staging resource
resource "aws_instance" "web" {
  tags = {
    DevInstance = data.terraform_remote_state.dev.outputs.instance_id
  }
}
```

This is how a real multi-layer architecture works — a networking layer outputs VPC/subnet IDs, and an application layer reads them via `terraform_remote_state` without duplicating or hardcoding them.

---

## Workspaces vs File Layout — Comparison

| | Workspaces | File Layout |
|---|---|---|
| Code isolation | ❌ Same code for all envs | ✅ Each env has its own code |
| State isolation | ✅ Separate state per workspace | ✅ Separate state per directory |
| Risk of wrong env apply | ⚠️ High — easy to forget to switch | ✅ Low — you `cd` into the right dir |
| Scales across large teams | ❌ Fragile at scale | ✅ Recommended for production |
| Backend config overhead | ✅ One backend config | ⚠️ Repeated per environment |
| Supports env-specific code | ❌ No | ✅ Yes |

**Recommendation:** Use file layouts for anything production. Workspaces are fine for quick experiments or when environments are truly identical. The risk of running `terraform apply` in the wrong workspace is real — file layouts make that mistake structurally impossible.

---

## State Locking Across Workspaces
DynamoDB locking is per state file key. Two different workspaces have different keys, so they get independent locks — running `apply` on dev and staging simultaneously is safe. There is no cross-workspace lock contention.

---

## Key Takeaways
- Workspaces share code but isolate state — convenient but risky at scale
- File layouts isolate both code and state — more setup, much safer
- `terraform_remote_state` lets separate configurations share outputs without coupling their code
- Never hardcode values that another config already outputs — use `terraform_remote_state` instead
