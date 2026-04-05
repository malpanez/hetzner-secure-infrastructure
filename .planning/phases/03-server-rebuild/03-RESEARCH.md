# Phase 3: Server Rebuild - Research

**Researched:** 2026-04-05
**Domain:** Hetzner Terraform destroy+apply, Ansible deploy.yml orchestrator, OpenBao transit unseal, OPS hardening
**Confidence:** HIGH — all findings from direct codebase inspection; no external sources needed

---

## Summary

Phase 3 is a planned destructive rebuild of a live production server. The entire automation
sequence is already implemented (deploy.yml from Phase 7, dual-wordpress.yml from Phase 1, all
roles from Phases 1–7). The planner's job is to sequence three operational acts: (1) the
Terraform destroy+apply with maintenance window coordination, (2) the Ansible deploy.yml
full-stack run with its two interactive pauses, and (3) post-deploy OPS hardening items that are
not fully wired into deploy.yml (fail2ban dual-path, AppArmor nginx paths, Valkey maxmemory).

The biggest risks are data loss before destroy (no external backup currently active), the
`prevent_destroy` flag in production.tfvars (currently commented out — confirmed safe to
destroy), and the IP address change after destroy (new server gets new IP; Cloudflare DNS and
Ansible inventory must update before Ansible can reach the host).

Binary logging (`mariadb_log_bin_enabled: true`) is already in group_vars and the 60-binlog.cnf.j2
template exists — it applies automatically on first MariaDB install via `mysql_config_include_files`.
No separate tag or extra-var is needed for a fresh server.

**Primary recommendation:** Follow the three-plan sequence exactly as roadmapped. Do not combine
plans — each has a different risk profile and may need to pause for operator action.

---

## Project Constraints (from CLAUDE.md)

- Ansible: FQCN for all modules (`ansible.builtin.*`)
- Terraform: `_` not `-` in resource names; never `apply` without plan review
- Pre-commit hooks: yamllint (max 250 chars), ansible-lint (production profile), gitleaks
- Conventional commits: `feat/fix/refactor/docs(scope): message`
- No auto-push — always confirm before pushing
- OpenBao must be manually unsealed after every reboot (transit 8201 first, then primary 8200)
- SSH is locked to a single IP — no SSH until inventory is updated with new server IP

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| INFRA-01 | `terraform destroy + apply` executed in maintenance window | Terraform destroy sequence, prevent_destroy flag handling |
| INFRA-02 | OpenBao transit (8201) unsealed manually post-deploy before starting primary (8200) | deploy.yml transit bootstrap pause, transit unseal key procedure |
| INFRA-03 | OpenBao primary (8200) started and verified unsealed | deploy.yml primary bootstrap pause, auto-unseal via transit |
| INFRA-04 | `site.yml` + `dual-wordpress.yml` executed cleanly on new server | deploy.yml imports both; single command covers this |
| OPS-01 | `valkey_maxmemory` increased to 512MB | Currently 256mb in valkey.yml; requires group_vars edit + re-run |
| OPS-02 | MariaDB binary logging applied to server | `mariadb_log_bin_enabled: true` already in mariadb.yml; applies on fresh install automatically |
| OPS-03 | `setup-openbao-rotation.yml` run cleanly; WP_PATH points to `/var/www/twomindstrading.com` | deploy.yml imports setup-openbao-rotation.yml; WP_PATH hardcoded correctly in script |
| OPS-04 | Fail2ban jails monitoring both nginx log paths | Currently only sshd jail in defaults; nginx jails must be added to fail2ban_services |
| OPS-05 | AppArmor profiles covering `/var/www/*/` | AppArmor role has sshd + fail2ban profiles only; nginx/php-fpm paths need local profile additions |
</phase_requirements>

---

## Standard Stack

All components are already present in the codebase. No new libraries or tools needed.

### Core (Phase 3 Execution Tools)

