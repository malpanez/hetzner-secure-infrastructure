# Deployment Playbook

Fresh server deployment sequence. The `ansible.cfg` sets the default inventory
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

## Step 3 — Base deployment

```bash
cd ansible
ansible-playbook playbooks/site.yml
```

Expected: play fails on OpenBao initialized assert. Everything else (common,
security, firewall, MariaDB, nginx, monitoring) applies cleanly. Transit is
running; primary is up but not yet initialized.

---

## Step 4 — Bootstrap transit (one-time)

```bash
ansible-playbook playbooks/openbao-transit-bootstrap.yml -e openbao_transit_bootstrap_ack=true
```

**STOP — save to password manager before continuing:**
- 5x Transit unseal keys (need 3 of 5 after every reboot)
- Transit root token
- Auto-unseal token (used in Step 5)

---

## Step 5 — Add auto-unseal token to Ansible Vault

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

Set (remove any duplicate entry):
```yaml
vault_openbao_transit_token: "<auto-unseal token from Step 4>"
```

---

## Step 6 — Re-deploy OpenBao primary with auto-unseal

```bash
ansible-playbook playbooks/site.yml --tags openbao
```

Primary now starts with the correct transit token and auto-unseals.

---

## Step 7 — Bootstrap primary OpenBao

```bash
ansible-playbook playbooks/openbao-bootstrap.yml -e openbao_bootstrap_ack=true
```

**STOP — save to password manager when displayed:**
- 5x Recovery keys
- Root token

If the play fails mid-run, the root token is preserved at
`/root/.openbao-bootstrap-token` (mode 600). Re-run the same command — it will
load the token from disk and resume seeding without re-initializing.

The file is deleted automatically on successful completion.

---

## Step 8 — Deploy WordPress (dual-site)

```bash
ansible-playbook playbooks/dual-wordpress.yml
```

---

## Step 9 — Deploy rotation scripts and timers

```bash
ansible-playbook playbooks/setup-openbao-rotation.yml
```

---

## Step 10 — Verify

```bash
# MariaDB binary logging
ssh 91.98.232.248 "sudo mysql -e \"SHOW VARIABLES LIKE 'log_bin';\""
# Expected: log_bin = ON

# OpenBao rotation timers
ssh 91.98.232.248 "systemctl list-timers | grep rotate"
# Expected: rotate-mariadb, rotate-wordpress, rotate-wordpress-academy timers

# Both WordPress sites reachable
curl -sI https://twomindstrading.com | head -1
curl -sI https://academy.twomindstrading.com | head -1
# Expected: HTTP/2 200
```
