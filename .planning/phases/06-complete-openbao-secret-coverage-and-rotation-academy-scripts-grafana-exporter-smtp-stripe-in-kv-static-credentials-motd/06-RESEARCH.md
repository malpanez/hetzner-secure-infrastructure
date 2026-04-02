# Phase 6: Complete OpenBao Secret Coverage and Rotation — Research

**Researched:** 2026-04-01
**Domain:** OpenBao (Vault fork) KV seeding, dynamic DB rotation, systemd timers, Ansible playbook extension, static MOTD
**Confidence:** HIGH

---

## Summary

Phase 6 closes the gaps between what OpenBao currently stores and what the full dual-site stack
requires. The bootstrap and rotation infrastructure already exists and is well-structured; this
phase adds seven discrete items to two existing files (`openbao-bootstrap.yml` and
`setup-openbao-rotation.yml`).

All work is additive and idempotent. The patterns used for the main site (script → service →
timer, KV seeding with `when: var is defined`, `bao kv patch` for partial updates) are directly
reusable for the academy site and static secrets.

The academy DB rotation script is a near-copy of `rotate-wordpress-secrets.sh` with two
variable changes: `WP_PATH` and the token file path. The academy admin rotation mirrors
`rotate-wp-admin.sh`. The monthly service needs a second `ExecStart` line. KV seeding for
Grafana, exporter password, SMTP, and Stripe follows the same conditional pattern as
`secret/backup` (skip if vars not defined). The static MOTD is a single Ansible `copy` task.

**Primary recommendation:** Implement all seven items in two plans: (1) academy rotation scripts
+ timers + monthly service update, and (2) KV seeding extensions + static MOTD. Both plans
touch only `setup-openbao-rotation.yml` and `tasks/openbao-bootstrap.yml`.

---

## Standard Stack

### Core (already deployed — do not change)

| Component | Version | Purpose |
|-----------|---------|---------|
| OpenBao | 2.x (bao CLI) | Secret storage, dynamic DB creds, KV-v2 |
| systemd | Debian 13 | Timer-based rotation scheduling |
| WP-CLI | latest | WordPress admin password updates |
| bao CLI | system | `kv put`, `kv patch`, `kv get`, `token create` |
| jq | system | JSON parsing in rotation scripts |

### Existing rotation architecture

| Script | Token file | Timer | Schedule |
|--------|-----------|-------|---------|
| `rotate-wordpress-secrets.sh` | `/root/.openbao-token` | `wordpress-secret-rotate.timer` | daily 03:00 |
| `rotate-mariadb-root.sh` | `/root/.openbao-mariadb-token` | `monthly-secret-rotate.timer` | monthly 1st 02:00 |
| `rotate-wp-admin.sh` | `/root/.openbao-token` | `monthly-secret-rotate.service` | monthly 1st 02:30 |

### New items this phase

| Item | File | Type |
|------|------|------|
| `rotate-wordpress-academy-secrets.sh` | `setup-openbao-rotation.yml` | Script + service + timer |
| `rotate-wp-admin-academy.sh` | `setup-openbao-rotation.yml` | Script |
| `monthly-secret-rotate.service` (updated) | `setup-openbao-rotation.yml` | Add second `ExecStart` |
| `secret/grafana` seeding | `tasks/openbao-bootstrap.yml` | KV seed |
| `secret/mariadb` exporter_password field | `tasks/openbao-bootstrap.yml` | KV patch/extend |
| `secret/smtp` seeding | `tasks/openbao-bootstrap.yml` | KV seed (conditional) |
| `secret/stripe` seeding | `tasks/openbao-bootstrap.yml` | KV seed (conditional) |
| `/etc/motd.d/80-credentials` | `setup-openbao-rotation.yml` | Static MOTD |

---

## Architecture Patterns

### Pattern 1: Academy DB rotation script

Exact copy of `rotate-wordpress-secrets.sh` with two changes:
- `WP_PATH="/var/www/academy.twomindstrading.com"`
- Token file: `/root/.openbao-academy-token`
- OpenBao path: `database/creds/wordpress-academy`
- Log file: `/var/log/wordpress-academy-secret-rotation.log`
- PHP-FPM reload: `systemctl reload php8.3-fpm` (same pool manager; both pools reload together)

The `wordpress-academy-rotator` policy already exists in `openbao-bootstrap.yml` and grants
`database/creds/wordpress-academy` read + `secret/data/wordpress-academy` create/update.

**Timer:** `wordpress-academy-secret-rotate.timer` at `*-*-* 03:30:00` (30 min after main site).

### Pattern 2: Academy WP admin rotation

