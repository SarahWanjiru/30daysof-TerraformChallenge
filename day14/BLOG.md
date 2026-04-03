TITLE (paste into Medium title field):
Getting Started with Multiple Providers in Terraform

SUBTITLE (paste into Medium subtitle field):
I deployed infrastructure across two AWS regions in a single terraform apply. Here is exactly how provider aliases work, what the lock file does, and the two errors I hit along the way.

---

BODY (paste everything below into Medium):

---

Introduction

On Day 14 of my 30-Day Terraform Challenge, I ran one terraform apply and created infrastructure in two different AWS regions at the same time.

A primary S3 bucket in eu-north-1. A replica bucket in eu-west-1. Cross-region replication configured between them. All from a single configuration file.

Before today I had always deployed everything to one region. The idea of managing multiple regions felt complicated. It turned out to be surprisingly clean once I understood how Terraform's provider system actually works.

In this post I will walk you through:

- What a provider actually is
- How provider installation and versioning work
- What the .terraform.lock.hcl file does and why it matters
- How to deploy to multiple regions using provider aliases
- The multi-account pattern using assume_role
- The two errors I hit and how I fixed them


Prerequisites

- AWS account with IAM user configured
- Terraform installed
- AWS CLI configured
- Basic understanding of terraform init, plan, apply


1. What Is a Provider?

Terraform does not know how to talk to AWS by itself. It is just a tool that reads configuration files.

A provider is a plugin that acts as the translator between Terraform and a specific platform.

When you write this:

resource "aws_s3_bucket" "primary" {
  bucket = "my-bucket"
}

Terraform does not know what an S3 bucket is. The AWS provider knows. It takes that resource declaration and turns it into an AWS API call.

Every resource in Terraform belongs to exactly one provider. The resource name prefix tells you which one — aws_s3_bucket belongs to the aws provider, google_storage_bucket belongs to the google provider.


2. How Provider Installation Works

When you run terraform init, Terraform:

1. Reads your required_providers block
2. Goes to registry.terraform.io and finds the provider
3. Selects the version that matches your constraint
4. Downloads the provider binary into .terraform/providers/
5. Records the exact version and hashes in .terraform.lock.hcl

The .terraform/providers/ folder contains a large binary file — this is why you never commit .terraform/ to Git. But the lock file is committed so every team member gets the exact same provider version.


3. Provider Version Pinning

Always pin your provider versions. Without pinning, terraform init downloads the latest version every time — which might have breaking changes.

terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

The ~> operator is called a pessimistic constraint. ~> 6.0 means: allow any version that is 6.x but never 7.x. You get bug fixes and new features automatically. You are protected from major version bumps that might break your configuration.

Version constraint cheat sheet:

= 6.38.0   → exactly this version, nothing else
>= 6.0     → 6.0 or higher, includes 7.0 — dangerous
~> 6.0     → 6.x only, never 7.x — recommended
~> 6.38.0  → 6.38.x only — most locked down


4. The Lock File

After running terraform init, a .terraform.lock.hcl file is created:

provider "registry.terraform.io/hashicorp/aws" {
  version = "6.38.0"
  hashes = [
    "h1:7F3W4qGLTbr4aploSI8eIqE4AueoNe/Tq5Osuo0IgJ4=",
    "zh:143f118ae71059a7a7026c6b950da23fef04a06e2362ffa688bef75e43e869ed",
    ...
  ]
}

📸 Screenshot here — your .terraform.lock.hcl output
Caption: The lock file records the exact version and cryptographic hashes of the provider binary

version = "6.38.0" — the exact version selected. Not a range. The specific version downloaded.

hashes — cryptographic checksums of the provider binary. When anyone runs terraform init, Terraform downloads the provider and verifies the hash matches. If someone tampered with the binary, the hash would not match and Terraform would refuse to proceed.

Why commit this file to Git:

Without it, Engineer A runs terraform init today and gets 6.38.0. Engineer B runs it next month and gets 6.39.0 which has a breaking change. Their plans produce different results. The lock file pins everyone to 6.38.0 until someone deliberately runs terraform init -upgrade.


5. Deploying to Multiple Regions — Provider Aliases

The default provider applies to all resources. To deploy to a second region, define an aliased provider:

# default provider — eu-north-1
provider "aws" {
  region = "eu-north-1"
}

# aliased provider — eu-west-1
provider "aws" {
  alias  = "eu_west"
  region = "eu-west-1"
}

