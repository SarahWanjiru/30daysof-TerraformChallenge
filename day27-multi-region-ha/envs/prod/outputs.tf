output "primary_alb_dns_name" {
  description = "DNS name of the primary region ALB (eu-north-1)"
  value       = module.alb_primary.alb_dns_name
}

output "secondary_alb_dns_name" {
  description = "DNS name of the secondary region ALB (eu-west-1)"
  value       = module.alb_secondary.alb_dns_name
}

output "primary_rds_endpoint" {
  description = "Primary RDS instance endpoint"
  value       = module.rds_primary.db_endpoint
  sensitive   = true
}

# secondary_rds_endpoint not available - see rds_replica comment in main.tf

# Uncomment if you enable Route53
# output "application_url" {
#   description = "Application URL via Route53 failover DNS"
#   value       = module.route53.application_url
# }