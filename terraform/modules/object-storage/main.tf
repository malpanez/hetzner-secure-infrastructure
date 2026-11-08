terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "backups" {
  # This bucket lives on Hetzner Object Storage (Ceph, S3-compatible), NOT AWS. The
  # AWS-native S3 controls below are not implemented by the endpoint (or not
  # applicable), so Checkov's AWS checks are waived here, each with a reason:
  #checkov:skip=CKV_AWS_145:Hetzner/Ceph has no AWS KMS — server-side encryption is provider-managed
  #checkov:skip=CKV_AWS_144:single-region Ceph endpoint — no cross-region replication
  #checkov:skip=CKV2_AWS_62:S3 event notifications require AWS SNS/SQS/Lambda (absent on Hetzner)
  #checkov:skip=CKV_AWS_18:AWS server-access-logging target is not supported on the Ceph endpoint
  #checkov:skip=CKV2_AWS_6:PublicAccessBlock API not implemented by Ceph — bucket is ACL=private and origin-locked
  #checkov:skip=CKV_AWS_21:backups use lifecycle retention (7/28/90d), not versioning, to avoid unbounded version growth
  bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "backups" {
  bucket = aws_s3_bucket.backups.id
  acl    = "private"

  depends_on = [aws_s3_bucket.backups]
}

resource "aws_s3_bucket_lifecycle_configuration" "backups" {
  bucket = aws_s3_bucket.backups.id

  # S3-compatible endpoints (Hetzner Object Storage) never echo this
  # provider-side default back, so the AWS provider's consistency wait times
  # out on create and every refresh shows a phantom in-place update. The
  # module defines no transition rules, so the attribute is inert.
  lifecycle {
    ignore_changes = [transition_default_minimum_object_size]
  }

  # Rules are declared in alphabetical id order on purpose: Ceph-based
  # endpoints return lifecycle rules sorted by id, and the provider diffs
  # `rule` as an ordered list — any other order is a permanent phantom diff.
  #
  # abort-multipart is bucket-wide via `prefix = ""`, not `filter {}`: Ceph
  # stores an empty filter in the legacy form (<Prefix></Prefix>, no <Filter>)
  # and returns it that way, so `filter {}` is a permanent phantom diff. The
  # provider's deprecation warning on `prefix` is the price.
  rule {
    id     = "abort-multipart"
    status = "Enabled"

    prefix = ""

    abort_incomplete_multipart_upload {
      days_after_initiation = var.abort_incomplete_multipart_upload_days
    }
  }

  rule {
    id     = "expire-daily"
    status = "Enabled"

    filter {
      prefix = "daily/"
    }

    expiration {
      days = 7
    }
  }

  rule {
    id     = "expire-monthly"
    status = "Enabled"

    filter {
      prefix = "monthly/"
    }

    expiration {
      days = 90
    }
  }

  rule {
    id     = "expire-weekly"
    status = "Enabled"

    filter {
      prefix = "weekly/"
    }

    expiration {
      days = 28
    }
  }
}
