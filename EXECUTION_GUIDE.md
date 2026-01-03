# Execution Guide - Ready to Deploy

**Date**: 2026-01-02
**Purpose**: Answer all final questions before production deployment

---

## Your Questions - Answered

### Q1: "Do I need to change Ansible to use the ansible user?"

**Answer**: ✅ YES - Already done!

I've updated [ansible/inventory/hetzner.hcloud.yml](ansible/inventory/hetzner.hcloud.yml):

```yaml
compose:
  ansible_user: ansible  # Changed from 'malpanez'
  ansible_ssh_private_key_file: ~/.ssh/ansible_automation  # Changed from github_ed25519
```

**What this means**:
- All future Ansible runs will use the `ansible` user (no 2FA prompts)
- Your `malpanez` account still exists with 2FA for manual SSH access
- Both users work simultaneously

**To override** (use your 2FA account):
```bash
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
  -u malpanez \
  --private-key ~/.ssh/github_ed25519
```

### Q2: "How do I capture the 2FA QR code for my phone?"

**Answer**: Full guide created!

See: [docs/security/SSH_2FA_INITIAL_SETUP.md](docs/security/SSH_2FA_INITIAL_SETUP.md)

**Quick version**:

```bash
# 1. SSH to server (before or after 2FA is enabled)
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# 2. Run Google Authenticator setup
google-authenticator

# 3. Answer the prompts (YES to all except "increase window" = NO)

# 4. QR code displays in terminal - scan with Google Authenticator app

# 5. Save emergency scratch codes in password manager
```

**If you lose the QR code**:
- Use emergency scratch codes to login
- Or use `ansible` user to regain access (no 2FA)
- Regenerate with: `google-authenticator`

### Q3: "Can you review and cleanup all documentation?"

**Answer**: ✅ Cleanup script ready!

Run this to organize everything:

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure
./scripts/cleanup-documentation.sh
```

**What it does**:
- Moves root-level `.md` files to proper `docs/` folders
- Archives outdated documentation
- Removes duplicates
- Creates `docs/INDEX.md` for easy navigation
- Keeps only essential files in root (README, CHANGELOG, etc.)

**After cleanup**, root will only have:
- `README.md` - Main project overview
- `CHANGELOG.md` - Version history
- `CONTRIBUTING.md` - How to contribute
- `SECURITY.md` - Security policy
- `GO_LIVE_TODAY_CHECKLIST.md` - Quick deployment guide
- `VAULT_SETUP_INSTRUCTIONS.md` - Vault setup
- `EXECUTION_GUIDE.md` - This file!

All other docs organized in `docs/`:
- `docs/guides/` - How-to guides
- `docs/security/` - Security documentation
- `docs/infrastructure/` - Architecture docs
- `docs/performance/` - Benchmarks

---

## Execution Order - Do This Now

### Step 1: Cleanup Documentation (2 min)

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure
./scripts/cleanup-documentation.sh
```

### Step 2: Review Documentation Index (1 min)

```bash
cat docs/INDEX.md
# Or open in VS Code
```

### Step 3: Run Production Setup (15 min)

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure
./scripts/production-setup-today.sh
```

This will:
1. Generate `ansible` user SSH key
2. Deploy `ansible` user to server (with hardening)
3. Test connection
4. Setup OpenBao rotation
5. Show Cloudflare DNS migration steps

### Step 4: Capture Your 2FA QR Code (5 min)

```bash
# SSH to server with your account
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# Run authenticator setup
google-authenticator

# Scan QR code with phone (Google Authenticator app)
# Save emergency codes in password manager
```

### Step 5: Complete OpenBao Setup (5 min)

Follow the commands from the playbook output:

```bash
# Still SSH'd to server
bao login -method=userpass username=admin
# Password: tGUL57rBq85GQsDnHbtoRbonobe5Ld7H

echo $OPENBAO_TOKEN > /root/.openbao-token
chmod 600 /root/.openbao-token

bao secrets enable database

bao write database/config/mariadb \
  plugin_name=mysql-database-plugin \
  connection_url='{{username}}:{{password}}@tcp(127.0.0.1:3306)/' \
  allowed_roles='wordpress-role' \
  username='openbao' \
  password='ybAxmkmVYpKqxt1Yzw60SOEK6kvMmfaU'

bao write database/roles/wordpress-role \
  db_name=mariadb \
  creation_statements="CREATE USER '{{name}}'@'localhost' IDENTIFIED BY '{{password}}'; GRANT ALL ON wordpress.* TO '{{name}}'@'localhost';" \
  default_ttl='24h' \
  max_ttl='720h'

