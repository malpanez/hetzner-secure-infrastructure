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