| Tool | Version/Location | Purpose |
|------|-----------------|---------|
| Terraform | `>= 1.6.0`, provider `hcloud ~> 1.45` | Destroy + apply Hetzner VPS |
| Ansible | system install | Run deploy.yml orchestrator |
| `ansible/playbooks/deploy.yml` | Phase 7 — complete | Full-stack orchestrator |
| `ansible/playbooks/dual-wordpress.yml` | Phase 1 — complete | MariaDB + Valkey + dual WP |
| `ansible/playbooks/setup-openbao-rotation.yml` | Phase 6 — complete | Rotation timers |
| Ansible Vault `secrets.yml` | `group_vars/all/secrets.yml` | All vault vars including transit token |

### OPS Hardening Items (need config changes before deploy)

| Item | Current State | Action Needed |
|------|--------------|---------------|
| `valkey_maxmemory` | 256mb in `group_vars/wordpress_servers/valkey.yml` | Change to 512mb before deploy |
| MariaDB binary logging | `mariadb_log_bin_enabled: true` already set | Nothing — applies on fresh install |
| Fail2ban nginx jails | Only `sshd` in `fail2ban_services` defaults | Add nginx jail entries to group_vars or role defaults |
| AppArmor nginx/php-fpm paths | Profiles: sshd + fail2ban only | Add local profile for nginx covering `/var/www/*/` |

---

## Architecture Patterns

### deploy.yml Execution Sequence

The orchestrator executes in this fixed order (from direct file inspection):

```
1. common.yml (base hardening)
2. Install OpenBao — first pass (no transit token, transit instance only)
   → SKIP if binary exists AND vault_openbao_transit_token is set (re-run guard)
3. Bootstrap OpenBao Transit (init + unseal + create autounseal key/token)
   → REQUIRES: openbao_transit_bootstrap_ack=true
   → PAUSE 1: Save transit unseal keys (5), transit root token, auto-unseal token
4. Re-deploy OpenBao with transit token (second pass, primary instance)
5. Bootstrap primary OpenBao (init + seed all KV secrets + create rotation tokens)
   → REQUIRES: openbao_bootstrap_ack=true
   → PAUSE 2: Save recovery keys (5) and primary root token
6. monitoring.yml
7. dual-wordpress.yml (MariaDB + Valkey + main site + academy site)
8. Finalize OpenBao MariaDB integration (post-WordPress play)
9. PAUSE 3: Verify token files exist on server before rotation setup
10. setup-openbao-rotation.yml
11. validate.yml
```

### Pre-Destroy Checklist

Items that must be captured BEFORE terraform destroy (all data on current server will be lost):

| Item | Where | Action |
|------|-------|--------|
| OpenBao transit unseal keys (5) | BitWarden | Verify present — needed to unseal transit after rebuild |
| OpenBao transit root token | BitWarden | Verify present |
| OpenBao transit auto-unseal token | `secrets.yml` as `vault_openbao_transit_token` | Verify it's set — deploy.yml uses it on re-runs |
| OpenBao primary recovery keys (5) | BitWarden | For reference only — new keys generated on rebuild |
| OpenBao primary root token | BitWarden | For reference only — new token generated on rebuild |
| DNS TTL | Cloudflare dashboard | Lower to 60s ~30min before destroy to speed propagation after IP change |
| Current server IP | `terraform output` or Hetzner console | For reference |

**Note:** KV secrets (passwords, SMTP, Stripe, etc.) do NOT need to be backed up separately — they
are seeded from `secrets.yml` by openbao-bootstrap.yml on the fresh server. The secrets.yml vault
file IS the source of truth.

### Post-Apply Inventory Update (Critical Gap)

After `terraform apply`, the server has a new IP. Ansible cannot reach it until the inventory
reflects the new IP. The dynamic inventory (`hetzner.hcloud.yml`) resolves this automatically
via hcloud API — no manual step needed as long as `HCLOUD_TOKEN` is set.

**Verify with:** `ansible-inventory --list | grep ansible_host` before running deploy.yml.

