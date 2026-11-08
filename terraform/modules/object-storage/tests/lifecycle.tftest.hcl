mock_provider "aws" {}

variables {
  bucket_name           = "example-backups"
  hetzner_s3_access_key = ""
  hetzner_s3_secret_key = ""
}

run "rules_are_in_alphabetical_id_order" {
  command = plan

  assert {
    condition = [for r in aws_s3_bucket_lifecycle_configuration.backups.rule : r.id] == [
      "abort-multipart",
      "expire-daily",
      "expire-monthly",
      "expire-weekly",
    ]
    error_message = "Lifecycle rules must be declared in alphabetical id order (Ceph returns them sorted)."
  }
}

run "abort_multipart_defaults_to_seven_days_bucket_wide" {
  command = plan

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.backups.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 7
    error_message = "abort-multipart must default to 7 days."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.backups.rule[0].prefix == ""
    error_message = "abort-multipart must be bucket-wide via prefix = \"\" (Ceph echoes an empty filter in the legacy form)."
  }

  assert {
    condition     = length(aws_s3_bucket_lifecycle_configuration.backups.rule[0].filter) == 0
    error_message = "abort-multipart must not declare a filter block (permanent phantom diff on Ceph)."
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.backups.rule[0].status == "Enabled"
    error_message = "abort-multipart must be enabled."
  }
}

run "abort_multipart_days_is_configurable" {
  command = plan

  variables {
    abort_incomplete_multipart_upload_days = 2
  }

  assert {
    condition     = aws_s3_bucket_lifecycle_configuration.backups.rule[0].abort_incomplete_multipart_upload[0].days_after_initiation == 2
    error_message = "abort_incomplete_multipart_upload_days must drive days_after_initiation."
  }
}

run "abort_multipart_days_rejects_zero" {
  command = plan

  variables {
    abort_incomplete_multipart_upload_days = 0
  }

  expect_failures = [var.abort_incomplete_multipart_upload_days]
}

run "retention_rules_are_unchanged" {
  command = plan

  assert {
    condition = [for r in aws_s3_bucket_lifecycle_configuration.backups.rule : [r.filter[0].prefix, r.expiration[0].days] if r.id != "abort-multipart"] == [
      ["daily/", 7],
      ["monthly/", 90],
      ["weekly/", 28],
    ]
    error_message = "Retention rules (daily 7d, monthly 90d, weekly 28d) must not change."
  }
}