alias gives the second provider a name. Resources that want to deploy to eu-west-1 must explicitly reference it with provider = aws.eu_west.

How Terraform decides which API endpoint to call:

- Resource has provider = aws.eu_west → calls eu-west-1 API
- Resource has no provider argument → uses default → calls eu-north-1 API


6. S3 Cross-Region Replication

I built a practical example — primary bucket in eu-north-1, replica in eu-west-1, with automatic replication between them.

Primary bucket — no provider argument, uses default:

resource "aws_s3_bucket" "primary" {
  bucket = "sarahcodes-primary-bucket-day14"
}

resource "aws_s3_bucket_versioning" "primary" {
  bucket = aws_s3_bucket.primary.id
  versioning_configuration { status = "Enabled" }
}

Replica bucket — provider = aws.eu_west routes it to eu-west-1:

resource "aws_s3_bucket" "replica" {
  provider = aws.eu_west
  bucket   = "sarahcodes-replica-bucket-day14"
}

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.eu_west
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration { status = "Enabled" }
}

Replication configuration:

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

The apply output confirmed both regions:

primary_bucket_region = "eu-north-1"
replica_bucket_region = "eu-west-1"

📸 Screenshot here — the apply output showing both regions
Caption: One apply, two regions — primary_bucket_region and replica_bucket_region confirm the aliased provider worked


7. The Multi-Account Pattern

For teams with multiple AWS accounts, use assume_role to deploy into a different account:

provider "aws" {
  alias  = "staging"
  region = "eu-north-1"

  assume_role {
    role_arn = "arn:aws:iam::ACCOUNT_ID:role/TerraformDeployRole"
  }
}

assume_role tells the AWS provider to call STS (Security Token Service) before making any API calls. STS returns temporary credentials for the target account. All subsequent API calls use those credentials — resources get created in the target account, not your current one.

I only have one AWS account so this was not deployed. The pattern is documented in the repository for reference.


8. Error — depends_on Required for Replication

On my first apply I got this error:

Error: creating S3 Bucket Replication Configuration
versioning is not enabled on the source bucket

What happened — Terraform tried to create the replication configuration before versioning was enabled on the buckets. Terraform normally detects dependencies automatically from references, but the replication config references the buckets, not the versioning resources. So it did not know to wait.

Fix — explicit depends_on:

depends_on = [
  aws_s3_bucket_versioning.primary,
  aws_s3_bucket_versioning.replica
]

This forces Terraform to wait until both versioning resources are created before attempting the replication configuration.


9. Error — Missing provider on Replica Resources

On my second attempt I forgot to add provider = aws.eu_west to aws_s3_bucket_versioning.replica.

Terraform tried to call the eu-north-1 API to modify a bucket that existed in eu-west-1.

Error: bucket not found

Fix — every resource that touches the replica bucket needs the provider argument:

resource "aws_s3_bucket_versioning" "replica" {
  provider = aws.eu_west
  bucket   = aws_s3_bucket.replica.id
  versioning_configuration { status = "Enabled" }
}

If a resource belongs to a non-default region, every resource that references it must also specify the correct provider.


Key Lessons Learned

- A provider is a plugin that translates Terraform resource declarations into API calls
- terraform init downloads the provider binary and records the exact version in the lock file
- Always commit .terraform.lock.hcl — it ensures every team member uses the same provider version
- ~> 6.0 allows 6.x versions only — the recommended constraint pattern
- Provider aliases let you deploy to multiple regions in one configuration
- Every resource that touches a non-default region must specify provider = aws.<alias>
- depends_on is needed when Terraform cannot automatically detect a dependency
- assume_role lets one provider deploy into a completely different AWS account


Final Thoughts

Multi-region deployments felt intimidating before today. Two lines of code — an alias and a provider argument on the resource — is all it takes.

The lock file was the other big learning. I had been ignoring it. Now I understand exactly what it does and why it belongs in Git.

I am currently doing the 30-Day Terraform Challenge while building Cloud and DevOps skills in public. Open to opportunities — using this time to build real-world skills by actually doing and breaking things.

If you are also learning Terraform or DevOps, let's connect and grow together.

#30DayTerraformChallenge #TerraformChallenge #Terraform #AWS #MultiRegion #IaC #DevOps #AWSUserGroupKenya #EveOps #WomenInTech #BuildInPublic #CloudComputing #Kubernetes #Andela
