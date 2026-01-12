# Deploy From Scratch - Complete Guide

**Date**: 2026-01-02
**Current Status**: No infrastructure deployed yet
**Goal**: Deploy production WordPress LMS platform from zero to production

---

## Prerequisites Check

Before starting, verify you have:

- [ ] Hetzner Cloud API token (set in environment or tfvars)
- [ ] SSH key `~/.ssh/github_ed25519` (for initial server access)
- [ ] Ansible Vault password: `8ZpBU0IW4pWNKuXm4b7hQxF5e/jmfspQYzrSSLhuXu8=`
- [ ] Domain registered (for Cloudflare DNS migration later)

---

## Step 1: Deploy Infrastructure with Terraform (5 min)

### 1.1 Configure Terraform Variables

```bash
cd terraform

# Check if terraform.tfvars or terraform.staging.tfvars exists
ls -la terraform*.tfvars
```

If using `terraform.staging.tfvars`, verify it contains:

```hcl
# Server Configuration
environment       = "production"
architecture      = "arm64"          # ARM64 is 2.68x faster!
server_size       = "small"          # CAX11: 2 vCPU, 4GB RAM
location          = "nbg1"           # Nuremberg (or your preferred location)
instance_number   = 1

# SSH Configuration
ssh_public_key_path = "~/.ssh/github_ed25519.pub"
```

### 1.2 Initialize Terraform

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Initialize Terraform (if not already done)
terraform init
```

### 1.3 Plan Deployment

```bash
# Create plan (use staging tfvars if that's what you have)
terraform plan -var-file=terraform.staging.tfvars -out=tfplan

# Review the plan - should show:
# - 1 hcloud_server to create (CAX11)
# - 1 hcloud_firewall to create
# - 1 hcloud_ssh_key to create
```

### 1.4 Deploy Server

```bash
# Apply the plan
terraform apply tfplan

# Expected output:
# - Server IP address
# - Server name (e.g., wp-prod-arm64-01)
# - Firewall rules created
```

**Save the server IP address** - you'll need it for the next steps!

---

## Step 2: Wait for Server to be Ready (2-3 min)

The server needs time to boot and complete cloud-init setup.

```bash
# Get server IP from Terraform output
SERVER_IP=$(terraform output -raw server_ipv4 2>/dev/null || echo "CHECK_TERRAFORM_OUTPUT")

echo "Server IP: $SERVER_IP"

# Wait for SSH to be available (may take 2-3 minutes)
echo "Waiting for SSH to become available..."
while ! nc -z $SERVER_IP 22 2>/dev/null; do
    echo -n "."
    sleep 5
done
echo ""
echo "SSH is now available!"

# Test SSH connection with your github_ed25519 key
ssh -i ~/.ssh/github_ed25519 -o StrictHostKeyChecking=no root@$SERVER_IP "echo 'Server is ready!'"
```

---

## Step 3: Run Initial Ansible Deployment (10-15 min)

Now deploy the full WordPress stack using your **personal account** (before ansible user exists).

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/ansible

# IMPORTANT: Override to use your personal account (ansible user doesn't exist yet!)
ansible-playbook -i inventory/hetzner.hcloud.yml \
  -u root \
  --private-key ~/.ssh/github_ed25519 \
  playbooks/site.yml

# This will install:
# - All security hardening (UFW, Fail2ban, AppArmor)
# - SSH 2FA configuration
# - Nginx + PHP 8.4 + MariaDB
# - WordPress with initial admin user
# - OpenBao for secret management
# - Monitoring stack (Grafana, Prometheus)
# - Valkey cache
```

**Expected Duration**: 10-15 minutes

---

## Step 4: Capture Your 2FA QR Code (5 min)

**CRITICAL**: Do this BEFORE enabling 2FA enforcement!

```bash
# SSH to server with root account
ssh -i ~/.ssh/github_ed25519 root@$SERVER_IP

# Create your user account if not already done
useradd -m -s /bin/bash -G sudo malpanez

# Set up Google Authenticator for your account
su - malpanez
google-authenticator

# Answer the prompts:
# - "Do you want authentication tokens to be time-based?" → YES
# - A QR code will display in your terminal
# - Scan with Google Authenticator app on your phone
# - Save emergency scratch codes in password manager!
# - "Do you want me to update your ~/.google_authenticator file?" → YES
# - "Do you want to disallow multiple uses of the same token?" → YES
# - "Do you want to increase the time window?" → NO (keep 30 seconds)
# - "Do you want to enable rate-limiting?" → YES

exit  # Exit back to root
exit  # Exit SSH
```

