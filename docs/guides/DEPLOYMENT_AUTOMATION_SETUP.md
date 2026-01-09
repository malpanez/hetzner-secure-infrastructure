# Deployment Automation Setup Guide

**Date**: 2026-01-09
**Purpose**: Configure secure automated deployments with 2FA
**Security Level**: Production-ready

---

## Table of Contents

1. [User Strategy for Automation](#user-strategy-for-automation)
2. [OpenBao Secret Rotation](#openbao-secret-rotation)
3. [Cloudflare + GoDaddy DNS Setup](#cloudflare--godaddy-dns-setup)
4. [WordPress Plugin Security](#wordpress-plugin-security)
5. [Production Deployment Checklist](#production-deployment-checklist)

---

## User Strategy for Automation

### The Challenge

You have SSH 2FA enabled for security, which blocks automated deployments. We need a solution that:

- ✅ Keeps 2FA enabled for human access (your account)
- ✅ Allows automation to run without human interaction
- ✅ Maintains security best practices

### Recommended Solution: Dedicated Ansible User

**Create a separate `ansible` user with key-based authentication:**

```bash
# On your local machine (where you run Ansible)
ssh-keygen -t ed25519 -C "ansible-automation" -f ~/.ssh/ansible_automation
```

#### On Each Server (via your 2FA account)

```bash
# 1. Create ansible user
sudo useradd -m -s /bin/bash ansible
sudo usermod -aG sudo ansible

# 2. Configure passwordless sudo for automation
sudo visudo -f /etc/sudoers.d/ansible
```

Add this content:

```
# Ansible automation user
ansible ALL=(ALL) NOPASSWD: ALL

# Restrict to specific commands if you want tighter security
# ansible ALL=(ALL) NOPASSWD: /usr/bin/apt, /usr/bin/systemctl, /usr/bin/cp
```

```bash
# 3. Setup SSH key for ansible user
sudo mkdir -p /home/ansible/.ssh
sudo chmod 700 /home/ansible/.ssh

# Copy your ansible public key
echo "YOUR_PUBLIC_KEY_HERE" | sudo tee /home/ansible/.ssh/authorized_keys
sudo chmod 600 /home/ansible/.ssh/authorized_keys
sudo chown -R ansible:ansible /home/ansible/.ssh

# 4. IMPORTANT: Exclude ansible user from 2FA requirement
sudo vim /etc/ssh/sshd_config.d/2fa.conf
```

Update the 2FA config:

```
# Enable 2FA for all users EXCEPT ansible
Match User *,!ansible
    AuthenticationMethods publickey,keyboard-interactive
```

```bash
# 5. Restart SSH
sudo systemctl restart sshd

# 6. Test ansible user access (from your local machine)
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP
```

#### Update Ansible Inventory

```yaml
# ansible/inventory/hetzner.hcloud.yml
plugin: hcloud
token: "{{ lookup('env', 'HCLOUD_TOKEN') }}"

groups:
  production: "'prod' in name"
  staging: "'stag' in name"

compose:
  ansible_user: ansible  # Use ansible user instead of malpanez
  ansible_ssh_private_key_file: ~/.ssh/ansible_automation
  ansible_python_interpreter: /usr/bin/python3
```

### Alternative: Break-Glass SSH Key for Your User

If you prefer to keep using your `malpanez` user:

```bash
# On server: Add break-glass SSH key
echo "YOUR_AUTOMATION_KEY" >> ~/.ssh/authorized_keys

# Update SSH config to allow both 2FA and key-only for specific key
# This is LESS secure but more convenient
```

**Security Trade-off**: This weakens 2FA for your account. **Not recommended for production.**

---

## OpenBao Secret Rotation

### Current State

OpenBao is installed but **not configured for automatic secret rotation**.

### Manual Secret Rotation (Current Process)

```bash
# 1. SSH to server
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# 2. Login to OpenBao
bao login -method=userpass username=admin

# 3. Update a secret
bao kv put secret/wordpress/db password="NEW_PASSWORD_HERE"

# 4. Update service with new password
sudo mysql -e "ALTER USER 'wordpress'@'localhost' IDENTIFIED BY 'NEW_PASSWORD_HERE';"

# 5. Update WordPress config
sudo -u www-data wp --path=/var/www/wordpress config set DB_PASSWORD 'NEW_PASSWORD_HERE'

# 6. Restart services
sudo systemctl restart php8.4-fpm nginx
```

### Automatic Rotation Setup (Recommended)

**Step 1: Enable OpenBao Database Secret Engine**

```bash
# Login to OpenBao
bao login -method=userpass username=admin

# Enable database secret engine
bao secrets enable database

# Configure MariaDB connection
bao write database/config/mariadb \
    plugin_name=mysql-database-plugin \
    connection_url="{{username}}:{{password}}@tcp(127.0.0.1:3306)/" \
    allowed_roles="wordpress-role" \
    username="openbao" \
    password="ybAxmkmVYpKqxt1Yzw60SOEK6kvMmfaU"

# Create role with automatic rotation
bao write database/roles/wordpress-role \
    db_name=mariadb \
    creation_statements="CREATE USER '{{name}}'@'localhost' IDENTIFIED BY '{{password}}'; GRANT ALL ON wordpress.* TO '{{name}}'@'localhost';" \
    default_ttl="24h" \
    max_ttl="720h"
```

**Step 2: Configure WordPress to Read from OpenBao**

This requires custom WordPress plugin or systemd service to fetch credentials:

```bash
# Create systemd timer to rotate secrets daily
sudo vim /etc/systemd/system/wordpress-secret-rotate.service
```

```ini
[Unit]
Description=Rotate WordPress Database Credentials
After=network.target openbao.service mariadb.service

[Service]
Type=oneshot
User=www-data
ExecStart=/usr/local/bin/rotate-wordpress-secrets.sh
```

```bash
sudo vim /etc/systemd/system/wordpress-secret-rotate.timer
```

```ini
[Unit]
Description=Rotate WordPress secrets daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
```

**Step 3: Create Rotation Script**

```bash
sudo vim /usr/local/bin/rotate-wordpress-secrets.sh
sudo chmod +x /usr/local/bin/rotate-wordpress-secrets.sh
```

```bash
#!/bin/bash
set -euo pipefail

# Fetch new credentials from OpenBao
CREDS=$(bao read -format=json database/creds/wordpress-role)
NEW_USER=$(echo "$CREDS" | jq -r '.data.username')
NEW_PASS=$(echo "$CREDS" | jq -r '.data.password')

# Update wp-config.php
wp --path=/var/www/wordpress config set DB_USER "$NEW_USER" --type=constant
wp --path=/var/www/wordpress config set DB_PASSWORD "$NEW_PASS" --type=constant

# Restart PHP-FPM
systemctl restart php8.4-fpm

# Log rotation
logger "WordPress database credentials rotated: $NEW_USER"
```

**Step 4: Enable Timer**

```bash
sudo systemctl enable --now wordpress-secret-rotate.timer
sudo systemctl list-timers  # Verify it's scheduled
```

### Rotation Schedule

| Secret | Current TTL | Rotation Method | Frequency |
|--------|-------------|-----------------|-----------|
| **WordPress DB** | Manual | OpenBao auto-rotation | 24 hours |
| **MariaDB Root** | Manual | Manual (high-privilege) | 90 days |
| **Grafana Admin** | Manual | Manual | 90 days |
| **SSH Keys** | Never | Manual | Annually |

### Ansible Vault Rotation

```bash
# On your local machine
cd /home/malpanez/repos/hetzner-secure-infrastructure/ansible

# 1. Backup current vault
cp inventory/group_vars/all/secrets.yml inventory/group_vars/all/secrets.yml.backup

# 2. Edit vault with new passwords
ansible-vault edit inventory/group_vars/all/secrets.yml

# 3. Change vault password (optional)
ansible-vault rekey inventory/group_vars/all/secrets.yml

# 4. Update services
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml --tags passwords
```

---

## Cloudflare + GoDaddy DNS Setup

### Overview

**Current Setup**: Domain registered with GoDaddy
**Goal**: Use Cloudflare for DNS, CDN, SSL, and security
**Cost**: FREE (Cloudflare Free Plan)

### Benefits of Cloudflare

✅ **Free CDN** - Edge caching worldwide
✅ **Free SSL/TLS** - Automatic HTTPS
✅ **DDoS Protection** - 100+ Tbps network
✅ **Web Application Firewall (WAF)** - Basic protection on free plan
✅ **DNS Management** - Fast, secure DNS (1.1.1.1)
✅ **Analytics** - Traffic insights

⚠️ **Risks**:

- Single point of failure (as you noted, 2 outages in 2025)
- All traffic proxied through Cloudflare
- Limited control on free plan

### Step-by-Step Setup

#### 1. Create Cloudflare Account

1. Go to <https://dash.cloudflare.com/sign-up>
2. Sign up with your email
3. Verify email address

#### 2. Add Your Domain to Cloudflare

1. Click "Add a Site"
2. Enter your domain (e.g., `yourdomain.com`)
3. Select **Free Plan** (€0/month)
4. Click "Continue"

#### 3. Cloudflare Scans Your DNS Records

Cloudflare will import existing DNS records from GoDaddy automatically.

**Review and add missing records:**

```
Type    Name    Content                 Proxy   TTL
────────────────────────────────────────────────────
A       @       46.224.156.140          ✅      Auto
A       www     46.224.156.140          ✅      Auto
AAAA    @       2a01:4f8:xxxx:xxxx::    ✅      Auto (if IPv6)
MX      @       mail.yourdomain.com     ❌      Auto
TXT     @       v=spf1 ...              ❌      Auto
```

**Important**:

- ✅ Orange cloud (Proxied) = Traffic goes through Cloudflare CDN
- ❌ Grey cloud (DNS only) = Direct to your server (use for mail, SSH)

#### 4. Update Nameservers at GoDaddy

Cloudflare will provide you with **2 nameservers**:

```
alexa.ns.cloudflare.com
phil.ns.cloudflare.com
```

**On GoDaddy:**

1. Login to <https://account.godaddy.com>
2. Go to **My Products** → **Domains**
3. Click on your domain → **Manage DNS**
4. Scroll to **Nameservers** section
5. Click **Change**
6. Select **Custom Nameservers**
7. Remove GoDaddy nameservers
8. Add Cloudflare nameservers:

   ```
   alexa.ns.cloudflare.com
   phil.ns.cloudflare.com
   ```

9. Click **Save**

**⏱️ Propagation Time**: 24-48 hours (usually < 2 hours)

#### 5. Verify DNS Propagation

```bash
# Check nameservers
dig NS yourdomain.com +short

# Should show:
# alexa.ns.cloudflare.com
# phil.ns.cloudflare.com

# Check A record
dig A yourdomain.com +short
# Should show your server IP: 46.224.156.140
```

#### 6. Configure Cloudflare Settings

##### SSL/TLS Settings

1. Go to **SSL/TLS** tab
2. Set encryption mode: **Full (strict)**
   - ⚠️ Requires valid SSL cert on your server (Nginx has Let's Encrypt)
3. Enable **Always Use HTTPS**
4. Enable **Automatic HTTPS Rewrites**

##### Security Settings

1. Go to **Security** → **WAF**
2. Create rule: **WordPress Protection**

   ```
   Field: URI Path
   Operator: contains
   Value: /wp-admin
   Action: Challenge (CAPTCHA for non-trusted IPs)
   ```

3. Go to **Security** → **Bots**
4. Enable **Bot Fight Mode** (free plan)

##### Performance Settings

1. Go to **Speed** → **Optimization**
2. Enable:
   - ✅ Auto Minify (HTML, CSS, JS)
   - ✅ Brotli compression
   - ✅ Early Hints
   - ✅ Rocket Loader (optional, test first)

##### Caching Rules

1. Go to **Caching** → **Configuration**
2. Set caching level: **Standard**
3. Browser Cache TTL: **4 hours** (for WordPress)
4. Create Page Rule:

   ```
   URL: yourdomain.com/wp-admin/*
   Settings:
     - Cache Level: Bypass
     - Disable Performance
   ```

#### 7. Update WordPress Configuration

```bash
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# Install Cloudflare plugin
sudo -u www-data wp plugin install cloudflare --activate --path=/var/www/wordpress

# Configure to restore visitor IP
sudo -u www-data wp config set CLOUDFLARE_API_KEY 'your_cf_api_key' --path=/var/www/wordpress
```

**Update Nginx to trust Cloudflare IPs:**

```bash
sudo vim /etc/nginx/conf.d/cloudflare-real-ip.conf
```

```nginx
# Cloudflare IP ranges (update periodically)
# https://www.cloudflare.com/ips/

set_real_ip_from 173.245.48.0/20;
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 131.0.72.0/22;

# IPv6
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;

real_ip_header CF-Connecting-IP;
real_ip_recursive on;
```

```bash
sudo nginx -t
sudo systemctl reload nginx
```

#### 8. Test Your Setup

```bash
# Test site loads
curl -I https://yourdomain.com

# Should see Cloudflare headers:
# cf-ray: xxxxx
# cf-cache-status: HIT/MISS

# Test WordPress admin
curl -I https://yourdomain.com/wp-admin/

# Test performance
curl -o /dev/null -s -w "Time: %{time_total}s\n" https://yourdomain.com
```

### Cloudflare Terraform Configuration

We already have Cloudflare configured in Terraform:

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Check current Cloudflare config
cat modules/cloudflare-config/zone-settings.tf
```

To apply Cloudflare settings via Terraform:

```bash
# Set Cloudflare API token
export CLOUDFLARE_API_TOKEN="your_token_here"

# Plan changes
terraform plan -target=module.cloudflare

# Apply
terraform apply -target=module.cloudflare
```

### Monitoring Cloudflare

**Free Analytics Dashboard:**

- <https://dash.cloudflare.com> → Analytics
- Traffic overview
- Cache hit rate
- Threats blocked
- Performance metrics

**Set up Email Alerts:**

1. Go to **Notifications**
2. Enable:
   - ✅ SSL/TLS certificate expiration
   - ✅ DDoS attack detection
   - ✅ Zone configuration changes

---

## WordPress Plugin Security

### Current Plugin List

From your Ansible configuration:

```yaml
wordpress_plugins:
  # LMS Platform
  - name: learndash
    source: premium  # Requires license
    version: latest

  # Security
  - name: wordfence
    source: wordpress.org
    state: present

  # Performance
  - name: wp-rocket
    source: premium  # Requires license
    version: latest

  # Cloudflare
  - name: cloudflare
    source: wordpress.org
    state: present
```

### LearnDash Security Configuration

**LearnDash** is your critical plugin (LMS platform). Security considerations:

```bash
# After purchasing LearnDash license from learndash.com
# Upload plugin manually or via WP-CLI

sudo -u www-data wp plugin install /path/to/learndash.zip --activate --path=/var/www/wordpress

# Activate license
sudo -u www-data wp learndash license activate LICENSE_KEY --path=/var/www/wordpress
```

**LearnDash Security Settings:**

1. **Restrict course access**:

   ```php
   // In wp-config.php
   define('LEARNDASH_COURSE_PROTECTION', true);
   ```

2. **Disable REST API for courses** (prevent scraping):

   ```bash
   sudo -u www-data wp plugin install disable-json-api --activate
   ```

3. **Protect video content** (if using videos):
   - Use signed URLs
   - Cloudflare Stream (paid) or Vimeo/YouTube private
   - Disable right-click on course pages

### Wordfence Configuration

**Wordfence** provides firewall and malware scanning:

```bash
# Install and activate
sudo -u www-data wp plugin install wordfence --activate --path=/var/www/wordpress

# Configure via WP-CLI
sudo -u www-data wp wordfence enable-firewall --path=/var/www/wordpress
sudo -u www-data wp wordfence set-learning-mode off --path=/var/www/wordpress
```

**Recommended Settings:**

1. **Firewall → Protection Level**: Extended Protection
2. **Scan → Schedule**: Daily at 3 AM
3. **Login Security**:
   - ✅ Enable 2FA for all users
   - ✅ Limit login attempts (5 tries, 20 min lockout)
   - ✅ Block admin username
   - ✅ Disable XML-RPC (unless needed)

4. **Rate Limiting**:

   ```
   Human verification: 5 min for 100+ page views
   Crawler verification: Block aggressive crawlers
   ```

### Security Headers (Nginx)

Already configured in your Nginx role, but verify:

```nginx
# /etc/nginx/snippets/security-headers.conf
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;

# Content Security Policy for WordPress
add_header Content-Security-Policy "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://www.google.com https://www.gstatic.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; frame-src 'self' https://www.youtube.com https://player.vimeo.com;" always;
```

### Plugin Update Strategy

**Critical Security Rule**: Update plugins weekly

```bash
# Automate with cron (runs as www-data)
sudo crontab -e -u www-data
```

Add:

```cron
# Update WordPress core, plugins, themes weekly
0 3 * * 0 /usr/bin/wp --path=/var/www/wordpress core update && /usr/bin/wp --path=/var/www/wordpress plugin update --all && /usr/bin/wp --path=/var/www/wordpress theme update --all
```

**Before updating production:**

1. Test updates on staging server first
2. Backup database and files
3. Check plugin changelogs for breaking changes

### Recommended Additional Plugins

```yaml
# Add to ansible/roles/nginx_wordpress/defaults/main.yml
wordpress_plugins:
  # ... existing plugins ...

  # Security hardening
  - name: wp-force-ssl
    source: wordpress.org
    state: present

  # Backup (important!)
  - name: updraftplus
    source: wordpress.org
    state: present

  # Anti-spam (if you have forms)
  - name: akismet
    source: wordpress.org
    state: present

  # Database optimization
  - name: wp-optimize
    source: wordpress.org
    state: present
```

---

## Production Deployment Checklist

Before going live with your trading course site:

### Pre-Deployment

- [ ] Purchase LearnDash license
- [ ] Purchase domain (or confirm GoDaddy ownership)
- [ ] Create Cloudflare account
- [ ] Setup Ansible automation user on server
- [ ] Configure Ansible vault with production secrets
- [ ] Test Ansible playbook on staging server

### DNS & SSL

- [ ] Update GoDaddy nameservers to Cloudflare
- [ ] Verify DNS propagation (24-48h)
- [ ] Configure Cloudflare SSL/TLS (Full Strict mode)
- [ ] Test HTTPS works (<https://yourdomain.com>)
- [ ] Setup Cloudflare page rules for WordPress
- [ ] Configure Nginx to trust Cloudflare IPs

### WordPress Setup

- [ ] Install WordPress via Ansible
- [ ] Change default admin username from "admin"
- [ ] Install and activate LearnDash with license
- [ ] Install Wordfence and configure firewall
- [ ] Install Cloudflare plugin
- [ ] Configure permalinks (Settings → Permalinks → Post name)
- [ ] Disable XML-RPC (Security → Settings)
- [ ] Enable 2FA for all admin users
- [ ] Setup automated backups (UpdraftPlus to S3 or Backblaze)

### Security Hardening

- [ ] Verify SSH 2FA works for your user
- [ ] Test ansible user can deploy without 2FA
- [ ] Configure Fail2ban alerts to your email
- [ ] Setup UFW firewall rules (ports 22, 80, 443 only)
- [ ] Enable Wordfence email alerts
- [ ] Configure Grafana alerting rules
- [ ] Test server monitoring dashboards
- [ ] Verify OpenBao is running and secured

### Content & SEO

- [ ] Create sample course with LearnDash
- [ ] Test course enrollment and access
- [ ] Install SEO plugin (Yoast SEO or Rank Math)
- [ ] Configure XML sitemap
- [ ] Submit sitemap to Google Search Console
- [ ] Setup Google Analytics (or privacy-focused alternative)
- [ ] Create privacy policy and terms of service pages
- [ ] Configure GDPR cookie consent (if EU traffic)

### Performance

- [ ] Run Lighthouse audit (target: 90+ performance score)
- [ ] Enable Cloudflare caching
- [ ] Configure WP Rocket (if using)
- [ ] Optimize images (use WebP format)
- [ ] Test page load speed (< 2 seconds)
- [ ] Enable Brotli compression (Cloudflare)
- [ ] Setup CDN for static assets

### Monitoring & Backup

- [ ] Configure Grafana dashboards for WordPress
- [ ] Setup email alerts for system issues
- [ ] Test backup restoration process
- [ ] Schedule automated backups (daily)
- [ ] Document recovery procedures
- [ ] Test fail2ban is blocking brute force
- [ ] Verify Prometheus is collecting metrics

### Legal & Compliance

- [ ] Add GDPR cookie notice (if applicable)
- [ ] Create privacy policy (include LearnDash data collection)
- [ ] Create terms of service
- [ ] Setup payment processor (Stripe/PayPal) for courses
- [ ] Configure tax collection (if selling courses)

### Go-Live

- [ ] Update production DNS to point to server
- [ ] Test all critical user flows (registration, login, course access)
- [ ] Monitor error logs for 24 hours
- [ ] Check Cloudflare analytics
- [ ] Verify SSL certificate is valid
- [ ] Test contact forms work
- [ ] Announce launch!

### Post-Launch (Week 1)

- [ ] Monitor server load and performance
- [ ] Review Wordfence scan results
- [ ] Check Grafana for anomalies
- [ ] Verify backups are running
- [ ] Test disaster recovery (restore from backup)
- [ ] Review Cloudflare security reports
- [ ] Optimize based on real traffic patterns

---

## Security Best Practices Summary

### Defense in Depth

You have multiple security layers:

1. **Network**: Cloudflare DDoS protection + WAF
2. **Firewall**: UFW (ports 22, 80, 443 only)
3. **SSH**: 2FA + key-based auth + Fail2ban
4. **Application**: Wordfence firewall + security headers
5. **Database**: MariaDB localhost-only + strong passwords
6. **Secrets**: OpenBao + Ansible Vault encryption
7. **Monitoring**: Prometheus + Grafana + Loki logging
8. **Backups**: Automated daily backups + tested restoration

### Weakest Links

Be aware of:

1. **Human error** - Use checklists, automation
2. **Plugin vulnerabilities** - Update weekly, use reputable plugins only
3. **Social engineering** - Strong passwords, 2FA everywhere
4. **Cloudflare dependency** - Have backup DNS plan
5. **WordPress core** - Auto-update minor versions, test major updates

### Incident Response Plan

If site is compromised:

1. **Immediately**:
   - Take site offline (Cloudflare "Under Attack" mode)
   - Block attacker IPs at UFW level
   - Review Fail2ban and Wordfence logs

2. **Investigation**:
   - Check Wordfence scan results
   - Review Nginx access logs
   - Check file integrity (WordPress files modified?)
   - Review user accounts (unauthorized admin?)

3. **Recovery**:
   - Restore from last known good backup
   - Change all passwords (WordPress, MariaDB, SSH)
   - Rotate Ansible vault secrets
   - Update all plugins and WordPress core
   - Review and patch vulnerability

4. **Prevention**:
   - Add attacker patterns to Fail2ban
   - Update Wordfence rules
   - Review and strengthen weak points
   - Document incident for future reference

---

## Next Steps

1. **This week**:
   - [ ] Create ansible automation user on server
   - [ ] Test automated deployment works
   - [ ] Setup Cloudflare account and migrate DNS
   - [ ] Purchase LearnDash license

2. **This month**:
   - [ ] Build out course content with AI assistance
   - [ ] Configure all WordPress plugins
   - [ ] Test backup and restore procedures
   - [ ] Run security audit

3. **Ongoing**:
   - [ ] Weekly plugin updates
   - [ ] Monthly security reviews
   - [ ] Quarterly disaster recovery drills
   - [ ] Monitor performance and optimize

---

**Questions?** Open an issue or check the documentation:

- SSH 2FA: [docs/security/SSH_2FA_BREAK_GLASS.md](../security/SSH_2FA_BREAK_GLASS.md)
- Nginx Security: [docs/guides/NGINX_CONFIGURATION_EXPLAINED.md](NGINX_CONFIGURATION_EXPLAINED.md)
- Deployment: [docs/guides/DEPLOYMENT.md](DEPLOYMENT.md)
