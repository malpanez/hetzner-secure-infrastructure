# Site Deployment Flow - Quick Reference

**Purpose**: Quick reference for deploying the complete infrastructure with OpenBao auto-unseal

---

## Complete Deployment (Fresh Install)

```bash
# 1. Deploy all infrastructure
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml

# 2. Bootstrap Transit OpenBao (auto-unseal provider)
ansible-playbook -i inventory/hetzner.hcloud.yml \
  playbooks/openbao-transit-bootstrap.yml \
  -e openbao_transit_bootstrap_ack=true

# SAVE: Transit unseal keys (5) + auto-unseal token

# 3. Add auto-unseal token to vault
ansible-vault edit inventory/group_vars/secrets_servers/vault.yml
# Add: vault_openbao_transit_token: "hvs.XXXXX"

# 4. Re-deploy Primary OpenBao with auto-unseal config
ansible-playbook -i inventory/hetzner.hcloud.yml \
  playbooks/site.yml --tags openbao

# 5. Bootstrap Primary OpenBao (will auto-unseal)
ansible-playbook -i inventory/hetzner.hcloud.yml \
  playbooks/openbao-bootstrap.yml \
  -e openbao_bootstrap_ack=true

# SAVE: Primary unseal keys (5, backup only) + WordPress rotation token

# 6. Setup WordPress DB rotation
ansible-playbook -i inventory/hetzner.hcloud.yml \
  playbooks/setup-openbao-rotation.yml
```

---

## What to Save

### Transit OpenBao (Port 8201)
- ✅ 5 unseal keys (password manager)
- ✅ Root token (password manager)
- ✅ Auto-unseal token (Ansible Vault)

### Primary OpenBao (Port 8200)
- ✅ 5 unseal keys (password manager, backup only)
- ✅ Root token (password manager)
- ✅ WordPress rotation token (Ansible Vault)

---

## After Server Reboot

```bash
# 1. SSH to server
ssh -i ~/.ssh/github_ed25519 malpanez@SERVER_IP

# 2. Unseal Transit (one-time, manual)
export VAULT_ADDR='https://127.0.0.1:8201'
export VAULT_SKIP_VERIFY=1
bao operator unseal  # Key 1
bao operator unseal  # Key 2
bao operator unseal  # Key 3

# 3. Primary auto-unseals automatically ✅
# (If not, restart it: sudo systemctl restart openbao)

# 4. Verify both unsealed
bao status  # Transit
export VAULT_ADDR='https://127.0.0.1:8200'
bao status  # Primary

# 5. Done! Rotation will work normally ✅
```

---

## Monitoring

```bash
# Check seal status
/usr/local/bin/check-openbao-sealed.sh

# View timer
systemctl list-timers openbao-seal-check.timer

# View logs
journalctl -u openbao-seal-check.service -f

# View alerts
journalctl -t openbao-alert -p crit
```

---

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Primary sealed after reboot | Unseal Transit first |
| Rotation failing | Check Primary seal status |
| CI/CD tests failing | Expected - tests deployment only |
| WordPress down | Check rotation logs |

---

## Deployment Order Summary

```
site.yml
  ↓
openbao-transit-bootstrap.yml → Save transit keys + token
  ↓
Add token to vault
  ↓
site.yml --tags openbao
  ↓
openbao-bootstrap.yml → Save primary keys
  ↓
setup-openbao-rotation.yml
  ↓
✅ Production Ready
```

---

**See Also**: [OpenBao Auto-Unseal Guide](./OPENBAO_AUTO_UNSEAL_GUIDE.md) for detailed information
