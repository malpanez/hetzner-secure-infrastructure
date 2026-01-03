# Staging Deployment Guide

## Quick Start - Deploy to Hetzner Staging

This guide walks you through deploying to a Hetzner staging VPS to test the complete infrastructure before production.

**Cost**: ~€5.83/month (CX22 server)
**Time**: ~15 minutes
**Environment**: Debian 13 (Trixie) - same as production

---

## Why Staging Instead of Vagrant?

✅ **Advantages**:
- Real Hetzner Cloud environment (identical to production)
- No VirtualBox/WSL2 issues
- Tests Terraform + Ansible integration together
- Validates networking, firewall, DNS
- Can be destroyed after testing

❌ **Vagrant Issues** (current blockers):
- VirtualBox kernel module error (VERR_LDR_IMPORTED_SYMBOL_NOT_FOUND)
- Requires Windows host, won't run from WSL2
- May conflict with Hyper-V

---

## Prerequisites

### 1. Hetzner Cloud Token

Get from: https://console.hetzner.cloud/

```bash
# Set as environment variable
export HCLOUD_TOKEN="your-hetzner-api-token"
```

**Required Permissions**:
- ✅ Read/Write Servers
- ✅ Read/Write SSH Keys
- ✅ Read/Write Firewalls

### 2. SSH Key

Your Yubikey FIDO2 key:

```bash
# Verify it exists
cat ~/.ssh/id_ed25519_sk.pub

# Should output something like:
# sk-ssh-ed25519@openssh.com AAAAGnNr... miguel@hetzner
```

### 3. Ansible Vault Password

You'll need the vault password for encrypted variables:

```bash
# Store in file for convenience (don't commit!)
echo "your-vault-password" > ~/.ansible_vault_pass.txt
chmod 600 ~/.ansible_vault_pass.txt
```

---

## Step-by-Step Deployment

### Step 1: Configure Terraform for Staging

```bash
cd ~/repos/hetzner-secure-infrastructure/terraform

# Copy example config
cp terraform.staging.tfvars.example terraform.staging.tfvars

# Edit with your values
nano terraform.staging.tfvars
```

**Required changes**:
```hcl
hcloud_token = "YOUR_ACTUAL_TOKEN"
ssh_public_key = "YOUR_ACTUAL_PUBLIC_KEY"
```

### Step 2: Initialize Terraform

```bash
terraform init
```

Expected output:
```
Terraform has been successfully initialized!
```

### Step 3: Plan Infrastructure

```bash
terraform plan -var-file="terraform.staging.tfvars"
```

This shows what will be created:
- 1 × CX22 server (2 vCPU, 4GB RAM, 40GB SSD)
- 1 × SSH key
- 1 × Firewall (SSH, HTTP, HTTPS)

**Cost**: €5.83/month

### Step 4: Deploy Infrastructure

```bash
terraform apply -var-file="terraform.staging.tfvars"
```

Type `yes` when prompted.

**Wait**: 30-60 seconds for server to boot.

### Step 5: Get Server IP

```bash
terraform output server_ipv4
```

Example output:
```
95.217.XXX.XXX
```

### Step 6: Test SSH Connection

```bash
SERVER_IP=$(terraform output -raw server_ipv4)
ssh miguel@$SERVER_IP
```

Expected:
- Yubikey should blink (touch to authenticate)
- You should get a shell on Debian 13

Exit the SSH session:
```bash
exit
```

### Step 7: Configure Ansible Inventory

The Hetzner dynamic inventory will automatically discover your server:

```bash
cd ../ansible

# Verify server is discovered
export HCLOUD_TOKEN="your-token"
ansible-inventory -i inventory/hetzner.yml --list
```

You should see your `staging-wordpress` server in the output.

### Step 8: Install Ansible Galaxy Requirements

```bash
# From Windows PowerShell (better network connectivity)
cd C:\Users\YourUser\path\to\repos\hetzner-secure-infrastructure\ansible
ansible-galaxy install -r requirements.yml --force
```

