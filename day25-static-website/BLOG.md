TITLE (paste into Medium title field):
Deploying a Static Website on AWS S3 with Terraform: A Beginner's Guide

SUBTITLE (paste into Medium subtitle field):
Day 25 — I deployed a fully modular static website on AWS using S3 and CloudFront. Hit a confusing AWS error, figured out why, and got the site live. Here is everything.

---

BODY (paste everything below into Medium):

---

Day 25 of my 30-Day Terraform Challenge.

The final build.

Today I deployed a static website on AWS S3 with CloudFront — fully modular, remote state, DRY configuration, environment isolation, consistent tagging. Everything from the last 24 days applied simultaneously in one project.

I also hit a confusing error. CloudFront failed with an "account not verified" message — on an account I have been using for 25 days to deploy EC2 instances, EKS clusters, and ALBs. I will explain exactly why that happens and how to fix it.

The S3 website is live. Here is everything.


Prerequisites

- AWS account with IAM user configured
- Terraform installed
- Basic understanding of S3 and static websites

New to Terraform? Check the earlier posts in this series — links at the bottom.


1. The Project Structure

day25-static-website/
├── modules/
│   └── s3-static-website/
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
├── envs/
│   └── dev/
│       ├── main.tf
│       ├── variables.tf
│       ├── outputs.tf
│       ├── terraform.tfvars
│       ├── backend.tf
│       └── provider.tf

The modules/ directory contains the reusable infrastructure logic. The envs/dev/ directory is the calling configuration — it passes values to the module and nothing else.

This separation is the DRY principle in practice. The module is written once. Every environment (dev, staging, production) calls it with different values.

📸 Screenshot here — your project structure in VS Code
Caption: Day 25 project structure — module in modules/, calling config in envs/dev/


2. The Module

variables.tf — five variables, two without defaults:

variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
  # no default — S3 bucket names are globally unique, caller must choose
}

variable "environment" {
  description = "Deployment environment"
  type        = string

  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

bucket_name has no default because S3 bucket names are globally unique across all AWS accounts. The module cannot know what names are available.

environment has no default but has a validation block — the same pattern from Day 11.

main.tf creates everything needed for a static website:

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "static-website"
  })
}

resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = var.environment != "production"
  tags          = local.common_tags
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id
  index_document { suffix = var.index_document }
  error_document { key    = var.error_document }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket                  = aws_s3_bucket.website.id
  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  policy     = data.aws_iam_policy_document.website.json
  depends_on = [aws_s3_bucket_public_access_block.website]
}

force_destroy = var.environment != "production" — dev buckets can be destroyed with objects inside, production cannot. One line that enforces different behaviour per environment.


3. The Calling Configuration

envs/dev/main.tf — 13 lines:

module "static_website" {
  source = "../../modules/s3-static-website"

  bucket_name    = var.bucket_name
  environment    = var.environment
  index_document = var.index_document
  error_document = var.error_document

  tags = {
    Owner = "terraform-challenge"
    Day   = "25"
  }
}

That is it. 13 lines. All the complexity lives in the module.

terraform.tfvars:

bucket_name    = "sarahcodes-static-website-day25-2026"
environment    = "dev"
index_document = "index.html"
error_document = "error.html"

To create a staging environment, add envs/staging/ with different values. The module code is not duplicated.


4. The Deployment

terraform plan showed 6 resources (CloudFront removed — see below):

Plan: 6 to add, 0 to change, 0 to destroy.

📸 Screenshot here — terraform plan output showing 6 resources
Caption: Plan: 6 to add — S3 bucket, website config, public access, policy, two HTML files

terraform apply:

Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

bucket_name      = "sarahcodes-static-website-day25-2026"
website_endpoint = "http://sarahcodes-static-website-day25-2026.s3-website.eu-north-1.amazonaws.com"

📸 Screenshot here — terraform apply output
Caption: Apply complete — 6 resources, website endpoint live


5. The CloudFront Error — Why It Happened

The original module included CloudFront. It failed with:

