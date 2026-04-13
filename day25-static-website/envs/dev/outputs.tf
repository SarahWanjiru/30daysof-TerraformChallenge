output "bucket_name" {
  value = module.static_website.bucket_name
}

output "website_endpoint" {
  value       = module.static_website.website_endpoint
  description = "Open this URL in your browser to see the live website"
}
