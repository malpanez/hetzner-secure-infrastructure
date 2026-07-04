# Changelog

All notable changes to this project are documented here.
Format: [Keep a Changelog](https://keepachangelog.com/) · Versioning: [SemVer](https://semver.org/).

## [1.0.4] - 2026-07-04

### Added

- **`cloudflare-config`: two WAF rules that block WordPress user enumeration.**
  Rule 5 blocks author enumeration via `?author=N` (WordPress redirects it to
  `/author/<username>/`, leaking valid usernames for brute-force lists). Rule 6
  blocks anonymous user enumeration via the REST API `/wp-json/wp/v2/users`,
  gated on the `wordpress_logged_in` cookie so logged-in editors (the block
  editor) still work. Both default to enabled. They close the gaps left by the
  existing xmlrpc / wp-config / traversal rules and stop scanners that reach the
  origin *through* Cloudflare — where an origin-side per-IP block only ever sees
  Cloudflare's addresses, not the real client.

## [1.0.3] - 2026-06-14

### Added

- **`cloudflare-config`: new `extra_cache_path_prefixes` variable.** A list of
  URL path prefixes that each get an aggressive 30-day edge-cache rule in the
  `cache_rules` ruleset. Intended for reverse-proxied assets served outside
  `/wp-content/` (e.g. a `/media/` proxy in front of object storage), where the
  default rules don't apply. Cloudflare serves Range requests from the cached
  object, so large media seek/streaming works from the edge. Defaults to `[]`
  (no behavior change for existing consumers). Objects must be within the
  Cloudflare plan's max cacheable size (512 MB on Free/Pro).

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
