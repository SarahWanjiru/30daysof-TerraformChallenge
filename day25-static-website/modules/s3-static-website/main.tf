locals {
  common_tags = merge(var.tags, {
    Environment = var.environment
    ManagedBy   = "terraform"
    Project     = "static-website"
  })
}

resource "aws_s3_bucket" "website" {
  bucket = var.bucket_name
  tags   = local.common_tags
}

resource "aws_s3_bucket_website_configuration" "website" {
  bucket = aws_s3_bucket.website.id

  index_document {
    suffix = var.index_document
  }

  error_document {
    key = var.error_document
  }
}

resource "aws_s3_bucket_public_access_block" "website" {
  bucket = aws_s3_bucket.website.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false
}

resource "aws_s3_bucket_policy" "website" {
  bucket = aws_s3_bucket.website.id
  policy = data.aws_iam_policy_document.website.json

  depends_on = [aws_s3_bucket_public_access_block.website]
}

data "aws_iam_policy_document" "website" {
  statement {
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions   = ["s3:GetObject"]
    resources = ["${aws_s3_bucket.website.arn}/*"]
  }
}

resource "aws_s3_object" "index" {
  bucket       = aws_s3_bucket.website.id
  key          = "index.html"
  content_type = "text/html"

  content = <<-HTML
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

  content = <<-HTML
    <!DOCTYPE html>
    <html>
    <head><title>404 - Not Found</title></head>
    <body>
      <h1>404 - Page Not Found</h1>
    </body>
    </html>
  HTML
}