output "bucket_name" {
  description = "Name of the S3 bucket for raw sensor data"
  value       = aws_s3_bucket.raw.bucket
}

output "bucket_arn" {
  description = "ARN of the S3 bucket for raw sensor data"
  value       = aws_s3_bucket.raw.arn
}

output "bucket_id" {
  description = "ID (name) of the S3 bucket"
  value       = aws_s3_bucket.raw.id
}
