output "bucket_name" {
  value = module.static_website.bucket_name
}

output "website_endpoint" {
  value = module.static_website.website_endpoint
}

output "cloudfront_domain_name" {
  value       = module.static_website.cloudfront_domain_name
  description = "Open this URL in your browser — CloudFront takes 5-15 minutes to propagate"
}

output "cloudfront_distribution_id" {
  value = module.static_website.cloudfront_distribution_id
}