### Terraform Destroy Sequence

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform
source .envrc              # Sets TF_VAR_hcloud_token, TF_CLI_ARGS_*
terraform plan -destroy    # Review what will be deleted
terraform destroy          # Requires typing 'yes'
```

**prevent_destroy status:** Currently `commented out` in both `production.tfvars` (line 119)
and `modules/hetzner-server/main.tf` (lifecycle block). Destroy will succeed without any
file changes needed.

### Terraform Apply Sequence

```bash
terraform apply            # TF_CLI_ARGS_apply auto-appends -var-file=production.tfvars
```

Wait for cloud-init to complete before running Ansible (~60–90 seconds after apply).
Check with: `ssh malpanez@<new-ip> 'cloud-init status'`

### Full Ansible Deploy Command

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/ansible
> ansible.log              # Clear log BEFORE run — secrets appear in debug output
ansible-playbook playbooks/deploy.yml \
  -e "openbao_transit_bootstrap_ack=true openbao_bootstrap_ack=true"
```

**No `-i` flag needed** — `ansible.cfg` sets default inventory to `inventory/hetzner.hcloud.yml`.

### OpenBao Transit Unseal After Rebuild

On a fresh server, deploy.yml handles transit init automatically (bootstrap play). The operator
does NOT need to manually unseal transit during a fresh deploy — the bootstrap play inits and
unseals it programmatically, then pauses for credential saving.

Manual transit unseal is only needed AFTER A REBOOT (day-2 ops), not during a fresh deploy.

**Transit unseal procedure (post-reboot only):**
```bash
export VAULT_ADDR=https://127.0.0.1:8201
export VAULT_SKIP_VERIFY=1
bao operator unseal <key-1>
bao operator unseal <key-2>
bao operator unseal <key-3>   # 3 of 5 required
sudo systemctl start openbao  # Primary then auto-unseals
```

### OPS Hardening — Items NOT Fully Wired Into deploy.yml

#### OPS-01: Valkey maxmemory 512MB

Change before running deploy.yml:
- File: `ansible/inventory/group_vars/wordpress_servers/valkey.yml`
- Line: `valkey_maxmemory: 256mb` → `valkey_maxmemory: 512mb`
- Applied by: `dual-wordpress.yml` → valkey role (no separate tag needed)

#### OPS-02: MariaDB Binary Logging

Already wired. `mariadb_log_bin_enabled: true` is set in `mariadb.yml`.
`mysql_config_include_files` includes `60-binlog.cnf.j2`.
On a fresh install via `dual-wordpress.yml` → `geerlingguy.mysql`, it applies automatically.

Verify after deploy: `mysql -uroot -p$(bao kv get -field=root_password secret/mariadb) -e "SHOW MASTER STATUS;"`

#### OPS-04: Fail2ban Dual Nginx Log Paths

The fail2ban role's `jail.local.j2` template loops `fail2ban_services`. Currently only `sshd` is
defined in `defaults/main.yml`. To add nginx jails:

Add to `group_vars/wordpress_servers/` (new file e.g. `fail2ban.yml`) or override in
`group_vars/all/common.yml`:

```yaml
fail2ban_services:
  - name: sshd
    enabled: true
    port: 22
    filter: sshd
    logpath: /var/log/auth.log
    maxretry: 3
    bantime: 3600
    findtime: 600
  - name: nginx-main
    enabled: true
    port: "80,443"
    filter: nginx-http-auth
    logpath: /var/log/nginx/main-access.log
    maxretry: 5
    bantime: 600
    findtime: 600
  - name: nginx-academy
    enabled: true
    port: "80,443"
    filter: nginx-http-auth
    logpath: /var/log/nginx/academy-access.log
    maxretry: 5
    bantime: 600
    findtime: 600
```

**Note:** The nginx log paths follow the pattern from `nginx_wordpress_site_name`:
`/var/log/nginx/main-access.log` and `/var/log/nginx/academy-access.log`.
Verify actual log path names from the nginx_wordpress role template.

#### OPS-05: AppArmor Nginx/PHP-FPM Web Root Paths

The AppArmor role (`roles/apparmor/defaults/main.yml`) currently profiles only `sshd` and
`fail2ban-server`. There is no nginx or php-fpm AppArmor profile in the role templates.

To cover `/var/www/*/`: Add local profile overrides via `apparmor_profiles_dir` and
`apparmor_local_dir` variables. This requires either:

1. A new AppArmor local override file for nginx (e.g., `/etc/apparmor.d/local/usr.sbin.nginx`)
   that adds `r /var/www/** r,` paths — deployed via a new template in the role
