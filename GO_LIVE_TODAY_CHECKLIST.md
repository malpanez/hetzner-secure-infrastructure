# Go Live Today - Production Checklist

**Date**: 2026-01-02
**Goal**: Deploy secure, automated WordPress LMS platform to production
**Server**: Hetzner ARM64 CAX11 (€4.05/month)

---

## Executive Summary

We're ready to deploy your production WordPress trading course platform today! Here's what you'll get:

✅ **Secure Infrastructure**:
- SSH with 2FA for human access
- Dedicated ansible user for automation (no 2FA bypass)
- All automation commands logged and monitored
- Fail2ban protection
- UFW firewall (ports 22, 80, 443 only)

✅ **Automatic Security**:
- OpenBao rotating WordPress DB credentials daily
- Automated security audits
- Real-time monitoring (Prometheus + Grafana)
- Cloudflare DDoS protection + CDN

✅ **Best Practices**:
- ARM64 architecture (2.68x faster than x86 for same price tier)
- Full monitoring stack
- Encrypted secrets (Ansible Vault)
- Defense in depth (7 security layers)

---

## Quick Start (30 minutes)

### Step 1: Run Automation Script (10 min)

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure
./scripts/production-setup-today.sh
```

This script will:
1. Generate SSH key for ansible user
2. Deploy ansible automation user to server
3. Setup OpenBao daily secret rotation
4. Test connections
5. Show Cloudflare migration steps

### Step 2: Complete OpenBao Setup (5 min)

After the script runs, SSH to your server and execute:

```bash
# SSH to server (still using your 2FA account)
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# Login to OpenBao
bao login -method=userpass username=admin
# Enter password: tGUL57rBq85GQsDnHbtoRbonobe5Ld7H

# Save token for rotation script
echo $OPENBAO_TOKEN > /root/.openbao-token
chmod 600 /root/.openbao-token

# Enable database secret engine
bao secrets enable database

# Configure MariaDB connection
bao write database/config/mariadb \
  plugin_name=mysql-database-plugin \
  connection_url='{{username}}:{{password}}@tcp(127.0.0.1:3306)/' \
  allowed_roles='wordpress-role' \
  username='openbao' \
  password='ybAxmkmVYpKqxt1Yzw60SOEK6kvMmfaU'

# Create rotation role
bao write database/roles/wordpress-role \
  db_name=mariadb \
  creation_statements="CREATE USER '{{name}}'@'localhost' IDENTIFIED BY '{{password}}'; GRANT ALL ON wordpress.* TO '{{name}}'@'localhost';" \
  default_ttl='24h' \
  max_ttl='720h'

# Test rotation manually
sudo /usr/local/bin/rotate-wordpress-secrets.sh

