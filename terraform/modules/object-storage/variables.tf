variable "hetzner_s3_access_key" {
  description = "Hetzner Object Storage S3-compatible access key"
  type        = string
  sensitive   = true
}

variable "hetzner_s3_secret_key" {
  description = "Hetzner Object Storage S3-compatible secret key"
  type        = string
  sensitive   = true
}

variable "bucket_name" {
  description = "Name of the S3 bucket for backups (must be globally unique)"
  type        = string
}

variable "region" {
  description = "Hetzner Object Storage region (nbg1, fsn1, hel1)"
  type        = string
  default     = "nbg1"
}

variable "abort_incomplete_multipart_upload_days" {
  description = "Days after initiation before an incomplete multipart upload is aborted and its parts deleted (bucket-wide)"
  type        = number
  default     = 7

  validation {
    condition     = var.abort_incomplete_multipart_upload_days >= 1 && floor(var.abort_incomplete_multipart_upload_days) == var.abort_incomplete_multipart_upload_days
    error_message = "abort_incomplete_multipart_upload_days must be a whole number of days, at least 1."
  }
}