2. Or verify that Debian 13's default nginx AppArmor profile already covers `/var/www/*/`
   (Debian ships nginx without an enforced AppArmor profile by default — complain mode only)

**Current AppArmor mode:** `apparmor_enforce_mode: false` (complain mode) in `common.yml`.
In complain mode, AppArmor logs violations but does not block. OPS-05 may be satisfied by
adding the correct paths in complain mode so violations are visible if enforce is later enabled.

**Practical approach for Phase 3:** Confirm that AppArmor is in complain mode (it is), verify
the apparmor role runs without errors, and document that nginx/php-fpm path coverage is
configuration-only (no enforcement, no blocking risk).

### setup-openbao-rotation.yml Verification

After deploy.yml completes, verify rotation is working:

```bash
# Check all timers are active
systemctl list-timers | grep -E "rotate|rotation"

# Expected timers:
#   wordpress-secret-rotate.timer       (daily 03:00)
#   wordpress-academy-secret-rotate.timer (daily 03:30)
#   monthly-secret-rotate.timer         (monthly 1st at 02:00)

# Check token files exist
ls -la /root/.openbao-token \
        /root/.openbao-academy-token \
        /root/.openbao-mariadb-token \
        /root/.openbao-backup-token

# WP_PATH in main rotation script
grep WP_PATH /usr/local/bin/rotate-wordpress-secrets.sh
# Expected: WP_PATH="/var/www/twomindstrading.com"
```

The scripts hardcode `WP_PATH="/var/www/twomindstrading.com"` — confirmed correct per OPS-03.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead |
|---------|-------------|-------------|
| Full-stack orchestration | Manual playbook sequence | `deploy.yml` — already handles complete sequence |
| OpenBao init/unseal | Manual bao commands | deploy.yml bootstrap plays — automated with pauses |
| MariaDB binary logging | Custom cnf template | `60-binlog.cnf.j2` + `mysql_config_include_files` — already wired |
| IP change after destroy | Static inventory update | hcloud dynamic inventory resolves from API |
| Rotation timers | Manual systemd units | `setup-openbao-rotation.yml` — complete implementation |

---

## Runtime State Inventory

This is a rebuild phase — all runtime state on the current server is intentionally destroyed
and re-created from IaC + secrets.yml.

| Category | Items Found | Action Required |
|----------|-------------|-----------------|
| Stored data | OpenBao KV: `secret/mariadb`, `secret/wordpress`, `secret/wordpress-academy`, `secret/grafana` — all seeded from `secrets.yml` variables in `openbao-bootstrap.yml` | None — re-seeded automatically on fresh deploy from secrets.yml |
| Live service config | OpenBao policies and tokens are re-created by bootstrap tasks | None — idempotent via bootstrap |
| OS-registered state | systemd timers (wordpress-secret-rotate, monthly-secret-rotate, etc.) — re-created by setup-openbao-rotation.yml | None — applied by deploy.yml |
| Secrets/env vars | `vault_openbao_transit_token` in secrets.yml MUST contain current transit auto-unseal token to enable re-run guard | Verify this is set in secrets.yml before destroy — the new deploy creates a NEW transit token that must be updated in secrets.yml after the run |
| Build artifacts | None — server-side artifacts are destroyed with the server | None |

**Critical note on transit token rotation:** After a fresh deploy, a NEW auto-unseal token is
generated. After deploy.yml completes, update `secrets.yml`:
```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
# Set: vault_openbao_transit_token: "<auto-unseal token from Pause 1>"
```

---

## Common Pitfalls

### Pitfall 1: DNS / Cloudflare Pointing at Old IP

**What goes wrong:** After `terraform apply` creates a new server with a new IP, Cloudflare DNS
still points to the old IP (which no longer exists). `curl -I https://twomindstrading.com`
returns errors or connects to nothing.

**Why it happens:** Cloudflare DNS A records are managed by Terraform (`cloudflare-config` module).
`terraform apply` updates them — but if DNS TTL was high (auto = 5min), propagation takes time.

**How to avoid:** Lower Cloudflare proxy TTL to 60s before destroy. After apply, verify DNS
points to new IP: `dig +short twomindstrading.com`.