Or if networking works from WSL2:
```bash
ansible-galaxy install -r requirements.yml --force
```

Expected collections:
- ✅ prometheus.prometheus
- ✅ grafana.grafana
- ✅ community.general
- ✅ ansible.posix

Expected roles:
- ✅ geerlingguy.mysql

### Step 9: Create Ansible Vault

```bash
# Create vault with secrets
ansible-vault create inventory/group_vars/all/vault.yml

# Or edit existing
ansible-vault edit inventory/group_vars/all/vault.yml
```

**Required variables**:
```yaml
---
# WordPress Database
wordpress_db_password: "StrongPassword123!"
wordpress_db_name: "wordpress"
wordpress_db_user: "wordpress"

# WordPress Admin
nginx_wordpress_admin_email: "admin@homelabforge.dev"
nginx_wordpress_admin_password: "AdminPassword123!"

# WordPress Salts (generate at: https://api.wordpress.org/secret-key/1.1/salt/)
nginx_wordpress_auth_key: "put unique phrase here"
nginx_wordpress_secure_auth_key: "put unique phrase here"
nginx_wordpress_logged_in_key: "put unique phrase here"
nginx_wordpress_nonce_key: "put unique phrase here"
nginx_wordpress_auth_salt: "put unique phrase here"
nginx_wordpress_secure_auth_salt: "put unique phrase here"
nginx_wordpress_logged_in_salt: "put unique phrase here"
nginx_wordpress_nonce_salt: "put unique phrase here"
```

### Step 10: Deploy with Ansible

**Option A**: Full deployment (all roles)

```bash
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --ask-vault-pass
```

**Option B**: WordPress-only (skip monitoring/secrets)

```bash
ansible-playbook -i inventory/hetzner.yml playbooks/wordpress-only.yml --ask-vault-pass
```

**Duration**: ~10-15 minutes

### Step 11: Verify Deployment

```bash
# Check all services are running
ssh miguel@$SERVER_IP "sudo systemctl status nginx php8.2-fpm mysql valkey"

# Test WordPress
curl http://$SERVER_IP

# Should return WordPress installation page HTML
```

### Step 12: Complete WordPress Setup

```bash
# Get server IP
terraform output server_ipv4

# Open in browser
http://95.217.XXX.XXX
```

Follow WordPress installation wizard:
1. Select language
2. Create admin account
3. Install LearnDash (manual - requires license)

---

## Validation Checklist

After deployment, verify:

### Security
- [ ] SSH works with Yubikey
- [ ] UFW firewall is active: `sudo ufw status`
- [ ] Fail2ban is running: `sudo systemctl status fail2ban`
- [ ] Unattended upgrades enabled: `sudo systemctl status unattended-upgrades`

### Services
- [ ] Nginx: `sudo systemctl status nginx`
- [ ] PHP-FPM: `sudo systemctl status php8.2-fpm`
- [ ] MySQL/MariaDB: `sudo systemctl status mysql`
- [ ] Valkey (Redis): `sudo systemctl status valkey`

### WordPress
- [ ] Site loads: `curl http://$SERVER_IP`
- [ ] Admin panel accessible: `http://$SERVER_IP/wp-admin`
- [ ] Database connection works
- [ ] Plugins installed (8 essential plugins)

### Monitoring (if deployed)
- [ ] Node Exporter: `curl http://localhost:9100/metrics`
- [ ] Prometheus: `http://$SERVER_IP:9090`
- [ ] Grafana: `http://$SERVER_IP:3000`

---

## Testing Individual Roles

Deploy specific roles for testing:

```bash
# Only security hardening
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags security

# Only WordPress stack
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags wordpress

# Only monitoring
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags monitoring

# Specific role
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags nginx_wordpress
```

---

## Cleanup After Testing

### Option 1: Destroy Everything