Exact copy of `rotate-wp-admin.sh` with:
- `WP_PATH="/var/www/academy.twomindstrading.com"`
- `TOKEN_FILE="/root/.openbao-academy-token"`
- `LOG_FILE="/var/log/wp-admin-academy-rotation.log"`
- KV patch target: `secret/wordpress-academy` (field: `admin_password`)

**Monthly service:** Add `ExecStart=/usr/local/bin/rotate-wp-admin-academy.sh` as third
`ExecStart` in `monthly-secret-rotate.service`. systemd executes `ExecStart` entries
sequentially when `Type=oneshot`.

### Pattern 3: KV seeding with conditional guard (from existing `secret/backup`)

```yaml
- name: Seed SMTP credentials in OpenBao
  ansible.builtin.command: >-
    {{ openbao_cli }} kv put secret/smtp
    user={{ vault_smtp_user }}
    app_password={{ vault_smtp_app_password }}
  environment: "{{ openbao_env | combine({'VAULT_TOKEN': openbao_bootstrap_token}) }}"
  changed_when: true
  when:
    - openbao_bootstrap_token is defined
    - vault_smtp_user is defined
    - vault_smtp_app_password is defined
  no_log: true
  tags: [openbao, bootstrap]
```

Same pattern applies to `secret/stripe` (guard on `vault_stripe_publishable_key` and
`vault_stripe_secret_key`).

### Pattern 4: Extending `secret/mariadb` with exporter_password

The bootstrap task seeds `secret/mariadb` with `root_password` only. To add
`exporter_password` without dropping the existing field, use `bao kv patch` (KV-v2 partial
update) instead of `bao kv put`. This preserves `root_password` across re-runs.

```yaml
- name: Add exporter_password to secret/mariadb in OpenBao
  ansible.builtin.command: >-
    {{ openbao_cli }} kv patch secret/mariadb
    exporter_password={{ vault_mariadb_exporter_password }}
  environment: "{{ openbao_env | combine({'VAULT_TOKEN': openbao_bootstrap_token}) }}"
  changed_when: true
  when:
    - openbao_bootstrap_token is defined
    - vault_mariadb_exporter_password is defined
  no_log: true
  tags: [openbao, bootstrap]
```

`bao kv patch` requires KV-v2 (already enabled at `secret/`). It adds/updates individual
fields without overwriting other fields in the same secret. Confirmed behavior: Vault/OpenBao
KV-v2 `patch` operation (HTTP PATCH on metadata endpoint).

**Confidence:** HIGH — KV-v2 patch is documented OpenBao/Vault behavior, and `rotate-wp-admin.sh`
already uses `bao kv patch` successfully in this project.

### Pattern 5: Static MOTD

The MOTD file `/etc/motd.d/80-credentials` must be:
- Permanent (not removed after rotation — unlike `90-rotation-notice`)
- Idempotent (Ansible `copy` or `template` with static content)
- Numbered `80` so it appears before `90-rotation-notice`

Use `ansible.builtin.copy` with literal `content:` block in `setup-openbao-rotation.yml`.
The file only shows `bao kv get` commands — no actual secrets.

```
=================================================================
  CREDENTIAL RETRIEVAL (requires OpenBao unsealed)
=================================================================
  export VAULT_ADDR=http://127.0.0.1:8200

  MariaDB root    : bao kv get -field=root_password secret/mariadb
  MariaDB exporter: bao kv get -field=exporter_password secret/mariadb
  WP admin (main) : bao kv get -field=admin_password secret/wordpress
  WP admin (acad) : bao kv get -field=admin_password secret/wordpress-academy
  Grafana admin   : bao kv get -field=admin_password secret/grafana
  SMTP            : bao kv get secret/smtp
  Stripe          : bao kv get secret/stripe
  Backup S3       : bao kv get secret/backup
=================================================================
```

### Anti-patterns to avoid

- **`bao kv put` on existing `secret/mariadb`:** This would overwrite `root_password` if the
  Ansible var is not provided at re-run time. Use `kv patch` for the exporter field.
- **Hardcoding WP_PATH in scripts:** Use a variable in the script header so the path is clear
  at the top of the file.
- **Single `ExecStart` pattern broken by multiple lines:** systemd `Type=oneshot` supports
  multiple `ExecStart=` lines running sequentially — this is already the pattern in the
  existing `monthly-secret-rotate.service`. Third `ExecStart` for academy admin is valid.
- **Stripping `no_log: true` from seeding tasks:** `vault_smtp_app_password` and
  `vault_stripe_secret_key` are credentials. All seeding tasks must have `no_log: true`.
- **Missing `changed_when: true`** on `bao kv put/patch` commands: These commands are
  always "changed" by design — add explicitly to pass ansible-lint.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Partial KV update | Custom read-modify-write script | `bao kv patch` (KV-v2 native) |
