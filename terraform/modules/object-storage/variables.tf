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
  description = "Name of the S3 bucket for backups"
  type        = string
  default     = "tmt-backups"
}

variable "region" {
  description = "Hetzner Object Storage region (nbg1, fsn1, hel1)"
  type        = string
  default     = "nbg1"
}