```bash
cd terraform
terraform destroy -var-file="terraform.staging.tfvars"
```

Type `yes` to confirm.

**Result**: Server deleted, no more charges.

### Option 2: Keep for Further Testing

Leave server running for continued testing:
- Cost: €5.83/month
- Can redeploy Ansible anytime
- Can test updates and changes

---

## Common Issues

### Issue: "Connection refused" when running Ansible

**Cause**: Server not fully booted yet

**Fix**: Wait 60 seconds after `terraform apply`

```bash
# Wait for SSH to be ready
sleep 60
ansible all -i inventory/hetzner.yml -m ping
```

### Issue: "Host key verification failed"

**Cause**: New server, SSH fingerprint unknown

**Fix**: Accept fingerprint or disable strict checking for staging

```bash
# Accept fingerprint
ssh miguel@$SERVER_IP

# Or disable strict checking (staging only!)
export ANSIBLE_HOST_KEY_CHECKING=False
```

### Issue: Ansible collections not found

**Cause**: Collections not installed

**Fix**:
```bash
ansible-galaxy install -r ansible/requirements.yml --force
```

### Issue: Vault password incorrect

**Cause**: Wrong password or vault not created

**Fix**:
```bash
# Create new vault
ansible-vault create inventory/group_vars/all/vault.yml

# Or reset password
ansible-vault rekey inventory/group_vars/all/vault.yml
```

---

## Differences from Vagrant

| Aspect | Vagrant (Local) | Hetzner Staging |
|--------|----------------|-----------------|
| **Network** | VirtualBox NAT | Real internet |
| **IP** | 192.168.56.254 | 95.217.XXX.XXX |
| **DNS** | /etc/hosts | Real DNS |
| **SSL** | Self-signed | Let's Encrypt |
| **Cost** | Free | €5.83/month |
| **Boot time** | 2-3 min | 30-60 sec |
| **Realism** | 80% | 100% |
| **Firewall** | VirtualBox rules | Hetzner + UFW |

---

## Next Steps

After successful staging deployment:

1. **Test all WordPress functionality**:
   - Install themes
   - Upload media
   - Test plugins
   - Create test courses (LearnDash)

2. **Validate security**:
   - Run Nessus/OpenVAS scan
   - Test Wordfence
   - Verify Fail2ban logs

3. **Monitor performance**:
   - Check Prometheus metrics
   - Review Grafana dashboards
   - Analyze slow queries

4. **Document issues**:
   - Note any errors
   - Update TROUBLESHOOTING.md
   - Fix issues before production

5. **Deploy to production**:
   - Use `terraform.tfvars` (production config)
   - Enable Cloudflare
   - Set up real domain
   - Enable backups

---

## VirtualBox Alternative (If You Still Want to Try)

If you want to fix VirtualBox for local testing:

### Check Hyper-V Conflict

```powershell
# From Windows PowerShell as Administrator
bcdedit /enum | findstr hypervisorlaunchtype

# If output shows "auto", disable it:
bcdedit /set hypervisorlaunchtype off

# Restart Windows
Restart-Computer
```

### Reinstall VirtualBox

```powershell
# Uninstall current version
winget uninstall Oracle.VirtualBox

# Install stable version (7.0.14)
winget install Oracle.VirtualBox --version 7.0.14

# Restart Windows
Restart-Computer
```

### Try Docker Desktop Alternative

If VirtualBox continues to fail, Docker Desktop is more reliable on Windows:

```powershell
# Install Docker Desktop
winget install Docker.DockerDesktop

# Restart Windows
Restart-Computer

# Then use docker-compose instead of Vagrant
cd C:\path\to\repo
docker-compose up -d
```

---

**Last Updated**: December 29, 2025
**Status**: Recommended approach for testing

**Estimated Time**:
- Setup: 5 minutes
- Terraform deploy: 2 minutes
- Ansible deploy: 10-15 minutes
- **Total**: ~20 minutes
