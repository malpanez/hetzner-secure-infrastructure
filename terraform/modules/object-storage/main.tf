terraform {
  required_version = ">= 1.6.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

resource "aws_s3_bucket" "tmt_backups" {
  bucket = var.bucket_name
}

resource "aws_s3_bucket_acl" "tmt_backups" {
  bucket = aws_s3_bucket.tmt_backups.id
  acl    = "private"

  depends_on = [aws_s3_bucket.tmt_backups]
}

resource "aws_s3_bucket_lifecycle_configuration" "tmt_backups" {
  bucket = aws_s3_bucket.tmt_backups.id

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
    id     = "expire-weekly"
    status = "Enabled"

    filter {
      prefix = "weekly/"
    }

    expiration {
      days = 28
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
}
