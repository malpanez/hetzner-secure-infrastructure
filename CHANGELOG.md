# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/) · Versioning: [SemVer](https://semver.org/).

## [1.0.2] - 2026-06-12

### Fixed

- **`object-storage`: lifecycle rules are now declared in alphabetical `id`
  order.** Ceph-based S3 endpoints (Hetzner Object Storage and most
  S3-compatibles) return lifecycle rules sorted by rule id regardless of the
  order they were submitted in, and the AWS provider diffs `rule` blocks as an
  ordered list. With any other declaration order every plan after the first
  refresh shows a permanent phantom in-place update swapping the rules —
  applying it never converges, because the endpoint re-sorts on the next read.
  If you consume this module against Hetzner/Ceph, keep any rules you add in
  alphabetical id order too.

## [1.0.1] - 2026-06-12

### Fixed

- **`object-storage`: ignore `transition_default_minimum_object_size` drift.**
  The AWS provider sends this provider-side default on create/update and then
  polls the bucket until the returned lifecycle configuration matches.
  S3-compatible endpoints (Hetzner Object Storage) never echo the attribute
  back, so the consistency wait fails with
  `timeout while waiting for state to become 'true'` (3m) **even though the
  PUT succeeded**, and every later refresh shows a phantom in-place update
  re-adding it. The module now sets
  `lifecycle { ignore_changes = [transition_default_minimum_object_size] }` —
  safe because it defines no transition rules, which makes the attribute
  inert. If a create still times out against such an endpoint, verify with
  `aws s3api get-bucket-lifecycle-configuration` and, if the rules are live,
  `terraform import` (or `tofu import`) the resource instead of re-applying.

## [1.0.0] - 2026-06-11

### Added

- Initial public release: Terraform/OpenTofu modules (`hetzner-server`,
  `cloudflare-config`, `object-storage`), 13 Ansible roles with Molecule
  scenarios, runnable examples, and the full lint/test tooling.

[1.0.2]: https://github.com/malpanez/hetzner-secure-infrastructure/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/malpanez/hetzner-secure-infrastructure/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/malpanez/hetzner-secure-infrastructure/releases/tag/v1.0.0
