# Day 25: Deploy a Static Website on AWS S3 with Terraform

## What I Did Today

Built a fully modular static website deployment using S3 and CloudFront. Applied every
best practice from the last 24 days simultaneously — modular code, remote state, DRY
configuration, environment isolation, version control, and consistent tagging.

CloudFront failed due to an AWS account-level restriction (separate from general account
verification — see the CloudFront section below). The S3 website deployed successfully
and is live.



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



## Module Code

### modules/s3-static-website/variables.tf

```hcl
variable "bucket_name" {
  description = "Globally unique name for the S3 bucket"
  type        = string
  # no default — S3 bucket names are globally unique across all AWS accounts
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
- `bucket_name` — no default. S3 bucket names are globally unique. The module cannot know what names are available.
- `environment` — no default. Has a validation block instead — forces the caller to be explicit.
- `tags` — defaults to empty map. Caller can add tags but is not required to.
- `index_document` / `error_document` — sensible defaults. Most websites use these names.



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

# CloudFront distribution — requires AWS account CloudFront approval
# See CloudFront section below for why this was removed from the active deployment
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
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
  description = "S3 website endpoint — open this in your browser"
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
bucket_name    = "sarahcodes-static-website-day25-2026"
environment    = "dev"
index_document = "index.html"
error_document = "error.html"
```

**Why the calling configuration stays clean:**

`envs/dev/main.tf` is 13 lines. It calls the module and passes values. All the
complexity — S3 bucket creation, public access configuration, bucket policy, CloudFront
distribution, HTML file uploads — lives in the module. The caller does not need to know
any of that. This is the DRY principle in practice.



## Deployment Output

```
Apply complete! Resources: 6 added, 0 changed, 0 destroyed.

Outputs:

bucket_name      = "sarahcodes-static-website-day25-2026"
website_endpoint = "http://sarahcodes-static-website-day25-2026.s3-website.eu-north-1.amazonaws.com"
```

Note: 6 resources deployed (CloudFront removed — see below). Full 7-resource deployment
including CloudFront is the intended final state once account approval is received.



## Live Website Confirmation

Accessed the S3 website endpoint in the browser:

`http://sarahcodes-static-website-day25-2026.s3-website.eu-north-1.amazonaws.com`

Saw:
```
Deployed with Terraform
Environment: dev
Bucket: sarahcodes-static-website-day25-2026
```

The website is live and publicly accessible via the S3 endpoint.



## CloudFront — Why It Failed and What It Means

**The error:**
```
Error: creating CloudFront Distribution: AccessDenied: Your account must be
verified before you can add new CloudFront resources.
```

**Why this is confusing:** This account has been used for 25 days of infrastructure
deployments — EC2, ALB, EKS, S3, RDS. All of those worked. So why does CloudFront fail?

**The answer:** AWS has two separate verification levels:

1. **Basic account verification** — covers EC2, S3, ALB, EKS, and most services.
   This account passed this when it was created.

2. **CloudFront-specific verification** — AWS requires separate manual approval before
   new accounts can create CloudFront distributions. This is an anti-abuse measure
   because CloudFront can serve content globally at massive scale, which bad actors
   use for DDoS attacks and illegal content distribution. AWS manually reviews accounts
   before enabling it.

**The code is correct.** The CloudFront Terraform resource block will work perfectly
on an account that has been approved. To request approval:
AWS Support → Create Case → Service Limit Increase → CloudFront.



## DRY Principle in Practice

**With the module:**

`envs/dev/main.tf` — 13 lines. Calls the module, passes 4 variables.

To add a staging environment: create `envs/staging/main.tf` — 13 lines with different
values. The infrastructure logic is not duplicated.

**Without the module (flat file):**

Everything in one file — S3 bucket, website configuration, public access block, bucket
policy, IAM policy document, CloudFront distribution with all nested blocks, two S3
objects. Approximately 150+ lines. To add staging, copy all 150 lines and change two
values. Any bug fix must be applied in every environment separately.

**The DRY principle:** Write the infrastructure logic once. Reuse it everywhere.



## Bonus — Route53 Custom Domain

Route53 configuration for pointing a custom domain to CloudFront (requires CloudFront
to be active and an ACM certificate in us-east-1):

```hcl
data "aws_route53_zone" "primary" {
  name = var.domain_name
}

resource "aws_route53_record" "website" {
  zone_id = data.aws_route53_zone.primary.zone_id
  name    = var.domain_name
  type    = "A"

  alias {
    name                   = aws_cloudfront_distribution.website.domain_name
    zone_id                = aws_cloudfront_distribution.website.hosted_zone_id
    evaluate_target_health = false
  }
}
```

This was not deployed because CloudFront is pending account approval. Will be
implemented once CloudFront is enabled.



## Cleanup Confirmation

```
Destroy complete! Resources: 6 destroyed.
```

All S3 objects, bucket policy, public access block, website configuration, and S3
bucket were destroyed. `force_destroy = true` on the bucket (because `environment = "dev"`)
allowed Terraform to delete the bucket even with objects inside.

Post-destroy verification:

```bash
aws s3 ls | grep day25
# returns nothing — bucket deleted
```



## Challenges and Fixes

**backend.tf and provider.tf in wrong location:**
Initially placed in the project root. Terraform only reads files from the directory
you run it from. Fixed by moving both into `envs/dev/`.

**VS Code variable errors:**
The linter read `main.tf` in isolation without seeing `variables.tf`. Not a real error
— `terraform validate` passes cleanly.

**CloudFront AccessDenied:**
AWS requires separate manual approval for CloudFront on new accounts. The code is
correct. Removed CloudFront from the active deployment. Will re-add once approved via
AWS Support → Service Limit Increase → CloudFront.