**Note:** Cloudflare-proxied records do NOT expose the real server IP to the public. The IP
change is internal to Cloudflare's infrastructure.

### Pitfall 2: Ansible Cannot Reach Server (SSH host key mismatch)

**What goes wrong:** New server has a different SSH host key. Ansible fails with
"WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED".

**Why it happens:** `~/.ssh/known_hosts` has the old server's key.

**How to avoid:** After terraform apply, remove the old key:
```bash
ssh-keygen -R <new-server-ip>
ssh-keygen -R <old-server-ip>
```
Or confirm with: `ssh -o StrictHostKeyChecking=accept-new malpanez@<new-ip> 'hostname'`

### Pitfall 3: deploy.yml Skips OpenBao Bootstrap (Re-Run Guard Triggers)

**What goes wrong:** If `vault_openbao_transit_token` is set in secrets.yml AND the binary
exists on the fresh server (unlikely but possible with image caching), deploy.yml skips the
transit bootstrap entirely.

**Why it happens:** The re-run guard in deploy.yml first-pass play:
```yaml
when:
  - vault_openbao_transit_token | default('') != ''
  - bao_binary_check.stat.exists
```

**How to avoid:** This is only a risk if using a Hetzner snapshot image with OpenBao
pre-installed. For a standard Debian 13 image (production.tfvars uses `image` var), OpenBao
binary won't exist and the guard won't trigger.

### Pitfall 4: ansible.log Contains Plaintext Secrets

**What goes wrong:** openbao-bootstrap.yml displays recovery keys and root tokens via
`ansible.builtin.debug`. These appear in ansible.log in plaintext.

**Why it happens:** Intentional design — allows credential capture during automated run.

**How to avoid:**
1. Clear log BEFORE run: `> ansible/ansible.log`
2. Save credentials from log DURING the interactive pauses
3. Clear log AFTER saving: `> ansible/ansible.log`

### Pitfall 5: Rotation Token Files Not Present Before setup-openbao-rotation.yml

**What goes wrong:** deploy.yml has a PAUSE 3 that prompts to verify token files exist.
If the bootstrap task that writes token files failed or was skipped, rotation scripts will fail
on first run.

**Why it happens:** Token files are written by openbao-bootstrap.yml tasks that capture tokens
from KV and write to `/root/.openbao-*-token`. These tasks run on the server via the bootstrap
play. If any earlier task failed and bootstrap was re-run, tokens may not have been re-written.

**How to avoid:** During PAUSE 3, SSH to server and verify:
```bash
ls -la /root/.openbao-token /root/.openbao-academy-token \
        /root/.openbao-mariadb-token /root/.openbao-backup-token
```
If missing, check the bootstrap debug output for token values and write manually.

### Pitfall 6: Valkey maxmemory Not Updated Before Deploy

**What goes wrong:** OPS-01 requires 512MB but valkey.yml currently has 256mb. If deploy.yml
runs without updating this first, Valkey starts with 256MB and a second Ansible run is needed.

**How to avoid:** Update `valkey.yml` and commit BEFORE the maintenance window. This is a
pre-deploy config change, not a post-deploy fix.

---

## Code Examples

### Check transit bootstrap guard condition

From `deploy.yml` lines 18–21 (the re-run guard that skips transit bootstrap):
```yaml
- name: Skip first pass if OpenBao already installed with transit token (re-run)
  ansible.builtin.meta: end_play
  when:
    - vault_openbao_transit_token | default('') != ''
    - bao_binary_check.stat.exists
```

### Fail2ban service addition pattern (from jail.local.j2)

The template loops `fail2ban_services`:
```jinja2
{% for service in fail2ban_services %}
[{{ service.name }}]
enabled = {{ service.enabled | ternary('true', 'false') }}
port = {{ service.port }}
filter = {{ service.filter }}
logpath = {{ service.logpath }}
...
{% endfor %}
```

Override `fail2ban_services` in group_vars to add nginx jails.

### Binary logging applies via mysql_config_include_files

From `mariadb.yml` group_vars:
```yaml
mysql_config_include_files:
  - src: 60-binlog.cnf.j2
    force: true
```

The `geerlingguy.mysql` role copies this template to `/etc/mysql/mariadb.conf.d/60-binlog.cnf`
on first install. No separate `--tags mariadb` run is needed on a fresh server.

