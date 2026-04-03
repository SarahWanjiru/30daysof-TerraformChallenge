# Day 14: Working with Multiple Providers — Part 1

## What I Did Today

Learned how Terraform's provider system works under the hood — installation, versioning, and
the lock file. Then deployed real infrastructure across two AWS regions in a single apply using
provider aliases: a primary S3 bucket in eu-north-1 and a replica bucket in eu-west-1 with
cross-region replication configured between them.



## Project Structure

```
day14/
└── multi-region/
    ├── main.tf                      # providers, IAM, S3 buckets, replication
    ├── outputs.tf                   # region outputs proving multi-region worked
    └── multi-account-example.tf.example  # assume_role pattern for reference
```



## Provider Configuration

```hcl
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

# default provider — used by all resources unless overridden with provider = aws.<alias>
provider "aws" {
  region = "eu-north-1"
}

# aliased provider — resources in eu-west-1 reference this with provider = aws.eu_west
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}
```

**What each argument does:**

- `required_version = ">= 1.0.0"` — refuses to run on Terraform CLI older than 1.0.0
- `source = "hashicorp/aws"` — full registry address: `registry.terraform.io/hashicorp/aws`
- `version = "~> 6.0"` — allows any 6.x version, never 7.x. Protects against breaking changes in major versions while still getting bug fixes
- `region` — which AWS API endpoint to call for resources using this provider
- `alias` — gives the second provider a name so resources can reference it explicitly

**Version constraint operators:**

| Constraint | Meaning |
|---|---|
| `= 6.38.0` | Exactly this version only |
| `>= 6.0` | 6.0 or higher — includes 7.0, 8.0 |
| `~> 6.0` | 6.x only, never 7.x — recommended |
| `~> 6.38.0` | 6.38.x only — most locked down |



## Multi-Region Deployment Code

```hcl
# primary bucket in eu-north-1 — versioning required for replication to work
resource "aws_s3_bucket" "primary" {
  bucket = "sarahcodes-primary-bucket-day14"
  tags   = { Name = "primary" }
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

# replica bucket in eu-west-1 — provider = aws.eu_west routes this to the aliased provider
resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west
  bucket   = "sarahcodes-replica-bucket-day14"
  tags     = { Name = "replica" }
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.eu_west
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration { status = "Enabled" }
}

# replication rule — copies all objects from primary to replica automatically
resource "aws_s3_bucket_replication_configuration" "replication" {
  role   = aws_iam_role.replication.arn
  bucket = aws_s3_bucket.primary.id

  rule {
    id     = "replicate-all"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.replica.arn
      storage_class = "STANDARD"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.primary,
    aws_s3_bucket_versioning.replica
  ]
}
```

**How Terraform decides which API endpoint to call:**

1. Resource has `provider = aws.eu_west` → calls `eu-west-1` API
2. Resource has no `provider` argument → uses default provider → calls `eu-north-1` API
3. No default provider exists → Terraform errors

**Real deployment output proving it worked:**

```
primary_bucket_name   = "sarahcodes-primary-bucket-day14"
primary_bucket_region = "eu-north-1"
replica_bucket_name   = "sarahcodes-replica-bucket-day14"
replica_bucket_region = "eu-west-1"
replication_role_arn  = "arn:aws:iam::629836545449:role/sarahcodes-s3-replication-role"
```



## .terraform.lock.hcl Explanation

```
provider "registry.terraform.io/hashicorp/aws" {
  version = "6.38.0"
  hashes = [
    "h1:7F3W4qGLTbr4aploSI8eIqE4AueoNe/Tq5Osuo0IgJ4=",
    "zh:143f118ae71059a7a7026c6b950da23fef04a06e2362ffa688bef75e43e869ed",
    ...
  ]
}
```

- `version = "6.38.0"` — the exact version selected from the `~> 6.0` constraint. Not a range — the specific version downloaded
- `hashes` — cryptographic checksums of the provider binary. `h1:` is a hash of the zip file. `zh:` hashes are per-platform (Linux, Mac, Windows). When anyone runs `terraform init`, Terraform verifies the downloaded binary matches these hashes — tampered binaries are rejected
- No `constraints` field — this was added in newer Terraform versions to record the original version constraint

**Why commit this file to version control:**

Without it, Engineer A runs `terraform init` today and gets `6.38.0`. Engineer B runs it next month and gets `6.39.0` which has a breaking change. Their plans produce different results. The lock file pins everyone to `6.38.0` until someone deliberately runs `terraform init -upgrade`.



## Multi-Account Setup

```hcl
provider "aws" {
  alias  = "staging"
  region = "eu-north-1"

  assume_role {
    role_arn = "arn:aws:iam::ACCOUNT_ID:role/TerraformDeployRole"
  }
}
```

`assume_role` tells the AWS provider to call `sts:AssumeRole` before making any API calls. STS returns temporary credentials for the target account. All subsequent API calls use those credentials — resources get created in the target account, not the current one.

I only have one AWS account so this was not deployed. The configuration is documented in `multi-account-example.tf.example`.

**IAM permissions TerraformDeployRole would need:**

- Trust policy allowing the source account to assume the role
- Permissions for whatever resources Terraform is deploying (S3, EC2, etc.)
- At minimum: `sts:AssumeRole` in the trust policy of the target account role



## Chapter 7 Learnings

**What happens during terraform init from a provider perspective:**

1. Terraform reads the `required_providers` block
2. Goes to `registry.terraform.io` and finds `hashicorp/aws`
3. Evaluates the version constraint `~> 6.0` and selects the latest matching version
4. Downloads the provider binary into `.terraform/providers/`
5. Writes the exact version and hashes into `.terraform.lock.hcl`

**Difference between `version = "6.0"` and `version = "~> 6.0"`:**

`version = "6.0"` means exactly 6.0.0 — nothing else. `version = "~> 6.0"` means any 6.x version. The `~>` operator is pessimistic — it allows patch and minor updates but blocks major version bumps that might have breaking changes.

**How Terraform determines which provider a resource uses:**

Every resource type has a provider implied by its name prefix. `aws_s3_bucket` implies the `aws` provider. If there is only one `aws` provider configured, all `aws_*` resources use it. If there are multiple (one default, one aliased), resources without an explicit `provider` argument use the default. Resources with `provider = aws.eu_west` use the aliased one.



## Challenges and Fixes

- **depends_on required for replication configuration** — Terraform does not automatically detect that the replication config depends on versioning being enabled. Without `depends_on`, Terraform tried to create the replication config before versioning was ready and the apply failed. Added explicit `depends_on` to fix it.

- **Every replica resource needs provider = aws.eu_west** — forgot to add `provider = aws.eu_west` to `aws_s3_bucket_versioning.replica` on the first attempt. Terraform tried to call the eu-north-1 API to modify a bucket that existed in eu-west-1 and got a bucket not found error. Added the provider argument to every resource that touches the replica bucket.

- **Bucket names must be globally unique** — S3 bucket names are unique across all AWS accounts worldwide. Used `sarahcodes-` prefix to avoid conflicts.



## Blog Post

URL: *(paste blog URL here)*

Title: **Getting Started with Multiple Providers in Terraform**



## Social Media

URL: *(paste post URL here)*

