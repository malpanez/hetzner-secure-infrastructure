# Plan 06-01 Summary

**Status:** Complete
**Files changed:**
- `ansible/playbooks/tasks/openbao-bootstrap.yml`
- `ansible/inventory/group_vars/all/secrets.yml.example`

## What was done

Extended `openbao-bootstrap.yml` to seed all service credentials in OpenBao KV at bootstrap time, so every credential is retrievable via `bao kv get` after a fresh server rebuild.

**Changes in openbao-bootstrap.yml:**

1. Extended "Seed MariaDB root password" task — `kv put secret/mariadb` now includes `exporter_password` alongside `root_password` in a single atomic command. The `when` guard now requires `vault_mariadb_exporter_password is defined` to prevent a partial seed. No separate `kv patch` task was added (avoids exporter_password being lost on monthly rotation).

2. Fixed `wordpress-academy-rotator` policy — added `"patch"` to capabilities for `secret/data/wordpress-academy`. Without this, `bao kv patch secret/wordpress-academy` in `rotate-wp-admin-academy.sh` returns 403.

3. Added 4 new KV seeding tasks (inserted after "Seed backup S3 credentials"):
   - `secret/grafana` — seeds `admin_password` (when `vault_grafana_admin_password` defined)
   - `secret/smtp` — seeds `user` + `app_password` (when both vars defined; optional)
   - `secret/stripe` — seeds `publishable_key` + `secret_key` (when both vars defined; optional)
   - `secret/wordpress-academy` — seeds `admin_password` (when `vault_wordpress_academy_admin_password` defined)

All new tasks follow the existing pattern: `no_log: true`, `changed_when: true`, `when` guards, `tags: [openbao, bootstrap]`.

**Changes in secrets.yml.example:**

- Removed stale `# vault_smtp_password` comment (wrong var name)
- Added `vault_mariadb_exporter_password` (uncommented — required at bootstrap)
- Added `vault_wordpress_academy_admin_password` (uncommented — required at bootstrap)
- Added commented-out SMTP section with correct var names (`vault_smtp_user`, `vault_smtp_app_password`)
- Added commented-out Stripe section (`vault_stripe_publishable_key`, `vault_stripe_secret_key`)

## Verification

```bash
# All 4 new kv put paths present + exporter_password in mariadb put
grep -n 'secret/grafana\|exporter_password\|secret/smtp\|secret/stripe\|secret/wordpress-academy' \
  ansible/playbooks/tasks/openbao-bootstrap.yml

# No separate kv patch for mariadb (exporter is in the kv put)
grep 'kv patch secret/mariadb' ansible/playbooks/tasks/openbao-bootstrap.yml \
  && echo "FAIL" || echo "OK"

# Academy rotator policy has patch capability
grep -A5 'secret/data/wordpress-academy' ansible/playbooks/tasks/openbao-bootstrap.yml \
  | grep 'patch'

# New vault vars in secrets.yml.example
grep 'vault_smtp_user\|vault_stripe_secret_key\|vault_wordpress_academy_admin_password\|vault_mariadb_exporter_password' \
  ansible/inventory/group_vars/all/secrets.yml.example

# ansible-lint passes
ansible-lint ansible/playbooks/tasks/openbao-bootstrap.yml
```

## Deviations from Plan

None — plan executed exactly as written.

## Commit

`0ab1872` — feat(openbao): extend KV bootstrap — grafana, smtp, stripe, academy, mariadb exporter; fix academy rotator policy