| Script idempotency | Check-before-write logic | Ansible task `when:` guards |
| Token renewal in scripts | Custom renewal logic | `bao token renew-self` (already in existing scripts) |

---

## Common Pitfalls

### Pitfall 1: `bao kv put` overwrites all fields in KV-v2

**What goes wrong:** `bao kv put secret/mariadb root_password=X` after
`bao kv patch secret/mariadb exporter_password=Y` will drop `exporter_password`.

**How to avoid:** Always use `bao kv patch` when adding a field to an existing secret.
If the secret does not yet exist at bootstrap time (first run), `bao kv patch` fails —
seed with `bao kv put` including all known fields, then use `patch` in subsequent tasks
or restructure the bootstrap to put all mariadb fields in one task.

**Resolution for this phase:** Update the "Seed MariaDB root password" task to include
`exporter_password` when the var is defined, using `bao kv put` on initial bootstrap
(both fields in one call). This is safe because bootstrap only runs once (idempotency
handled by token existence guard).

### Pitfall 2: `monthly-secret-rotate.service` has three `ExecStart` lines — ordering matters

**What goes wrong:** If `rotate-mariadb-root.sh` fails, systemd with `Type=oneshot` stops
and does not run subsequent `ExecStart` lines.

**How to avoid:** The existing pattern already accepts this behavior — main WP admin rotation
depends on the MariaDB rotation completing first (same pattern). Academy admin rotation added
third is acceptable. Log files provide per-script audit trail.

### Pitfall 3: PHP-FPM reload in academy rotation

**What goes wrong:** `systemctl reload php8.3-fpm` reloads the master process which manages
all pools. During the reload window both sites briefly serve with old credentials (< 1 second).

**How to avoid:** This is already the behavior for the main site — it is acceptable. Do not
use `restart` (causes connection drops); `reload` is the correct operation.

### Pitfall 4: `vault_smtp_user`/`vault_smtp_app_password` vars not defined in secrets.yml.example

**What goes wrong:** The bootstrap task is skipped silently if vars are not defined (that is
the intent), but the planner/operator may not know to add them.

**How to avoid:** Add commented-out entries to `secrets.yml.example` for all new vault vars
introduced in this phase: `vault_smtp_user`, `vault_smtp_app_password`,
`vault_stripe_publishable_key`, `vault_stripe_secret_key`, `vault_grafana_admin_password`
(already present), `vault_mariadb_exporter_password` (already present).

### Pitfall 5: Academy WP admin token uses the same `/root/.openbao-academy-token`

**What goes wrong:** `rotate-wp-admin-academy.sh` re-uses `/root/.openbao-academy-token`
(same as the DB rotation script). This token has policy `wordpress-academy-rotator` which
grants `secret/data/wordpress-academy` create/update. Verify the policy includes this path —
it does (confirmed in `openbao-bootstrap.yml` lines 308-328).

**How to avoid:** No additional token or policy needed. Both academy scripts share the same
token file, which is already the design (same pattern as main site using `/root/.openbao-token`
for both `rotate-wordpress-secrets.sh` and `rotate-wp-admin.sh`).

---

## Code Examples

### Academy DB rotation service unit (new)

```ini
[Unit]
Description=Rotate WordPress Academy Database Credentials
After=network.target openbao.service mariadb.service
Requires=openbao.service mariadb.service

[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/rotate-wordpress-academy-secrets.sh
StandardOutput=journal
StandardError=journal
SyslogIdentifier=wordpress-academy-rotation
```

### Academy DB rotation timer unit (new)

```ini
[Unit]
Description=Rotate WordPress Academy secrets daily
Documentation=man:systemd.timer(5)

[Timer]
OnCalendar=*-*-* 03:30:00
Persistent=true
RandomizedDelaySec=300

[Install]
WantedBy=timers.target
```

### Updated monthly-secret-rotate.service (three ExecStart lines)

```ini
[Service]
Type=oneshot
User=root
ExecStart=/usr/local/bin/rotate-mariadb-root.sh
ExecStart=/usr/local/bin/rotate-wp-admin.sh
ExecStart=/usr/local/bin/rotate-wp-admin-academy.sh
```

### Grafana KV seeding task

```yaml
- name: Seed Grafana admin password in OpenBao
  ansible.builtin.command: >-
    {{ openbao_cli }} kv put secret/grafana
    admin_password={{ vault_grafana_admin_password }}
  environment: "{{ openbao_env | combine({'VAULT_TOKEN': openbao_bootstrap_token}) }}"
  changed_when: true
  when:
    - openbao_bootstrap_token is defined
    - vault_grafana_admin_password is defined
  no_log: true
  tags: [openbao, bootstrap]
```

---

## Runtime State Inventory

