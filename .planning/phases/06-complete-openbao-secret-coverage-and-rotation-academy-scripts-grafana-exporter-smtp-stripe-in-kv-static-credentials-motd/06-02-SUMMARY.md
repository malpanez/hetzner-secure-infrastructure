# Plan 06-02 Summary

**Status:** Complete
**Files changed:**
- `ansible/playbooks/setup-openbao-rotation.yml`
- `ansible/playbooks/tasks/openbao-bootstrap.yml`

## What was done

Added full rotation coverage for the academy site and a static operator MOTD:

1. **Academy DB rotation** — `rotate-wordpress-academy-secrets.sh` deployed to `/usr/local/bin`, with a systemd service (`wordpress-academy-secret-rotate.service`) and daily timer firing at 03:30 (offset 30 min from main site at 03:00). Token: `/root/.openbao-academy-token`, credentials path: `database/creds/wordpress-academy`.

2. **Academy WP admin rotation** — `rotate-wp-admin-academy.sh` deployed to `/usr/local/bin`; uses `bao kv patch secret/wordpress-academy` to update admin password monthly. Added to `monthly-secret-rotate.service` as a third `ExecStart` line.

3. **Fixed mariadb root rotation** — `rotate-mariadb-root.sh` changed from `kv put` to `kv patch secret/mariadb` so only `root_password` is updated and `exporter_password` (added by Plan 06-01) is preserved. Also added `"patch"` capability to the `mariadb-rotator` policy in `openbao-bootstrap.yml`.

4. **Static credentials MOTD** — `/etc/motd.d/80-credentials` deployed with `bao kv get` retrieval commands for all 8 secrets (MariaDB root, MariaDB exporter, WP admin main, WP admin academy, Grafana, SMTP if configured, Stripe if configured, Backup S3). Contains no actual passwords.

5. **Manual steps updated** — debug task extended with steps 10–13 covering academy token placement (`/root/.openbao-academy-token`) and academy script test commands.

6. **Log file loop** — `wp-admin-academy-rotation.log` appended as third item while preserving the original two.

## Verification

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure

# Academy scripts and timer present
grep -n 'rotate-wordpress-academy-secrets.sh\|rotate-wp-admin-academy.sh' ansible/playbooks/setup-openbao-rotation.yml

# Monthly service has 3 ExecStart lines
grep 'ExecStart' ansible/playbooks/setup-openbao-rotation.yml | grep -v '#'

# Static MOTD with (if configured) labels
grep -A25 '80-credentials' ansible/playbooks/setup-openbao-rotation.yml | grep 'if configured'

# Academy timer at 03:30
grep -A5 'OnCalendar' ansible/playbooks/setup-openbao-rotation.yml | grep '03:30'

# kv patch used (not kv put) for mariadb
grep 'kv patch secret/mariadb' ansible/playbooks/setup-openbao-rotation.yml
grep 'kv put secret/mariadb' ansible/playbooks/setup-openbao-rotation.yml && echo FAIL || echo OK

# mariadb-rotator policy has patch capability
grep -A3 '"secret/data/mariadb"' ansible/playbooks/tasks/openbao-bootstrap.yml | head -4

# ansible-lint clean
ansible-lint ansible/playbooks/setup-openbao-rotation.yml
```

## Commits

- `38670b5` — feat(06-02): add academy DB rotation script, service, and timer
- `6ab9b5a` — feat(06-02): fix mariadb rotation, add academy WP admin script, static MOTD

## Deviations from Plan

**1. [Rule 2 - Missing critical functionality] Added "patch" capability to mariadb-rotator policy in openbao-bootstrap.yml**
- Found during: Task 2
- Issue: openbao-bootstrap.yml mariadb-rotator policy had `["read", "create", "update"]` but not `"patch"`. Without it, `bao kv patch` falls back to read-then-put (dropping exporter_password), which defeats the fix.
- Fix: Added `"patch"` to capabilities list.
- Files modified: `ansible/playbooks/tasks/openbao-bootstrap.yml`
- Commit: 6ab9b5a
