output "primary_bucket_name" {
  value       = aws_s3_bucket.primary.bucket
  description = "Name of the primary bucket"
}

output "primary_bucket_region" {
  value       = aws_s3_bucket.primary.region
  description = "Region of the primary bucket"
}

output "replica_bucket_name" {
  value       = aws_s3_bucket.replica.bucket
  description = "Name of the replica bucket"
}

output "replica_bucket_region" {
  value       = aws_s3_bucket.replica.region
  description = "Region of the replica bucket"
}