> This phase adds new items to OpenBao KV and new scripts/timers on disk. No rename or migration.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | `secret/mariadb` exists with `root_password` only; `secret/wordpress-academy` not yet seeded | Bootstrap task: add `exporter_password` to mariadb seed; add `secret/wordpress-academy` seed |
| Live service config | `monthly-secret-rotate.service` deployed on server (if rotation.yml has been run) | Ansible re-deploy overwrites file idempotently |
| OS-registered state | `wordpress-secret-rotate.timer` and `monthly-secret-rotate.timer` registered | New timer `wordpress-academy-secret-rotate.timer` requires `systemctl daemon-reload` + enable |
| Secrets/env vars | `vault_mariadb_exporter_password` in secrets.yml (default: `changeme`) — needs real value before seeding | Set real value in vault before running bootstrap |
| Build artifacts | None — all scripts deployed via Ansible `copy` tasks | None |

**Note on academy token file:** `/root/.openbao-academy-token` must exist on the server with the
`wordpress-academy-rotator` token before the academy rotation scripts can run. The bootstrap
already creates this token and outputs it for manual placement (see `setup-openbao-rotation.yml`
debug output). This is a pre-condition the planner must include as a manual step.

---

## Environment Availability

> Phase runs on the existing production server (Phase 3 + 3.5 must complete first).
> All dependencies are part of the base OS deploy.

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| bao CLI | All KV seeding + scripts | Deployed in Phase 3 | OpenBao role |
| jq | Academy DB rotation script | Installed in setup-openbao-rotation.yml | Already present |
| WP-CLI | Academy admin rotation script | Deployed by nginx_wordpress role | Path: `sudo -u www-data wp` |
| php8.3-fpm | PHP-FPM reload in DB rotation | Deployed in Phase 3 | Same as main site |
| systemd | Timers | Debian 13 base | Always available |
| openssl | Password generation in scripts | Debian 13 base | Always available |

**Missing dependencies with no fallback:** None — all dependencies are in the existing stack.

---

## Open Questions

1. **`secret/mariadb` bootstrap task: `put` vs `patch`**
   - What we know: Current task uses `bao kv put secret/mariadb root_password=...`
   - What's unclear: Should we add `exporter_password` to the same `put` call, or use
     a separate `patch` task after? Both work on first bootstrap. A second `patch` task
     is cleaner for separation of concerns but requires the secret to already exist.
   - Recommendation: Add `exporter_password` to the existing `put` task (single atomic
     write, both fields in one call). Add `when: vault_mariadb_exporter_password is defined`
     guard. If the var is not defined, the task is skipped and `exporter_password` is omitted.

2. **Academy WP admin initial seeding in bootstrap**
   - What we know: `secret/wordpress` is seeded in bootstrap with `admin_password` from
     `vault_wordpress_admin_password`. No equivalent for academy.
   - What's unclear: Which vault var name to use — `vault_wordpress_academy_admin_password`
     or `vault_nginx_wordpress_admin_password` (reuse)?
   - Recommendation: Use `vault_wordpress_academy_admin_password` for clarity. Add to
     `secrets.yml.example`.

3. **Grafana policy: read-only access or no policy**
   - What we know: `secret/grafana` is useful as a reference but Grafana reads its admin
     password from `grafana.ini` (Ansible template), not from OpenBao at runtime.
   - What's unclear: Should a `grafana-reader` policy and token be created?
   - Recommendation: No policy/token needed. The purpose is operator reference via MOTD
     (`bao kv get -field=admin_password secret/grafana`). Skip policy creation.

---

## Sources

### Primary (HIGH confidence)

- `ansible/playbooks/tasks/openbao-bootstrap.yml` — existing patterns, policies, token creation
- `ansible/playbooks/setup-openbao-rotation.yml` — existing script/service/timer patterns
- `ansible/inventory/group_vars/wordpress_servers/mariadb.yml` — `vault_mariadb_exporter_password` var
- `ansible/inventory/group_vars/monitoring_servers/grafana.yml` — `vault_grafana_admin_password` var
- `ansible/inventory/group_vars/all/secrets.yml.example` — vault var naming conventions
- `.planning/todos/pending/2026-04-02-complete-openbao-secret-coverage-and-rotation-for-all-services.md` — gap analysis

### Secondary (MEDIUM confidence)

- OpenBao KV-v2 `patch` behavior: consistent with HashiCorp Vault KV-v2 PATCH semantics
  (project already uses `bao kv patch` in `rotate-wp-admin.sh` — confirmed working)

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all patterns exist in the codebase and are proven working
- Architecture: HIGH — academy scripts are direct copies with two variable changes
- Pitfalls: HIGH — derived from reading actual existing scripts and bootstrap tasks

**Research date:** 2026-04-01
**Valid until:** Stable (no external dependencies; all patterns are internal to this codebase)
