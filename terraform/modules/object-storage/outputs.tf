output "bucket_name" {
  description = "The name of the backup bucket"
  value       = aws_s3_bucket.tmt_backups.id
}

output "bucket_endpoint" {
  description = "The Hetzner Object Storage endpoint URL"
  value       = "https://${var.region}.your-objectstorage.com"
}
