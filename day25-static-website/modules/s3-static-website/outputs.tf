output "bucket_name" {
  value       = aws_s3_bucket.website.id
  description = "Name of the S3 bucket"
}

output "website_endpoint" {
  value       = "http://${aws_s3_bucket_website_configuration.website.website_endpoint}"
  description = "S3 website endpoint — open this in your browser"
}