**Save emergency scratch codes NOW!**

---

## Step 5: Create Ansible Automation User (5 min)

Now that the server exists, create the dedicated ansible automation user.

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure

# Run the production setup script
./scripts/production-setup-today.sh

# This will:
# 1. Generate ~/.ssh/ansible_automation key
# 2. Deploy ansible user to server
# 3. Configure security hardening for ansible user
# 4. Setup OpenBao rotation
# 5. Test ansible user connection
```

**What this creates**:

- `ansible` user on server (no 2FA, key-based only)
- All ansible commands logged to `/var/log/ansible-automation/sudo.log`
- Fail2ban monitoring for ansible user
- Restricted sudo access (specific commands only)

---

## Step 6: Complete OpenBao Database Secret Rotation (5 min)

SSH to server and configure OpenBao database engine:

```bash
# SSH with YOUR account (2FA enabled)
ssh -i ~/.ssh/github_ed25519 malpanez@$SERVER_IP
# Enter 6-digit code from Google Authenticator app

# Login to OpenBao
bao login -method=userpass username=admin
# Password: tGUL57rBq85GQsDnHbtoRbonobe5Ld7H

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

# Verify WordPress can connect
sudo -u www-data wp --path=/var/www/wordpress db check

# Check rotation timer is scheduled
systemctl list-timers wordpress-secret-rotate.timer

exit  # Exit SSH
```

---

## Step 7: Test Ansible Automation User (2 min)

Verify the ansible user can deploy without 2FA prompts:

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/ansible

# Test SSH connection (no 2FA prompt!)
ssh -i ~/.ssh/ansible_automation ansible@$SERVER_IP "echo 'Ansible user works!'"

# Test Ansible deployment (dry run)
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml --check

# Should run without any 2FA prompts!
```

---

## Step 8: Migrate DNS to Cloudflare (15 min + 24-48h propagation)

### 8.1 Create Cloudflare Account

1. Go to: <https://dash.cloudflare.com/sign-up>
2. Create free account
3. Verify email

### 8.2 Add Domain to Cloudflare

1. Click "Add a Site"
2. Enter your domain name
3. Select **Free** plan
4. Cloudflare will scan existing DNS records

### 8.3 Get Cloudflare Nameservers

Cloudflare will provide two nameservers like:

```
alexa.ns.cloudflare.com
phil.ns.cloudflare.com
```

**Write these down!**

### 8.4 Update GoDaddy Nameservers

1. Login: <https://account.godaddy.com>
2. Navigate: My Products → Domains
3. Click your domain → Manage DNS
4. Scroll to "Nameservers" section
5. Click "Change"
6. Select "Custom Nameservers"
7. Replace with Cloudflare nameservers
8. Click "Save"

### 8.5 Configure DNS Records in Cloudflare

Add these records:

| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| A | @ | YOUR_SERVER_IP | ✅ Proxied |
| A | www | YOUR_SERVER_IP | ✅ Proxied |

### 8.6 Configure Cloudflare Settings

**SSL/TLS**:

- Mode: **Full (strict)**
- Always Use HTTPS: **ON**

**Speed**:

- Auto Minify: Enable HTML, CSS, JS
- Brotli: **ON**

**Security**:

- Security Level: **Medium**
- Bot Fight Mode: **ON**

---

## Step 9: Wait for DNS Propagation (24-48 hours)

```bash
# Check DNS propagation
dig yourdomain.com +short

# Should show Cloudflare IPs (not your server IP directly)
```

---

## Step 10: Install WordPress Plugins (After DNS Propagates)

```bash
# SSH to server
ssh -i ~/.ssh/github_ed25519 malpanez@$SERVER_IP

# Install Wordfence
sudo -u www-data wp plugin install wordfence --activate --path=/var/www/wordpress

# Install Cloudflare plugin
sudo -u www-data wp plugin install cloudflare --activate --path=/var/www/wordpress

# Install backup plugin
sudo -u www-data wp plugin install updraftplus --activate --path=/var/www/wordpress

# Configure Wordfence
sudo -u www-data wp wordfence enable-firewall --path=/var/www/wordpress
sudo -u www-data wp wordfence set-learning-mode off --path=/var/www/wordpress

exit
```

---

## Verification Checklist

