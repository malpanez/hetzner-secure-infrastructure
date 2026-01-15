# Deployment Guide - Two Minds Trading

## Pre-Deployment Checklist

- [ ] Review all variables in `ansible/inventory/group_vars/all/common.yml` and `ansible/inventory/group_vars/hetzner/`
- [ ] Set Hetzner API token: `export HCLOUD_TOKEN="your-token"`
- [ ] Ensure Yubikey is connected
- [ ] Backup any existing SSH keys

## Global Configuration

**Timezone:** UTC (for global business operations)
**Locales:** Multi-language (EN, ES, PT, DE, FR)
**NTP:** Global anycast servers (Cloudflare, Google)

## Initial Deployment
```bash
cd hetzner-secure-infrastructure

# Initialize
make init

# Deploy (AppArmor in complain mode, audit mutable)
make deploy

# After successful deployment and testing:
# 1. Set apparmor_enforce_mode: true
# 2. Set audit_immutable_mode: "2"
# 3. Re-run: make deploy
```

## Post-Deployment

1. SSH to server: `ssh miguel@SERVER_IP`
2. Setup 2FA: `sudo /usr/local/bin/setup-2fa-yubikey.sh miguel`
3. Add to Yubikey: `ykman oath accounts add 'hetzner-miguel' SECRET`
4. Test: `hssh SERVER_IP` (from WSL2)

## Rollback

If server becomes locked:
```bash
ansible-playbook -i inventory/hosts rollback-security.yml
```

## WordPress Considerations

- `/tmp` is tmpfs with 4GB limit
- UMASK set to 022 (web-compatible)
- PHP monitoring includes all versions
- Unattended upgrades conservative by default
