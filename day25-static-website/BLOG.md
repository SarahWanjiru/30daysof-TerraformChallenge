TITLE (paste into Medium title field):
Deploying a Static Website on AWS S3 with Terraform: A Beginner's Guide

SUBTITLE (paste into Medium subtitle field):
Day 25 of my Terraform challenge — I deployed a globally distributed static website using S3 and CloudFront, hit a real AWS account error, and applied every best practice from the last 24 days in one project.

---

BODY (paste everything below into Medium):

---

Day 25 of my 30-Day Terraform Challenge.

The last build.

Today I deployed a static website on AWS S3 with CloudFront — fully modular, remote state, DRY configuration, environment isolation, consistent tagging. Everything from the last 24 days applied simultaneously in one project.

I also hit a real error. The CloudFront distribution failed because my AWS account needs verification. The S3 website is live. CloudFront will follow once the account is verified.

Here is everything — the code, the structure, the error, and why the module approach makes this project reusable across environments.


Prerequisites

- AWS account with IAM user configured
- Terraform installed
- Basic understanding of S3 and CloudFront

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

The module creates everything needed for a static website:

- S3 bucket with website configuration
- Public access block (disabled for public website)
- Bucket policy allowing public read
- CloudFront distribution for HTTPS and global CDN
- index.html and error.html uploaded to the bucket

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

bucket_name has no default because S3 bucket names are globally unique across all AWS accounts. The module cannot know what names are available. The caller must choose.

environment has no default but has a validation block — the same pattern from Day 11.

The common_tags local merges caller-provided tags with the standard tags:

locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "static-website"
  })
}

force_destroy is set based on environment — dev buckets can be destroyed with objects inside, production cannot:

resource "aws_s3_bucket" "website" {
  bucket        = var.bucket_name
  force_destroy = var.environment != "production"
  tags          = local.common_tags
}


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

That is it. 13 lines. All the complexity — S3 configuration, CloudFront distribution, HTML uploads — lives in the module. The calling config just passes values.

terraform.tfvars:

bucket_name    = "my-terraform-challenge-website-dev-unique123"
environment    = "dev"
index_document = "index.html"
error_document = "error.html"

To create a staging environment, add envs/staging/ with different values. The module code is not duplicated.


4. The Deployment

terraform plan showed 7 resources to create:

- aws_s3_bucket
- aws_s3_bucket_website_configuration
- aws_s3_bucket_public_access_block
- aws_s3_bucket_policy
- aws_cloudfront_distribution
- aws_s3_object (index.html)
- aws_s3_object (error.html)

📸 Screenshot here — terraform plan output showing 7 resources
Caption: Plan: 7 to add — S3 bucket, website config, public access, policy, CloudFront, two HTML files


5. The Error — CloudFront Account Verification

terraform apply created 6 of the 7 resources successfully. Then:

Error: creating CloudFront Distribution: AccessDenied: Your account must be
verified before you can add new CloudFront resources.

📸 Screenshot here — the CloudFront error in your terminal
Caption: CloudFront AccessDenied — AWS account requires verification before creating distributions

This is an AWS account-level restriction on new accounts. Not a code issue. The S3 bucket, website configuration, public access block, bucket policy, and HTML files were all created successfully.

The S3 website is live at:
http://sarahcodes-terraform-challenge-website-day25.s3-website-us-east-1.amazonaws.com

📸 Screenshot here — the website in your browser
Caption: Static website live on S3 — "Deployed with Terraform, Environment: dev"

CloudFront will be added once the account verification is complete. It adds HTTPS and global CDN caching — the S3 endpoint serves HTTP only.


6. The DRY Principle in Practice

Without the module, everything would be in one flat file — approximately 150 lines. To create a staging environment, you copy all 150 lines and change two values.

With the module:

envs/dev/main.tf — 13 lines
envs/staging/main.tf — 13 lines (different bucket name and environment)
envs/production/main.tf — 13 lines (different bucket name and environment)

The 150 lines of infrastructure logic are written once. Three environments. 39 lines of calling configuration total.

That is DRY.


7. The Errors I Hit

Error 1 — backend.tf and provider.tf in wrong location

Initially placed both files in the project root. Terraform only reads files from the directory you run it from. When running from envs/dev/, it could not see the root files. Fixed by moving both into envs/dev/.

Error 2 — VS Code showing variable errors

The VS Code linter was reading main.tf in isolation without seeing variables.tf in the same directory. Not a real error — terraform validate passes cleanly. The linter just does not understand multi-file Terraform configurations.

Error 3 — CloudFront AccessDenied

AWS account verification required for CloudFront. S3 website works without it. Will add CloudFront once verified.


Key Lessons Learned

- The module approach makes environments trivial — 13 lines per environment instead of 150
- bucket_name must have no default — S3 names are globally unique, the module cannot choose
- force_destroy = var.environment != "production" — dev buckets can be destroyed, production cannot
- CloudFront requires account verification on new AWS accounts — S3 endpoint works without it
- backend.tf and provider.tf must be in the same directory you run terraform from
- The DRY principle is not just about less code — it is about one place to change when something needs to change


One question before you go:

Have you deployed a static website on AWS before? Did you use the console or Terraform?

Drop it in the comments. I am curious how many people are still clicking through the console for this.

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