---

## Environment Availability

| Dependency | Required By | Available | Notes |
|------------|------------|-----------|-------|
| Hetzner Cloud API token | `terraform destroy/apply` | In `.envrc` (not git) | `source .envrc` before terraform |
| Cloudflare API token | `terraform apply` (Cloudflare module) | In `secrets.yml` as `vault_cloudflare_api_token` | Loaded via Ansible vault |
| Ansible Vault password | `ansible-playbook` | `~/.ansible/vault_password` | Must be present on controller |
| OpenBao transit unseal keys (5) | Manual step post-reboot, not during fresh deploy | In BitWarden | Verify present before maintenance window |
| hcloud dynamic inventory | Ansible host discovery after new IP | Requires `HCLOUD_TOKEN` env var | Set via `source .envrc` or `TF_VAR_hcloud_token` — check if `hcloud` inventory plugin reads `HCLOUD_TOKEN` |

**Note on hcloud inventory:** The dynamic inventory at `ansible/inventory/hetzner.hcloud.yml`
uses the `hcloud` inventory plugin. This requires `HCLOUD_TOKEN` environment variable to be set.
Verify this is available in the Ansible execution environment (it may need `export HCLOUD_TOKEN=$TF_VAR_hcloud_token` if not already set).

---

## Plan-Specific Guidance

### Plan 03-01: Terraform destroy + apply

**Pre-destroy checklist (verify each):**
1. `vault_openbao_transit_token` is set in `secrets.yml` (for future re-runs)
2. OpenBao transit unseal keys (5) present in BitWarden
3. All `secrets.yml` vault vars are populated (passwords, salts, API tokens)
4. `valkey_maxmemory` updated to 512mb in `valkey.yml` and committed
5. Fail2ban nginx jails added to group_vars and committed
6. DNS TTL lowered in Cloudflare (optional but recommended)

**Terraform sequence:**
```bash
cd terraform
source .envrc
terraform plan -destroy    # Review
terraform destroy          # Type 'yes'
# Wait for destroy to complete
terraform apply            # Auto-applies production.tfvars
# Wait ~90s for cloud-init
ssh-keygen -R <old-ip> && ssh-keygen -R <new-ip>
ssh -o StrictHostKeyChecking=accept-new malpanez@<new-ip> 'cloud-init status --wait'
```

**Verify Cloudflare DNS updated:**
```bash
terraform output server_ipv4
dig +short twomindstrading.com
dig +short academy.twomindstrading.com
```

### Plan 03-02: Ansible full-stack deploy

**Pre-run steps:**
```bash
cd ansible
> ansible.log
```

**Full deploy command:**
```bash
ansible-playbook playbooks/deploy.yml \
  -e "openbao_transit_bootstrap_ack=true openbao_bootstrap_ack=true"
```

**Interactive pause actions:**

PAUSE 1 (transit init):
- Save 5 transit unseal keys to BitWarden
- Save transit root token to BitWarden
- Save auto-unseal token to BitWarden AND update secrets.yml:
  `ansible-vault edit inventory/group_vars/all/secrets.yml` → set `vault_openbao_transit_token`
- Press Enter

PAUSE 2 (primary init):
- Save 5 recovery keys to BitWarden
- Save primary root token to BitWarden
- Press Enter

PAUSE 3 (rotation tokens):
- SSH to server and verify token files: `ls -la /root/.openbao-*-token`
- If any missing, place manually (values shown in bootstrap debug output)
- Press Enter

**Post-deploy verification (OPS-02 binary logging):**
```bash
ssh malpanez@<server-ip> \
  "sudo mysql -e \"SHOW VARIABLES LIKE 'log_bin';\""
# Expected: log_bin | ON

ssh malpanez@<server-ip> \
  "sudo mysql -e \"SHOW MASTER STATUS;\""
# Expected: row with File and Position values
```

**HTTP checks:**
```bash
curl -sI https://twomindstrading.com | head -2
curl -sI https://academy.twomindstrading.com | head -2
```

### Plan 03-03: setup-openbao-rotation.yml verification

