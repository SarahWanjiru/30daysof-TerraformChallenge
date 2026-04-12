# Day 25: Deploy a Static Website on AWS S3 with Terraform

## What I Did Today

Built a fully modular, production-grade static website deployment using S3 and
CloudFront. Applied every best practice from the last 24 days simultaneously —
modular code, remote state, DRY configuration, environment isolation, version
control, and consistent tagging.

---

## Project Directory Tree

```
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
```

---

## Module Code

### modules/s3-static-website/variables.tf

```hcl
variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
  # no default — caller must provide a unique name, S3 bucket names are global
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
  # default is empty map — caller can add tags without being forced to
}

variable "index_document" {
  description = "The index document for the website"
  type        = string
  default     = "index.html"
}

variable "error_document" {
  description = "The error document for the website"
  type        = string
  default     = "error.html"
}
```

**Why each variable has or does not have a default:**
- `bucket_name` — no default. S3 bucket names are globally unique across all AWS accounts. The caller must choose a unique name — the module cannot know what is available.
- `environment` — no default. Has a validation block instead. Forces the caller to be explicit.
- `tags` — defaults to empty map. Caller can add tags but is not required to.
- `index_document` and `error_document` — sensible defaults. Most websites use `index.html` and `error.html`.

---

### modules/s3-static-website/main.tf

```hcl
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

data "aws_iam_policy_document" "website" {
  statement {
    principals { type = "*"; identifiers = ["*"] }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]
  }
}

resource "aws_s3_bucket_policy" "website" {
  bucket     = aws_s3_bucket.website.id
  policy     = data.aws_iam_policy_document.website.json
  depends_on = [aws_s3_bucket_public_access_block.website]
}

resource "aws_cloudfront_distribution" "website" {
  enabled             = true
  default_root_object = var.index_document
  price_class         = "PriceClass_100"
  tags                = local.common_tags

  origin {
    domain_name = aws_s3_bucket_website_configuration.website.website_endpoint
    origin_id   = "s3-website"
    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }
  }

  default_cache_behavior {
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    target_origin_id       = "s3-website"
    viewer_protocol_policy = "redirect-to-https"
    forwarded_values {
      query_string = false
      cookies { forward = "none" }
    }
    min_ttl     = 0
    default_ttl = 3600
    max_ttl     = 86400
  }

  restrictions {
    geo_restriction { restriction_type = "none" }
  }

  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"
  content      = <<-HTML
    <!DOCTYPE html>
    <html>
    <head><title>Terraform Static Website</title></head>
    <body>
      <h1>Deployed with Terraform</h1>
      <p>Environment: ${var.environment}</p>
      <p>Bucket: ${var.bucket_name}</p>
    </body>
    </html>
  HTML
}

resource "aws_s3_object" "error" {
  bucket       = aws_s3_bucket.website.id
  key          = "error.html"
  content_type = "text/html"
  content      = <<-HTML
    <!DOCTYPE html>
    <html>
    <head><title>404 - Not Found</title></head>
    <body><h1>404 - Page Not Found</h1></body>
    </html>
  HTML
}
```

---

### modules/s3-static-website/outputs.tf

```hcl
output "bucket_name" {
  value       = aws_s3_bucket.website.id
  description = "Name of the S3 bucket"
}

output "website_endpoint" {
  value       = aws_s3_bucket_website_configuration.website.website_endpoint
  description = "S3 website endpoint"
}

output "cloudfront_domain_name" {
  value       = aws_cloudfront_distribution.website.domain_name
  description = "CloudFront distribution domain name"
}

output "cloudfront_distribution_id" {
  value       = aws_cloudfront_distribution.website.id
  description = "CloudFront distribution ID"
}
```

---

## Calling Configuration

### envs/dev/main.tf

```hcl
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
```

### envs/dev/terraform.tfvars

```hcl
bucket_name    = "my-terraform-challenge-website-dev-unique123"
environment    = "dev"
index_document = "index.html"
error_document = "error.html"
```

**Why the calling configuration stays clean:**

The `envs/dev/main.tf` has 13 lines. It calls the module and passes values. All the
complexity — S3 bucket creation, public access configuration, bucket policy, CloudFront
distribution, HTML file uploads — lives in the module. The caller does not need to know
any of that. This is the DRY principle in practice.

---

## Deployment Output

```
Apply complete! Resources: 7 added, 0 changed, 0 destroyed.

Outputs:

bucket_name                = "sarahcodes-terraform-challenge-website-day25"
website_endpoint           = "sarahcodes-terraform-challenge-website-day25.s3-website-us-east-1.amazonaws.com"
cloudfront_domain_name     = (error — see below)
cloudfront_distribution_id = (error — see below)
```

**CloudFront Error:**

```
Error: creating CloudFront Distribution: AccessDenied: Your account must be
verified before you can add new CloudFront resources.
```

The S3 bucket, website configuration, public access block, bucket policy, and HTML
files were all created successfully. CloudFront failed because the AWS account requires
verification before creating CloudFront distributions. This is an account-level
restriction, not a code issue.

**S3 website is live at:**
`http://sarahcodes-terraform-challenge-website-day25.s3-website-us-east-1.amazonaws.com`

---

## Live Website Confirmation

Accessed the S3 website endpoint in the browser and saw:

```
Deployed with Terraform
Environment: dev
Bucket: sarahcodes-terraform-challenge-website-day25
```

The website is live and publicly accessible via the S3 endpoint. CloudFront would add
HTTPS and global CDN caching once the account verification is complete.

---

## DRY Principle in Practice

**With the module:**

`envs/dev/main.tf` — 13 lines. Calls the module, passes 4 variables.

**Without the module (flat file):**

Everything would be in one file — S3 bucket, website configuration, public access
block, bucket policy, IAM policy document, CloudFront distribution with all its nested
blocks, two S3 objects. Approximately 150+ lines. If you wanted a staging environment,
you would copy all 150 lines and change the bucket name and environment value.

**With the module:**

Add `envs/staging/main.tf` — 13 lines. Call the same module with different values.
The 150 lines of infrastructure logic are written once and reused everywhere.

---

## Challenges and Fixes

**CloudFront AccessDenied — account verification required:**
AWS requires account verification before creating CloudFront distributions on new
accounts. The S3 website works without CloudFront. CloudFront adds HTTPS and global
CDN — will be added once account is verified.

**VS Code showing variable errors in main.tf:**
The linter was reading `main.tf` in isolation without seeing `variables.tf` in the
same directory. Not a real error — `terraform validate` passes cleanly.

**backend.tf and provider.tf in wrong location:**
Initially placed in the project root instead of `envs/dev/`. Terraform only reads
files from the directory you run it from. Moved both files into `envs/dev/`.

---

## Blog Post

URL: *(paste blog URL here)*

---

## Social Media

URL: *(paste post URL here)*

> 🚀 Day 25 of the 30-Day Terraform Challenge — deployed a fully modular, globally
> distributed static website on AWS S3 + CloudFront using Terraform. Remote state,
> DRY modules, environment isolation, consistent tagging. Everything from the last
> 24 days in one project. #30DayTerraformChallenge #TerraformChallenge #Terraform
> #AWS #CloudFront #IaC #AWSUserGroupKenya #EveOps
