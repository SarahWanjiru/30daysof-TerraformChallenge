output "primary_bucket_name" {
  value       = aws_s3_bucket.primary.bucket
  description = "Name of the primary bucket in eu-north-1"
}

output "primary_bucket_region" {
  value       = aws_s3_bucket.primary.region
  description = "Region of the primary bucket"
}

output "replica_bucket_name" {
  value       = aws_s3_bucket.replica.bucket
  description = "Name of the replica bucket in eu-west-1"
}

output "replica_bucket_region" {
  value       = aws_s3_bucket.replica.region
  description = "Region of the replica bucket — confirms aliased provider worked"
}

output "replication_role_arn" {
  value       = aws_iam_role.replication.arn
  description = "ARN of the IAM role used for S3 replication"
}