# Check it worked
sudo -u www-data wp --path=/var/www/wordpress db check
```

### Step 3: Migrate to Cloudflare (15 min)

1. **Create Cloudflare Account**: https://dash.cloudflare.com/sign-up
2. **Add Domain**: Click "Add a Site" → Enter your domain → Select Free Plan
3. **Get Nameservers**: Cloudflare will show two nameservers:
   ```
   alexa.ns.cloudflare.com
   phil.ns.cloudflare.com
   ```

4. **Update GoDaddy**:
   - Login to https://account.godaddy.com
   - My Products → Domains → Your Domain → Manage DNS
   - Nameservers → Change → Custom Nameservers
   - Replace with Cloudflare nameservers
   - Save

5. **Configure DNS in Cloudflare**:
   ```
   Type    Name    Content           Proxy Status
   ────────────────────────────────────────────────
   A       @       YOUR_SERVER_IP    ✅ Proxied
   A       www     YOUR_SERVER_IP    ✅ Proxied
   ```

6. **Configure Cloudflare Settings**:
   - SSL/TLS → Full (strict)
   - Enable "Always Use HTTPS"
   - Speed → Auto Minify (HTML, CSS, JS)
   - Speed → Brotli compression

---

## What Gets Deployed

### Infrastructure

| Component | Status | Security |
|-----------|--------|----------|
| Nginx | ✅ Installed | TLS 1.3, security headers |
| PHP 8.4-FPM | ✅ Installed | Hardened config |
| MariaDB 11.4 | ✅ Installed | Localhost only, rotating creds |
| WordPress Latest | ✅ Installed | Admin user, 2FA ready |
| Valkey 8.0 | ✅ Installed | Object caching |

### Monitoring

| Component | URL | Purpose |
|-----------|-----|---------|
| Grafana | http://YOUR_IP:3000 | Dashboards |
| Prometheus | http://YOUR_IP:9090 | Metrics |
| OpenBao | http://127.0.0.1:8200 | Secret management |

**Grafana Credentials**:
- Username: `admin`
- Password: `QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl`

### Security (8 Layers)

| Layer | Protection | Status |
|-------|-----------|--------|
| **Network Edge** | Cloudflare DDoS + WAF | ⏳ After DNS migration |
| **Cloud Firewall** | Hetzner Cloud Firewall | ✅ Active |
| **Host Firewall** | UFW (22, 80, 443 only) | ✅ Active |
| **SSH** | 2FA + key-based auth | ✅ Active |
| **Brute Force** | Fail2ban | ✅ Active |
| **Application** | Wordfence (to install) | ⏳ After Cloudflare |
| **Database** | Rotating credentials | ✅ After OpenBao setup |
| **Secrets** | Ansible Vault (AES256) | ✅ Active |

---

## Post-Deployment Tasks

### Immediate (Today)

- [ ] Execute `./scripts/production-setup-today.sh`
- [ ] Complete OpenBao database engine setup
- [ ] Migrate DNS to Cloudflare
- [ ] Wait for DNS propagation (2-24 hours)
- [ ] Test site loads via HTTPS

### This Week

- [ ] Purchase LearnDash license
- [ ] Install WordPress plugins:
  ```bash
  # After DNS is migrated and Cloudflare is active
  sudo -u www-data wp plugin install wordfence --activate --path=/var/www/wordpress
  sudo -u www-data wp plugin install cloudflare --activate --path=/var/www/wordpress
  sudo -u www-data wp plugin install updraftplus --activate --path=/var/www/wordpress
  ```
- [ ] Upload LearnDash plugin manually
- [ ] Configure Wordfence firewall
- [ ] Setup automated backups (UpdraftPlus → S3/Backblaze)
- [ ] Create privacy policy and terms pages

### Content Creation (This Month)

- [ ] Design homepage with AI assistance
- [ ] Create first trading course with LearnDash
- [ ] Setup course enrollment flow
- [ ] Configure payment gateway (Stripe/PayPal)
- [ ] Create sample lessons and quizzes
- [ ] Test student enrollment process

---

## Automation Examples

### Deploy Updates (No 2FA Prompt!)

```bash
# Update WordPress core, plugins, themes
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml \
  -u ansible \
  --private-key=$HOME/.ssh/ansible_automation \
  ansible/playbooks/site.yml \
  --tags wordpress

# Restart services
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml \
  -u ansible \
  --private-key=$HOME/.ssh/ansible_automation \
  ansible/playbooks/site.yml \
  --tags restart
```

### Check Security Status

```bash
# View fail2ban bans
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP \
  "sudo fail2ban-client status sshd"

# View ansible user activity
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP \
  "sudo tail -50 /var/log/ansible-automation/sudo.log"

# Check OpenBao rotation logs
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP \
  "sudo tail -50 /var/log/wordpress-secret-rotation.log"
```

---

## Security Monitoring

### Daily (Automated)

- ✅ OpenBao rotates WordPress DB credentials (3 AM)
- ✅ Ansible user security audit (4 AM)
- ✅ Fail2ban watches for brute force attempts
- ✅ Prometheus collects metrics every 15 seconds

### Weekly (Manual)

- Update WordPress plugins: `wp plugin update --all`
- Review Grafana dashboards for anomalies
- Check Wordfence scan results
- Review fail2ban ban list

### Monthly (Manual)

- Review and rotate non-automated passwords
- Update system packages: `apt update && apt upgrade`
- Review backup restoration procedure
- Check SSL certificate renewal (auto with Cloudflare)

---

## Troubleshooting

### Ansible User Connection Fails

```bash
# Test SSH key
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP

# If fails, check:
# 1. SSH service is running
sudo systemctl status sshd

# 2. UFW allows SSH
sudo ufw status

# 3. Fail2ban hasn't banned you
sudo fail2ban-client status sshd
```

### OpenBao Rotation Fails

```bash
# Check rotation logs
sudo tail -100 /var/log/wordpress-secret-rotation.log

# Check OpenBao is running
sudo systemctl status openbao

# Manually test rotation
sudo /usr/local/bin/rotate-wordpress-secrets.sh

# Check timer schedule
systemctl list-timers wordpress-secret-rotate.timer
```

### Site Not Loading After Cloudflare

```bash
# Check DNS propagation
dig yourdomain.com +short
# Should show Cloudflare IPs