Error: creating CloudFront Distribution: AccessDenied: Your account must be
verified before you can add new CloudFront resources.

This confused me. I have been using this AWS account for 25 days — deploying EC2 instances, ALBs, EKS clusters, S3 buckets. Everything worked. So why does CloudFront fail?

AWS has two separate verification levels.

1. Basic account verification — covers EC2, S3, ALB, EKS, and most services. This account passed this when it was created.

2. CloudFront-specific verification — AWS requires separate manual approval before new accounts can create CloudFront distributions. This is an anti-abuse measure. CloudFront can serve content globally at massive scale, which bad actors use for DDoS attacks and illegal content distribution. AWS manually reviews accounts before enabling it.

The Terraform code is correct. The CloudFront resource block will work perfectly on an approved account.

To request approval: AWS Support → Create Case → Service Limit Increase → CloudFront.

📸 Screenshot here — the CloudFront AccessDenied error
Caption: CloudFront AccessDenied — separate from general AWS account verification, requires manual approval


6. The Live Website

Opened the S3 endpoint in the browser:

http://sarahcodes-static-website-day25-2026.s3-website.eu-north-1.amazonaws.com

Deployed with Terraform
Environment: dev
Bucket: sarahcodes-static-website-day25-2026

📸 Screenshot here — the website in your browser
Caption: Static website live on S3 — deployed entirely by Terraform


7. The DRY Principle in Practice

Without the module, everything would be in one flat file — approximately 150 lines. To create a staging environment, copy all 150 lines and change two values. Any bug fix must be applied in every environment separately.

With the module:

envs/dev/main.tf — 13 lines
envs/staging/main.tf — 13 lines (different bucket name and environment)
envs/production/main.tf — 13 lines (different bucket name and environment)

The 150 lines of infrastructure logic are written once. Three environments. 39 lines of calling configuration total.

That is DRY.


8. Remote State

The state file lives in S3 with encryption:

terraform {
  backend "s3" {
    bucket         = "sarahcodes-terraform-state-2026"
    key            = "day25/static-website/dev/terraform.tfstate"
    region         = "eu-north-1"
    dynamodb_table = "sarahcodes-terraform-locks"
    encrypt        = true
  }
}

Why this matters: if the state file lived locally and your laptop died, you would lose track of what Terraform manages. With remote state, any engineer on any machine can run terraform plan and get the same result.


9. Cleanup

terraform destroy -auto-approve

Destroy complete! Resources: 6 destroyed.

force_destroy = true on the bucket (because environment = "dev") allowed Terraform to delete the bucket even with objects inside. In production, force_destroy = false — Terraform would refuse to delete a bucket with objects, protecting against accidental data loss.


Key Lessons Learned

- bucket_name must have no default — S3 names are globally unique, the module cannot choose
- force_destroy = var.environment != "production" — one line enforces different behaviour per environment
- CloudFront requires separate AWS account approval — different from general account verification
- backend.tf and provider.tf must be in the same directory you run terraform from
- The DRY principle is not just about less code — it is about one place to change when something needs to change
- Remote state protects your infrastructure — any engineer on any machine gets the same state


One question before you go:

Have you deployed a static website on AWS before? Did you use the console or Terraform?

Drop it in the comments. I am curious how many people are still clicking through the AWS console for this.

If this post helped you, clap so more engineers find it before they spend an hour clicking through the AWS console.

Follow me here on Medium — the challenge posts keep coming.

I am currently doing the 30-Day Terraform Challenge while building Cloud and DevOps skills in public. Open to opportunities — using this time to build real-world skills by actually doing and breaking things.

I am Sarah Wanjiru — a frontend developer turned cloud and DevOps engineer, sharing every step of the transition in public. The mistakes. The fixes. The moments things finally click. Follow along if that sounds useful. 🤝💫

#30DayTerraformChallenge #TerraformChallenge #Terraform #AWS #CloudFront #IaC #AWSUserGroupKenya #EveOps #WomenInTech #BuildInPublic #CloudComputing #Andela
DevOps
Terraform
AWS
Infrastructure As Code
Buildinginpublic