After completing all steps, verify:

- [ ] Server is running and accessible via SSH
- [ ] 2FA works for your `malpanez` account
- [ ] ansible user can SSH without 2FA
- [ ] Ansible deployments work without prompts
- [ ] OpenBao rotation timer is active
- [ ] Grafana dashboard accessible: `http://SERVER_IP:3000`
- [ ] WordPress admin accessible: `http://SERVER_IP/wp-admin`
- [ ] DNS points to Cloudflare (after propagation)
- [ ] HTTPS works via Cloudflare
- [ ] Wordfence installed and active

---

## What You Have Now

### Infrastructure

- ✅ Hetzner ARM64 CAX11 server (2.68x faster than x86!)
- ✅ Hetzner Cloud Firewall
- ✅ Cloudflare DNS + CDN + DDoS protection

### Security (8 Layers)

1. **Network Edge**: Cloudflare DDoS + WAF
2. **Cloud Firewall**: Hetzner Cloud Firewall
3. **Host Firewall**: UFW (ports 22, 80, 443)
4. **SSH**: 2FA for humans + key-only for automation
5. **Brute Force**: Fail2ban
6. **Application**: Wordfence
7. **Database**: OpenBao rotating credentials daily
8. **Secrets**: Ansible Vault (AES256)

### Automation

- ✅ Ansible deployments without 2FA prompts
- ✅ All ansible user commands logged
- ✅ Fail2ban monitoring ansible user
- ✅ Daily secret rotation (3 AM)

### Services

- ✅ WordPress Latest + LearnDash (to install after purchase)
- ✅ Nginx with TLS 1.3
- ✅ PHP 8.4-FPM
- ✅ MariaDB 11.4
- ✅ Valkey 8.0 cache
- ✅ OpenBao secret management
- ✅ Grafana + Prometheus monitoring

---

## Next Steps

### Immediate

1. Purchase LearnDash license
2. Upload LearnDash plugin via WordPress admin
3. Configure course structure

### Content Creation

1. Design homepage
2. Create first trading course
3. Setup payment gateway (Stripe/PayPal)
4. Configure course enrollment

### Ongoing

- Daily: OpenBao rotates DB credentials (automated)
- Weekly: Update WordPress plugins
- Monthly: Review security logs and backups

---

## Useful Commands

### Deploy updates (no 2FA!)

```bash
ansible-playbook -i ansible/inventory/hetzner.hcloud.yml ansible/playbooks/site.yml
```

### Manual SSH (your account with 2FA)

```bash
ssh -i ~/.ssh/github_ed25519 malpanez@SERVER_IP
```

### Automation SSH (ansible user, no 2FA)

```bash
ssh -i ~/.ssh/ansible_automation ansible@SERVER_IP
```

### Check ansible user activity

```bash
ssh -i ~/.ssh/github_ed25519 malpanez@SERVER_IP
sudo tail -50 /var/log/ansible-automation/sudo.log
```

### View Grafana

```
http://SERVER_IP:3000
Username: admin
Password: QiNzF3GvnyWp2URH3FXhKfiBt8CtR1vl
```

---

## Documentation

- [EXECUTION_GUIDE.md](EXECUTION_GUIDE.md) - Answers to all questions
- [GO_LIVE_TODAY_CHECKLIST.md](GO_LIVE_TODAY_CHECKLIST.md) - Quick reference
- [docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md](docs/guides/DEPLOYMENT_AUTOMATION_SETUP.md) - Detailed automation guide
- [docs/security/SSH_2FA_INITIAL_SETUP.md](docs/security/SSH_2FA_INITIAL_SETUP.md) - 2FA setup guide

---

## Ready to Start?

Execute these commands in order:

```bash
# 1. Deploy server
cd terraform
terraform plan -var-file=terraform.staging.tfvars -out=tfplan
terraform apply tfplan

# 2. Deploy WordPress stack
cd ../ansible
ansible-playbook -i inventory/hetzner.hcloud.yml -u root --private-key ~/.ssh/github_ed25519 playbooks/site.yml

# 3. Setup 2FA
ssh -i ~/.ssh/github_ed25519 malpanez@SERVER_IP
google-authenticator

# 4. Create ansible automation user
cd ..
./scripts/production-setup-today.sh

# 5. Complete OpenBao setup
# (Follow commands from script output)
```

**Total time**: ~45 minutes + DNS propagation (24-48h)

Good luck! 🚀
