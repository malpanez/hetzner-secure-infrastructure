# Deployment Playbook

Fresh server deployment. The `ansible.cfg` sets the default inventory
(`inventory/hetzner.hcloud.yml`) — no `-i` flag needed.

## Prerequisites

- Terraform state clean (`terraform destroy` completed)
- Ansible Vault password available
- Password manager open and ready

---

## Step 1 — Terraform apply

```bash
cd terraform
source .envrc
terraform apply
```

`production.tfvars` is loaded automatically via `TF_CLI_ARGS_apply` in `.envrc`.

---

## Step 2 — Clear ansible.log

```bash
> ansible/ansible.log
```

---

## Step 3 — Full deployment

```bash
cd ansible
ansible-playbook playbooks/site.yml \
  -e "openbao_transit_bootstrap_ack=true openbao_bootstrap_ack=true"
```

`site.yml` runs the entire sequence automatically: base hardening, OpenBao
install, transit bootstrap, primary bootstrap, WordPress (dual-site), monitoring,
rotation timers, and final validation. It pauses twice for credential saving:

- **Pause 1 (transit):** Save the 5 transit unseal keys, root token, and
  auto-unseal token to password manager. Press Enter to continue.
- **Pause 2 (primary):** Save the recovery keys and root token to password
  manager. Press Enter to continue.

After deployment completes, add the auto-unseal token to Ansible Vault for
future re-runs:

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
# Set: vault_openbao_transit_token: "<auto-unseal token from Pause 1>"
```

---

## Re-runs / Idempotency

```bash
ansible-playbook playbooks/site.yml
```

No extra vars needed on re-runs. The bootstraps and pauses are skipped when
OpenBao is already initialized.

---

## Day-2 Operations

```bash
# Base hardening only
ansible-playbook playbooks/site.yml --tags common

# OpenBao role only
ansible-playbook playbooks/site.yml --tags openbao

# WordPress (dual-site)
ansible-playbook playbooks/dual-wordpress.yml

# Monitoring stack
ansible-playbook playbooks/monitoring.yml

# Rotation timers
ansible-playbook playbooks/setup-openbao-rotation.yml

# Validation
ansible-playbook playbooks/validate.yml
```

---

## Verification

```bash
curl -sI https://twomindstrading.com | head -1
curl -sI https://academy.twomindstrading.com | head -1
ssh <server-ip> "systemctl list-timers | grep rotate"
ssh <server-ip> "sudo mysql -e \"SHOW VARIABLES LIKE 'log_bin';\""
```
