# Deployment Guide - Two Minds Trading

## Pre-Deployment Checklist

- [ ] Review all variables in `ansible/inventory/group_vars/all/common.yml`
- [ ] Set Hetzner API token: `export HCLOUD_TOKEN="your-token"`
- [ ] Set Cloudflare API token: `vault_cloudflare_api_token` in secrets.yml
- [ ] Set `domain_name` in `ansible/inventory/group_vars/all/common.yml`
- [ ] Ensure Yubikey is connected
- [ ] Backup any existing SSH keys

## Deployment Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    DEPLOYMENT PROCESS                           │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  STEP 1: Terraform (infrastructure)                             │
│  ─────────────────────────────────                              │
│  cd terraform && terraform apply                                │
│                                                                 │
│  STEP 2: OpenBao Transit Bootstrap (ONE TIME ONLY)              │
│  ─────────────────────────────────────────────────              │
│  cd ansible                                                     │
│  ansible-playbook playbooks/openbao.yml                         │
│  ansible-playbook playbooks/openbao-transit-bootstrap.yml \     │
│    -e openbao_transit_bootstrap_ack=true                        │
│                                                                 │
│  ⚠️  MANUAL STEP: Save credentials and update vault             │
│  ────────────────────────────────────────────────               │
│  1. Save Transit Unseal Keys → password manager                 │
│  2. Copy Auto-Unseal Token                                      │
│  3. ansible-vault edit inventory/group_vars/all/secrets.yml     │
│     Add: vault_openbao_transit_token: "s.xxxxx"                 │
│                                                                 │
│  STEP 3: Full Stack Deployment                                  │
│  ─────────────────────────────                                  │
│  ansible-playbook playbooks/site.yml                            │
│  (or: make deploy)                                              │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

## Initial Deployment (First Time)

```bash
cd hetzner-secure-infrastructure

# 1. Initialize terraform and ansible
make init

# 2. Create infrastructure
cd terraform && terraform apply && cd ..

# 3. Bootstrap OpenBao Transit (generates unseal keys)
cd ansible
ansible-playbook playbooks/openbao.yml
ansible-playbook playbooks/openbao-transit-bootstrap.yml \
  -e openbao_transit_bootstrap_ack=true

# 4. STOP HERE - Save the credentials shown:
#    - Transit Unseal Keys → save to password manager
#    - Auto-Unseal Token → add to Ansible Vault:
ansible-vault edit inventory/group_vars/all/secrets.yml
# Add: vault_openbao_transit_token: "s.xxxxx"

# 5. Deploy full stack (now with auto-unseal configured)
ansible-playbook playbooks/site.yml
```

## Subsequent Deployments

Once OpenBao Transit is bootstrapped and the token is in the vault:

```bash
# Just run site.yml - everything is automatic
ansible-playbook playbooks/site.yml

# Or with make
make deploy
```

## Post-Deployment

1. SSH to server: `ssh prod-de-wp-01`
2. Setup 2FA: `sudo /usr/local/bin/setup-2fa-yubikey.sh malpanez`
3. Add to Yubikey: `ykman oath accounts add 'hetzner-malpanez' SECRET`
4. Test: `hssh prod-de-wp-01` (from WSL2)

## Security Hardening (After Testing)

Once everything works:

```bash
# Edit security settings
# 1. Set apparmor_enforce_mode: true
# 2. Set audit_immutable_mode: "2"

# Re-deploy with hardened settings
make deploy
```

## Rollback

If server becomes locked:
```bash
ansible-playbook playbooks/common.yml --tags security -e security_rollback=true
```

## WordPress Access

- Main site: `https://yourdomain.com`
- Admin: `https://yourdomain.com/wp-admin`
- Grafana: `https://grafana.yourdomain.com`
- Prometheus: `https://prometheus.yourdomain.com`

## Notes

- `/tmp` is tmpfs with 4GB limit
- UMASK set to 022 (web-compatible)
- Cloudflare challenge disabled for wp-admin (Pi-hole compatible)
- WordPress 2FA via WP 2FA plugin