# Test rotation
sudo /usr/local/bin/rotate-wordpress-secrets.sh
```

### Step 6: Migrate to Cloudflare (15 min + 24h propagation)

1. **Create Cloudflare account**: https://dash.cloudflare.com/sign-up
2. **Add your domain** → Free plan
3. **Get nameservers** (example):
   ```
   alexa.ns.cloudflare.com
   phil.ns.cloudflare.com
   ```
4. **Update GoDaddy**:
   - Login: https://account.godaddy.com
   - My Products → Domains → Your Domain → Manage DNS
   - Nameservers → Change → Custom
   - Add Cloudflare nameservers
   - Save

5. **Add DNS records in Cloudflare**:
   ```
   Type    Name    Content         Proxy
   ─────────────────────────────────────
   A       @       YOUR_SERVER_IP  ✅
   A       www     YOUR_SERVER_IP  ✅
   ```

6. **Configure Cloudflare**:
   - SSL/TLS → Full (strict)
   - Always Use HTTPS → ON
   - Auto Minify → HTML, CSS, JS
   - Brotli → ON

### Step 7: Test Everything (10 min)

```bash
# Test ansible user (no 2FA)
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP
# Should login without 2FA prompt
exit

# Test your account (with 2FA)
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP
# Should prompt for verification code
# Enter 6-digit code from Google Authenticator
exit

# Test Ansible deployment (using ansible user)
cd /home/malpanez/repos/hetzner-secure-infrastructure/ansible
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml --check
# Should run without 2FA prompts

# Check OpenBao rotation timer
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP \
  "sudo systemctl list-timers wordpress-secret-rotate.timer"

# Check Grafana
# Visit: http://YOUR_SERVER_IP:3000
# Login: admin / QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl
```

---

## What You Have Now

### Security Layers (8 Total)

1. **Network Edge**: Cloudflare DDoS + WAF (after DNS migration)
2. **Cloud Firewall**: Hetzner Cloud Firewall (network-level filtering)
3. **Host Firewall**: UFW (ports 22, 80, 443 only)
4. **SSH**: 2FA for humans + key-only for automation
5. **Brute Force**: Fail2ban (3 attempts = 1h ban)
6. **Application**: Wordfence (to install after Cloudflare)
7. **Database**: OpenBao rotating credentials (daily)
8. **Secrets**: Ansible Vault (AES256 encrypted)

### Automation Users

| User | Purpose | 2FA | SSH Key | Access |
|------|---------|-----|---------|--------|
| **malpanez** | Your account | ✅ YES | `github_ed25519` | Full sudo |
| **ansible** | Automation | ❌ NO | `ansible_automation` | Limited sudo + logged |

### Services Running

| Service | Port | Access | Purpose |
|---------|------|--------|---------|
| Nginx | 80, 443 | Public | Web server |
| SSH | 22 | Public | Remote access |
| Grafana | 3000 | Public | Monitoring dashboard |
| Prometheus | 9090 | Localhost | Metrics collection |
| OpenBao | 8200 | Localhost | Secrets management |
| MariaDB | 3306 | Localhost | Database |
| PHP-FPM | Unix socket | Localhost | Application server |
| Valkey | 6379 | Localhost | Cache |

### Passwords Location

All passwords are in Ansible Vault:
```bash
ansible-vault view ansible/inventory/group_vars/all/secrets.yml
# Vault password: 8ZpBU0IW4pWNKuXm4b7hQxF5e/jmfspQYzrSSLhuXu8=
```

Also in: [VAULT_SETUP_INSTRUCTIONS.md](VAULT_SETUP_INSTRUCTIONS.md) (plaintext - delete after setup!)

---

## After DNS Propagates (24-48 hours)

### Install WordPress Plugins

```bash
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# Install Wordfence
sudo -u www-data wp plugin install wordfence --activate --path=/var/www/wordpress

# Install Cloudflare plugin
sudo -u www-data wp plugin install cloudflare --activate --path=/var/www/wordpress

# Install backup plugin
sudo -u www-data wp plugin install updraftplus --activate --path=/var/www/wordpress

# Upload LearnDash (manual - after purchasing license)
# Download from learndash.com
# Upload via WordPress admin or:
sudo -u www-data wp plugin install /path/to/learndash.zip --activate --path=/var/www/wordpress
```

### Configure Wordfence

```bash
# Enable firewall
sudo -u www-data wp wordfence enable-firewall --path=/var/www/wordpress

# Set protection level
sudo -u www-data wp wordfence set-learning-mode off --path=/var/www/wordpress

