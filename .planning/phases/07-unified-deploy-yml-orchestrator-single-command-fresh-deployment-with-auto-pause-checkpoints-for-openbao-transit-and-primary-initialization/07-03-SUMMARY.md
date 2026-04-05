---
phase: 07-unified-deploy-yml-orchestrator
plan: "03"
subsystem: ansible
tags: [wordpress, ssl, openbao, motd, gap-closure]
dependency_graph:
  requires: ["07-01", "07-02"]
  provides: ["academy-ssl-cert", "wordpress-academy-kv-complete", "motd-vault-addr-correct"]
  affects: ["ansible/playbooks/dual-wordpress.yml", "ansible/playbooks/tasks/openbao-bootstrap.yml", "ansible/roles/security_hardening/templates/motd.sh.j2"]
tech_stack:
  added: []
  patterns: ["certbot DNS-01 via Cloudflare API token", "OpenBao KV 4-field parity", "HTTPS localhost with VAULT_SKIP_VERIFY"]
key_files:
  created: []
  modified:
    - ansible/playbooks/dual-wordpress.yml
    - ansible/playbooks/tasks/openbao-bootstrap.yml
    - ansible/roles/security_hardening/templates/motd.sh.j2
decisions:
  - "Academy certbot uses Cloudflare DNS-01 with explicit domains — cannot inherit main site letsencrypt_domains (those include www/grafana/prometheus which don't apply to academy)"
  - "VAULT_SKIP_VERIFY=1 is safe for localhost-only communication against self-signed cert"
  - "vault_wp_academy_db_password is defined added to when conditional — task must not run with incomplete credentials"
metrics:
  duration: "7min"
  completed_date: "2026-04-05"
  tasks_completed: 3
  files_modified: 3
---

# Phase 07 Plan 03: Gap Closure — Academy SSL, KV Seeding, and MOTD VAULT_ADDR Summary

Three verification gaps found in Phase 07 code review closed: academy certbot with Cloudflare DNS-01 on fresh deploy, complete 4-field KV seeding for secret/wordpress-academy, and HTTPS VAULT_ADDR with VAULT_SKIP_VERIFY in MOTD.

## What Was Built

### Task 1 — Academy SSL (BLOCKER fix)
`nginx_wordpress_letsencrypt_enabled: false` replaced with `true` in the academy `include_role` vars block in `dual-wordpress.yml`. Added explicit `letsencrypt_domains`, `letsencrypt_cloudflare_api_token`, `ssl_cert_path`, and `ssl_key_path` for `academy.twomindstrading.com`. Without this, nginx would fail to start on a fresh server because the cert path would not exist.

### Task 2 — Academy KV seeding (DATA completeness)
The `Seed WordPress Academy admin password in OpenBao` task in `openbao-bootstrap.yml` previously only stored `admin_password`. It now stores all 4 fields: `db_name=wordpress_academy`, `db_user=wp_academy`, `db_password={{ vault_wp_academy_db_password }}`, `admin_password={{ vault_wordpress_academy_admin_password }}`. The `when` conditional now also guards on `vault_wp_academy_db_password is defined` to prevent a partial write.

### Task 3 — MOTD VAULT_ADDR (USABILITY fix)
MOTD `motd.sh.j2` previously showed `export VAULT_ADDR=http://127.0.0.1:8200`. OpenBao primary runs on HTTPS with a self-signed cert, so all `bao kv get` commands would fail with an x509 error. Fixed to `https://127.0.0.1:8200` and added `export VAULT_SKIP_VERIFY=1` on the immediately following line.

## Verification Results

| Gap | Check | Result |
|-----|-------|--------|
| GAP-1 (BLOCKER) | `grep 'letsencrypt_enabled: false' dual-wordpress.yml` | No matches |
| GAP-1 | `grep 'academy.twomindstrading.com' dual-wordpress.yml` | Shows domains, cert_path, key_path |
| GAP-2 (DATA) | `grep -A6 'kv put secret/wordpress-academy'` | All 4 fields present |
| GAP-3 (USABILITY) | `grep 'VAULT_ADDR=http://'` | No matches |
| GAP-3 | `grep 'VAULT_SKIP_VERIFY=1'` | 1 match at line 72 |

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None.

## Self-Check: PASSED

| Item | Status |
|------|--------|
| ansible/playbooks/dual-wordpress.yml | FOUND |
| ansible/playbooks/tasks/openbao-bootstrap.yml | FOUND |
| ansible/roles/security_hardening/templates/motd.sh.j2 | FOUND |
| Commit 27de2a0 (Task 1) | FOUND |
| Commit 3084c54 (Task 2) | FOUND |
| Commit 3be8783 (Task 3) | FOUND |