deploy.yml already imports setup-openbao-rotation.yml at the end. This plan is primarily
verification that it ran correctly.

**Verification commands:**
```bash
# All rotation timers active
ssh malpanez@<server-ip> "systemctl list-timers | grep -E 'rotate|rotation'"

# Expected timers (6 total):
# wordpress-secret-rotate.timer
# wordpress-academy-secret-rotate.timer
# monthly-secret-rotate.timer

# Verify WP_PATH in main rotation script
ssh malpanez@<server-ip> "grep WP_PATH /usr/local/bin/rotate-wordpress-secrets.sh"
# Expected: WP_PATH="/var/www/twomindstrading.com"

# Fail2ban jails watching both log paths
ssh malpanez@<server-ip> "sudo fail2ban-client status"
# Expected: nginx-main and nginx-academy jails listed
```

---

## Open Questions

1. **hcloud inventory plugin HCLOUD_TOKEN availability**
   - What we know: The `.envrc` sets `TF_VAR_hcloud_token` not `HCLOUD_TOKEN`
   - What's unclear: Whether the hcloud Ansible inventory plugin reads `HCLOUD_TOKEN` or
     `TF_VAR_hcloud_token` or a separate `ansible/inventory/hetzner.hcloud.yml` config key
   - Recommendation: Check `ansible/inventory/hetzner.hcloud.yml` config before the maintenance
     window to confirm the inventory can discover the new host IP automatically

2. **AppArmor OPS-05 scope on fresh server**
   - What we know: AppArmor is in complain mode; the role only templates sshd and fail2ban profiles
   - What's unclear: Whether "covering `/var/www/*/`" means adding an nginx AppArmor profile
     or just ensuring the wildcard path is in an existing profile
   - Recommendation: Interpret OPS-05 as a complain-mode coverage item for Phase 3 (log paths,
     no enforcement). Full enforcement is a v2 requirement (MEDIUM in REQUIREMENTS.md)

3. **nginx log file names for fail2ban**
   - What we know: The nginx_wordpress role uses `nginx_wordpress_site_name` to parameterize log names
   - What's unclear: The exact log file names (access/error pattern) — need to check the
     nginx vhost template to confirm `/var/log/nginx/main-access.log` is the right path
   - Recommendation: Check `roles/nginx_wordpress/templates/sites-available/wordpress.conf.j2`
     before writing the fail2ban group_vars override

---

## Sources

### Primary (HIGH confidence)
- Direct inspection of `ansible/playbooks/deploy.yml` — full execution sequence, pause conditions, skip guards
- Direct inspection of `ansible/playbooks/tasks/openbao-bootstrap.yml` — token creation, KV seeding, file paths
- Direct inspection of `ansible/playbooks/setup-openbao-rotation.yml` — timer names, WP_PATH values, token file paths
- Direct inspection of `ansible/roles/fail2ban/defaults/main.yml` + `templates/jail.local.j2` — current jails, template pattern
- Direct inspection of `ansible/roles/apparmor/defaults/main.yml` — current profiles
- Direct inspection of `ansible/inventory/group_vars/wordpress_servers/valkey.yml` — current maxmemory 256mb
- Direct inspection of `ansible/inventory/group_vars/wordpress_servers/mariadb.yml` — binary logging config
- Direct inspection of `terraform/modules/hetzner-server/main.tf` — prevent_destroy state (commented out)
- Direct inspection of `terraform/production.tfvars` — prevent_destroy commented out
- Direct inspection of `docs/deployment-playbook.md` — canonical deploy procedure
- Direct inspection of `ansible/inventory/group_vars/all/secrets.yml.example` — all vault vars required

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are in codebase, versions verified from actual files
- Architecture patterns: HIGH — deploy.yml sequence read directly from source
- Pitfalls: HIGH — derived from direct code inspection and MEMORY.md incident history
- OPS hardening items: HIGH (binary logging, Valkey) / MEDIUM (fail2ban nginx paths, AppArmor) — exact log path names unverified

**Research date:** 2026-04-05
**Valid until:** Until any of the following files change: deploy.yml, openbao-bootstrap.yml,
setup-openbao-rotation.yml, fail2ban/defaults/main.yml, valkey.yml, mariadb.yml