# Schedule daily scan
sudo -u www-data wp wordfence schedule-scan --path=/var/www/wordpress
```

### Test Site Loads via HTTPS

```bash
# Check DNS
dig yourdomain.com +short
# Should show Cloudflare IPs

# Test HTTPS
curl -I https://yourdomain.com
# Should show: 200 OK with Cloudflare headers

# Test WordPress admin
curl -I https://yourdomain.com/wp-admin/
# Should redirect to login page
```

---

## Useful Commands Reference

### Ansible Deployment (Using ansible User - No 2FA)

```bash
# Full deployment
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml ansible/playbooks/site.yml

# Dry run (check mode)
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml ansible/playbooks/site.yml --check

# Specific tags only
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml ansible/playbooks/site.yml --tags wordpress

# Override to use your account (with 2FA)
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml ansible/playbooks/site.yml \
  -u malpanez --private-key ~/.ssh/github_ed25519
```

### Manual SSH Access

```bash
# Your account (with 2FA)
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP
# Enter verification code from Google Authenticator

# Ansible user (no 2FA)
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP
# Direct login, no 2FA prompt
```

### Security Monitoring

```bash
# View ansible user activity
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP
sudo tail -50 /var/log/ansible-automation/sudo.log

# Check fail2ban bans
sudo fail2ban-client status sshd

# Check OpenBao rotation logs
sudo tail -50 /var/log/wordpress-secret-rotation.log

# View Grafana dashboards
# Visit: http://YOUR_SERVER_IP:3000
# Login: admin / QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl
```

### OpenBao Operations

```bash
# Login to OpenBao
bao login -method=userpass username=admin
# Password: tGUL57rBq85GQsDnHbtoRbonobe5Ld7H

# Generate new WordPress DB credentials manually
bao read database/creds/wordpress-role

# Check rotation timer
systemctl status wordpress-secret-rotate.timer
systemctl list-timers wordpress-secret-rotate.timer

# Manually trigger rotation
sudo /usr/local/bin/rotate-wordpress-secrets.sh
```

---

## Emergency Procedures

### Lost Phone (Can't Get 2FA Code)

**Option 1**: Use emergency scratch code
```bash
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP
# Enter scratch code instead of TOTP code
```

**Option 2**: Use ansible user
```bash
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP
sudo -u malpanez bash
google-authenticator  # Regenerate 2FA
```

### Locked Out (Fail2ban)

```bash
# Use ansible user to unban yourself
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP
sudo fail2ban-client set sshd unbanip YOUR_IP_ADDRESS
```

### OpenBao Rotation Failed

```bash
# Check logs
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP
sudo tail -100 /var/log/wordpress-secret-rotation.log

# Check OpenBao is running
sudo systemctl status openbao

# Restart if needed
sudo systemctl restart openbao

# Test manually
sudo /usr/local/bin/rotate-wordpress-secrets.sh
```

---

## Documentation Navigation

All documentation is now organized in `docs/`:

**Start here**:
- [docs/INDEX.md](docs/INDEX.md) - Complete documentation index

**Key guides**:
- [docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md](docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md) - **Main production guide**
- [docs/security/SSH_2FA_INITIAL_SETUP.md](docs/security/SSH_2FA_INITIAL_SETUP.md) - **2FA setup with QR code**
- [docs/performance/ARM64_vs_X86_COMPARISON.md](docs/performance/ARM64_vs_X86_COMPARISON.md) - **Performance benchmarks**

**Quick access** (in root):
- [GO_LIVE_TODAY_CHECKLIST.md](GO_LIVE_TODAY_CHECKLIST.md) - 30-minute deployment
- [VAULT_SETUP_INSTRUCTIONS.md](VAULT_SETUP_INSTRUCTIONS.md) - Ansible Vault setup

---

## Ready? Let's Go! 🚀

Execute in order:

```bash
# 1. Cleanup docs (2 min)
./scripts/cleanup-documentation.sh

# 2. Deploy automation (15 min)
./scripts/production-setup-today.sh

# 3. Setup your 2FA (5 min)
# SSH to server and run: google-authenticator

# 4. Complete OpenBao (5 min)
# Follow commands in script output

# 5. Migrate DNS to Cloudflare (15 min + 24h wait)
# Follow Cloudflare instructions

# 6. After DNS: Install plugins (5 min)
# Wordfence, Cloudflare, UpdraftPlus, LearnDash
```

**Total active time**: ~45 minutes
**Total wait time**: 24-48 hours (DNS propagation)

**Questions?** Check [docs/INDEX.md](docs/INDEX.md) or [GO_LIVE_TODAY_CHECKLIST.md](GO_LIVE_TODAY_CHECKLIST.md)

Good luck! 🎉