# Check Nginx is running
sudo systemctl status nginx

# Check SSL certificate
curl -I https://yourdomain.com
# Should show 200 OK

# Check Cloudflare SSL mode
# Dashboard → SSL/TLS → Must be "Full (strict)"
```

---

## Cost Breakdown

### Current (Single Server)

| Service | Cost | Included |
|---------|------|----------|
| **Hetzner CAX11** | €4.05/month | 2 vCPU ARM64, 4GB RAM, 40GB NVMe |
| **Cloudflare Free** | €0/month | CDN, DDoS, SSL, WAF |
| **LearnDash** | ~€159/year | LMS platform (one-time + renewals) |
| **Total Infrastructure** | **€4.05/month** + **€159/year LMS** |

### Future (When Revenue Justifies - 3 Servers)

| Component | Server | Monthly |
|-----------|--------|---------|
| WordPress + Nginx | CAX11 | €4.05 |
| MariaDB | CAX11 | €4.05 |
| Monitoring + OpenBao | CAX11 | €4.05 |
| **Total** |  | **€12.15/month** |

---

## Performance Expectations

Based on benchmarks ([docs/performance/ARM64_vs_X86_COMPARISON.md](docs/performance/ARM64_vs_X86_COMPARISON.md)):

- **Throughput**: 8,339 requests/sec (localhost)
- **Latency**: 12ms median response time
- **Capacity**: Can handle 10,000-50,000 visits/day with caching
- **Reliability**: 100% uptime in tests (0 failed requests)

With Cloudflare CDN:
- **Edge caching**: 80-90% of requests served from cache
- **Origin load**: Reduced to 10-20% of total traffic
- **Global latency**: < 100ms worldwide

---

## Questions & Answers

### Do I need Wordfence if I have Cloudflare?

**YES**. They protect different layers:
- **Cloudflare**: Stops attacks at the network edge (DDoS, bots)
- **Wordfence**: Stops WordPress-specific threats (plugin vulns, malware, brute force on wp-login)

Think of it like: Cloudflare is your building security, Wordfence is your apartment lock.

### Can I still use my account with 2FA?

**YES**. Your `malpanez` account keeps 2FA enabled. The `ansible` user is separate and only for automation (no interactive login allowed).

### What if I forget the OpenBao admin password?

Use the break-glass procedure:
1. Stop OpenBao service
2. Reset with unseal key
3. Re-init if needed

**Prevention**: Save unseal key and root token in your password manager NOW.

### How do I add more courses/users?

WordPress admin:
- URL: `https://yourdomain.com/wp-admin`
- Username: `admin`
- Password: `nf0ZTtKYCd78NoY1EivkCT9Mi7aNrImR`

Use LearnDash interface to create courses, lessons, quizzes.

---

## Support & Documentation

| Topic | Document |
|-------|----------|
| **Full deployment guide** | [docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md](docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md) |
| **SSH 2FA break-glass** | [docs/security/SSH_2FA_BREAK_GLASS.md](docs/security/SSH_2FA_BREAK_GLASS.md) |
| **Nginx configuration** | [docs/guides/NGINX_CONFIGURATION_EXPLAINED.md](docs/guides/NGINX_CONFIGURATION_EXPLAINED.md) |
| **ARM64 vs x86 performance** | [docs/performance/ARM64_vs_X86_COMPARISON.md](docs/performance/ARM64_vs_X86_COMPARISON.md) |
| **Ansible Vault** | [VAULT_SETUP_INSTRUCTIONS.md](VAULT_SETUP_INSTRUCTIONS.md) |

---

## Final Pre-Flight Check

Before running the automation script, verify:

- [ ] Hetzner server is running and accessible
- [ ] You have the vault password (`8ZpBU0IW4pWNKuXm4b7hQxF5e/jmfspQYzrSSLhuXu8=`)
- [ ] Your 2FA device is available (for manual SSH)
- [ ] GoDaddy account credentials ready (for DNS update)
- [ ] Cloudflare account created (or ready to create)

---

## Let's Go! 🚀

Execute the automation:

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure
./scripts/production-setup-today.sh
```

**Time estimate**: 30-45 minutes total (mostly waiting for DNS propagation)

**Result**: Production-ready WordPress LMS platform with:
- ✅ Automated deployments
- ✅ Daily credential rotation
- ✅ Full security stack
- ✅ Global CDN
- ✅ Real-time monitoring

Good luck! 🎉
