# Domain Pitfalls

**Domain:** Hardened VPS infrastructure (Terraform + Ansible + Secrets Management + WordPress/LMS)
**Researched:** 2026-03-28

## Critical Pitfalls

### Pitfall 1: Secrets Manager Sealed After Reboot Breaks Application Access

**What goes wrong:** OpenBao (or Vault) requires manual unseal after every reboot. If the transit instance on 8201 is not unsealed before the primary on 8200 is started, the primary cannot auto-unseal. WordPress loses database credentials and becomes inaccessible.

**Why it happens:** Transit auto-unseal is not the same as automatic startup. systemd starts OpenBao but the transit instance must be unsealed with physical key shares before it can unseal the primary.

**Consequences:** Application downtime. In this project this was the direct cause of the 2026-03-26 security incident — the admin lockout created an opportunity for an attacker to overwrite the site.

**Prevention:**
- Document and rehearse the unseal runbook before any reboot
- Add MOTD warning that lists the unseal procedure
- Consider a UPS or snapshot-before-reboot policy to minimise unplanned reboots
- Add an external health check (uptime monitor) that alerts within minutes of WordPress going down

**Detection:** WordPress returns 500/502. `systemctl status openbao` shows "sealed". `/health` endpoint on port 8200 returns `{"sealed":true}`.

---

### Pitfall 2: No External Backups + No Binary Logging = Unrecoverable Data Loss

**What goes wrong:** A single VPS with no off-site backup and binary logging disabled means any data-destroying event (attacker, accidental DROP, disk failure) results in permanent data loss.

**Why it happens:** Binary logging is often deferred because it adds I/O overhead and complexity. Off-site backups require automation work that is easy to postpone on a live server.

**Consequences:** As demonstrated in the 2026-03-26 incident, original LearnDash course data was lost permanently when the attacker restored their project over the existing WordPress. No binary logs, no Hetzner snapshot, no off-site backup.

**Prevention:**
- Enable binary logging (`mariadb_log_bin_enabled: true`) — already added to Ansible, must be applied
- Configure automated Hetzner snapshots (daily, keep 7)
- Add off-site backup: `mysqldump` + `restic` or `borgbackup` to Hetzner Object Storage or B2
- Implement `wp-content` filesystem backup separately from the database

**Detection:** After a destructive event you will notice there is nothing to restore from.

---

### Pitfall 3: Rotation Scripts Never Run = False Security Posture

**What goes wrong:** Rotation playbooks exist in the repository but are never executed. The assumption that secrets are being rotated is wrong. Static credentials remain unchanged indefinitely.

**Why it happens:** Idempotent playbooks give false confidence — the file exists, so it must be working. Initial setup steps (first run, token creation) are blocked by "maintenance window" deferral and never revisited.

**Consequences:** Static MariaDB root and WP admin credentials never rotate. No `/root/.openbao-token` or `/root/.openbao-mariadb-token` means rotation scripts will fail silently. Demonstrated in this project: `setup-openbao-rotation.yml` was never run.

**Prevention:**
- After writing any rotation playbook, run it immediately and verify the token files and cron entries exist on the server
- Add a CI smoke-test or Ansible check-mode task that verifies expected cron entries are present
- Record rotation state explicitly (see MEMORY.md pattern)

**Detection:** SSH to server, check `crontab -l` for root and verify token files exist.

---

## High Pitfalls

### Pitfall 4: SSH Locked to Single IP Without Recovery Path

**What goes wrong:** Firewall rules restrict SSH to one IP. If that IP changes (ISP DHCP, travel, mobile tether) you are locked out of the server permanently unless a recovery console exists.

**Prevention:**
- Always verify Hetzner rescue/VNC console access before making firewall changes
- Keep a second admin IP (e.g., a VPN exit node or cloud shell) in the allowlist
- Document the Hetzner console URL and credentials in an offline password manager

---

### Pitfall 5: Third-Party WordPress Admin Access Without Audit Trail

**What goes wrong:** Granting WordPress admin to external parties without audit logging allows them to make destructive changes. Standard WordPress does not log admin actions by default.

**Consequences:** As in the 2026-03-26 incident, an external WP admin silently restored a different project over the existing site while the legitimate admin was locked out.

**Prevention:**
- Install WP Activity Log or Simple History before granting any third-party admin access
- Restrict third-party users to Editor role unless Admin is strictly required
- Enable Cloudflare Access or HTTP basic auth as a second gate for `/wp-admin`

---

### Pitfall 6: Unpinned GitHub Actions (`@master`) Create Supply Chain Risk

**What goes wrong:** Using `@master` for third-party actions means any pushed commit to that action's repo runs in your CI pipeline without review.

**Prevention:** Pin all third-party actions to a specific SHA or tagged release. Current offenders in this project: `aquasecurity/trivy-action@master`, `ludeeus/action-shellcheck@master`.

---

## Moderate Pitfalls

### Pitfall 7: Ansible Root Token Leaked in Verbose Output

**What goes wrong:** Tasks in `openbao-bootstrap.yml` that use `environment: VAULT_TOKEN: ...` will print the token value in `-vvv` verbose output and in CI logs.

**Prevention:** Add `no_log: true` to any task with secrets in the `environment:` block.

---

### Pitfall 8: `curl | sh` in CI Without Integrity Check

**What goes wrong:** Installing tools with `curl -LsSf ... | sh` trusts the remote server blindly.

**Prevention:** Download the script, verify a published SHA256 checksum, then execute.

---

### Pitfall 9: Hetzner Firewall Does Not Replace Host-Level Firewall

**What goes wrong:** Relying solely on the Hetzner cloud firewall means any network interface change (private network, floating IP) may bypass it entirely.

**Prevention:** Maintain `ufw` or `nftables` rules on the host as the authoritative firewall.

---

## Minor Pitfalls

### Pitfall 10: `set -e` Instead of `set -euo pipefail` in Shell Scripts

**Prevention:** Use `set -euo pipefail` as the standard header for all bash scripts.

### Pitfall 11: Unquoted Variables in SSH Commands

**Prevention:** Always quote: `ssh user@"$HOST"`.

### Pitfall 12: Two Git Remotes with Different Visibility

**Prevention:** After every push to `origin` (Codeberg), push to `github` (GitHub). CI runs on GitHub — if it lags behind, CI tests stale code.

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|---|---|---|
| Enable binary logging on live server | MariaDB restart required; brief downtime | Schedule maintenance window, take Hetzner snapshot first |
| Run `setup-openbao-rotation.yml` for first time | Token files don't exist yet; rotation scripts will fail | Run playbook, then verify cron + token files on server |
| Off-site backup implementation | Backup job silently fails if credentials expire | Add backup verification step (restore test) to cron |
| Grant any future third-party WP access | No audit trail by default | Install activity logging plugin before granting access |
| Upgrade OpenBao or transit instance | Sealed state is lost | Always unseal transit first, verify health endpoint, then start primary |
| Rotate static secrets for first time | WP site goes down if MariaDB password changed in KV but not applied to MariaDB | Script must update both atomically; test in staging first |
