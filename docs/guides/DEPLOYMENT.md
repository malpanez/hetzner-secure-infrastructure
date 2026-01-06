# Deployment Guide - Hetzner Secure Infrastructure

**Complete deployment workflow from development to production with Terraform Cloud**

---

## Table of Contents

1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Deployment Scenarios](#deployment-scenarios)
4. [Development Workflow](#development-workflow)
5. [Production Workflow with Terraform Cloud](#production-workflow-with-terraform-cloud)
6. [Testing ARM vs x86 Architecture](#testing-arm-vs-x86-architecture)
7. [Post-Deployment](#post-deployment)
8. [Troubleshooting](#troubleshooting)

---

## Overview

This infrastructure supports three deployment patterns:

| Pattern | Use Case | Automation Level | Tools |
|---------|----------|------------------|-------|
| **Development** | Testing, experimentation | Manual | Terraform CLI + Ansible CLI |
| **Staging** | Pre-production validation | Semi-automated | Terraform CLI + Ansible CLI |
| **Production** | Live environment | Fully automated | Terraform Cloud + Ansible (manual or CI/CD) |

### Architecture Decision Flow

```
┌─────────────────────────┐
│  Choose Architecture    │
│  (x86 vs ARM)          │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Deploy with Terraform  │
│  (Infrastructure)       │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Configure with Ansible │
│  (Software stack)       │
└───────────┬─────────────┘
            │
            ▼
┌─────────────────────────┐
│  Production Ready       │
│  (WordPress + LearnDash)│
└─────────────────────────┘
```

---

## Prerequisites

### Required Software

```bash
# Check versions
terraform version  # >= 1.5.0
ansible --version  # >= 2.15.0
ssh -V            # OpenSSH >= 8.0

# Install missing tools
# Terraform: https://www.terraform.io/downloads
# Ansible: pip3 install ansible
```

### Required Credentials

1. **Hetzner Cloud API Token**
   - Get from: <https://console.hetzner.cloud/projects>
   - Permissions: Read & Write

2. **SSH Key Pair**

   ```bash
   # Generate if not exists
   ssh-keygen -t ed25519 -C "your-email@example.com" -f ~/.ssh/github_ed25519
   ```

3. **Codeberg Account** (for git hosting)
   - Repository: Your infrastructure code

4. **Terraform Cloud Account** (for production)
   - Free tier: Up to 500 resources
   - Sign up: <https://app.terraform.io/signup/account>

---

## Deployment Scenarios

### Scenario 1: All-in-One (Single Server)

**Best for:** Staging, small production sites (< 5,000 req/s)

```
┌─────────────────────────────────────┐
│  Hetzner CX23 (€5.04/mo)           │
│  ┌─────────────────────────────┐   │
│  │  WordPress + MariaDB         │   │
│  │  Nginx + PHP 8.4-FPM         │   │
│  │  Valkey (Redis)              │   │
│  │  Prometheus + Grafana        │   │
│  │  Loki + Promtail             │   │
│  └─────────────────────────────┘   │
└─────────────────────────────────────┘
```

**Cost:** €5.04/month (x86) or €4.45/month (ARM)

### Scenario 2: Separated Monitoring (2 Servers)

**Best for:** Production sites with dedicated monitoring

```
┌──────────────────────┐  ┌──────────────────────┐
│  WordPress Server    │  │  Monitoring Server   │
│  CX23 (€5.04/mo)     │  │  CX23 (€5.04/mo)     │
│  ├─ WordPress        │  │  ├─ Prometheus       │
│  ├─ Nginx            │  │  ├─ Grafana          │
│  ├─ MariaDB          │  │  ├─ Loki             │
│  ├─ Valkey           │  │  └─ Alertmanager     │
│  └─ Node Exporter    │  │                      │
└──────────────────────┘  └──────────────────────┘
```

**Cost:** €10.08/month

### Scenario 3: Full 3-Tier (3+ Servers)

**Best for:** Large production (> 10,000 req/s), compliance requirements

```
┌─────────────┐  ┌─────────────┐  ┌─────────────┐
│  WordPress  │  │  Monitoring │  │   OpenBao   │
│  CX33       │  │  CX23       │  │   CX11      │
│  €12.90/mo  │  │  €5.04/mo   │  │   €4.15/mo  │
└─────────────┘  └─────────────┘  └─────────────┘
```

**Cost:** €22.09/month

---

## Development Workflow

### Step 1: Clone Repository

```bash
# Clone from Codeberg
git clone git@codeberg.org:yourusername/hetzner-secure-infrastructure.git
cd hetzner-secure-infrastructure
```

### Step 2: Configure Terraform

```bash
cd terraform/environments/staging

# Copy example configuration
cp terraform.staging.tfvars.example terraform.staging.tfvars

# Edit configuration
nano terraform.staging.tfvars
```

**Edit `terraform.staging.tfvars`:**

```hcl
# Hetzner Configuration
hcloud_token = "your-hetzner-api-token"

# Server Configuration
server_name = "stag-de-wp-01"
server_type = "cx23"        # or "cax11" for ARM
server_location = "nbg1"    # Nuremberg, Germany
server_image = "debian-13"  # Debian Trixie

# Architecture Selection
architecture = "x86"  # or "arm64"

# Labels for dynamic inventory
environment = "staging"
project_name = "wordpress-lms"

# Monitoring (all-in-one for staging)
deploy_monitoring_server = false
deploy_openbao_server = false
```

### Step 3: Deploy Infrastructure with Terraform

```bash
# Initialize Terraform
terraform init

# Validate configuration
terraform validate

# Format code
terraform fmt

# Preview changes
terraform plan

# Apply changes
terraform apply

# Note the server IP
terraform output server_ipv4
# Example output: 46.224.156.140
```

### Step 4: Configure Dynamic Inventory

```bash
cd ../../ansible

# Set Hetzner API token
export HCLOUD_TOKEN="your-hetzner-api-token"

# Test dynamic inventory discovery
ansible-inventory -i inventory/hetzner.hcloud.yml --graph

# Expected output:
# @all:
#   |--@hetzner:
#   |  |--@env_staging:
#   |  |  |--stag-de-wp-01
#   |  |--@staging:
#   |  |  |--stag-de-wp-01
#   |  |--@type_cx23:
#   |  |  |--stag-de-wp-01

# List detailed inventory
ansible-inventory -i inventory/hetzner.hcloud.yml --list
```

### Step 5: Configure Ansible Variables

```bash
# Create group_vars for staging
mkdir -p inventory/group_vars/staging

# Create staging configuration
cat > inventory/group_vars/staging/main.yml <<'EOF'
---
# Staging Environment Configuration

# Domain (optional for staging)
nginx_wordpress_server_name: "46.224.156.140"

# SSL (disabled for staging - use HTTP)
nginx_wordpress_ssl_enabled: false

# WordPress Configuration
wordpress_db_name: "wordpress"
wordpress_db_user: "wordpress"
wordpress_table_prefix: "wp_"

# Monitoring (all-in-one)
monitoring_all_in_one: true
EOF

# Create secrets file (encrypted)
ansible-vault create inventory/group_vars/staging/vault.yml
```

**In the vault file, add:**

```yaml
---
# Sensitive variables for staging

# MariaDB passwords
vault_mysql_root_password: "CHANGE_TO_STRONG_PASSWORD"
vault_wordpress_db_password: "CHANGE_TO_STRONG_PASSWORD"

# Grafana admin password
vault_grafana_admin_password: "CHANGE_TO_STRONG_PASSWORD"
```

**Generate strong passwords:**

```bash
# Generate 3 passwords
openssl rand -base64 32
openssl rand -base64 32
openssl rand -base64 32
```

### Step 6: Deploy with Ansible

```bash
# Test connection first
ansible -i inventory/hetzner.hcloud.yml staging -m ping

# Expected output:
# stag-de-wp-01 | SUCCESS => {
#     "ping": "pong"
# }

# Run full deployment (20-30 minutes)
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
  --ask-vault-pass

# Or deploy specific tags
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
  --tags wordpress \
  --ask-vault-pass
```

### Step 7: Verify Deployment

```bash
# Get server IP
SERVER_IP=$(cd terraform/environments/staging && terraform output -raw server_ipv4)

# Test WordPress
curl -I http://$SERVER_IP/
# Should return: HTTP/1.1 302 Found (redirect to wp-admin/install.php)

# Test Grafana
curl -I http://$SERVER_IP:3000/
# Should return: HTTP/1.1 302 Found (redirect to login)

# SSH to server
ssh malpanez@$SERVER_IP

# Check services
systemctl status nginx php8.4-fpm mariadb valkey-server prometheus grafana-server

# All should show: active (running)
```

---

## Production Workflow with Terraform Cloud

### Why Terraform Cloud?

- **State Management**: Secure remote state storage
- **Secret Management**: Encrypted variables (HCLOUD_TOKEN, etc.)
- **CI/CD Integration**: Auto-run on git push
- **Collaboration**: Team access with RBAC
- **Set and Forget**: Automatic infrastructure management

### Architecture: Codeberg + Terraform Cloud

```
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   Codeberg      │────>│ Terraform Cloud  │────>│ Hetzner Cloud   │
│   (Git Repo)    │     │ (IaC Execution)  │     │ (Infrastructure)│
└─────────────────┘     └──────────────────┘     └─────────────────┘
         │                       │                         │
         │                       │                         ▼
         │                       │              ┌─────────────────┐
         │                       │              │  Servers Running│
         │                       │              │  (IP addresses) │
         │                       │              └────────┬────────┘
         │                       │                       │
         ▼                       ▼                       ▼
┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│  Manual Ansible │     │  Optional: GitHub│     │  Configured     │
│  (from local)   │────>│  Actions Ansible │────>│  WordPress      │
└─────────────────┘     └──────────────────┘     └─────────────────┘
```

### Step 1: Create Terraform Cloud Account

1. **Sign up for free account**:
   - Go to: <https://app.terraform.io/signup/account>
   - Use your email
   - Verify email

2. **Create organization**:
   - Name: `wordpress-lms-infrastructure` (or your choice)
   - Email: <your-email@example.com>

3. **Create workspace**:
   - **Workspace name**: `hetzner-production`
   - **Workflow**: Version control workflow
   - **VCS provider**: Configure > Add VCS Provider > Custom (Codeberg)

### Step 2: Connect Codeberg to Terraform Cloud

Terraform Cloud doesn't have native Codeberg integration, but we can use SSH-based connection:

#### Option A: SSH Key Connection (Recommended)

1. **Generate SSH key for Terraform Cloud**:

   ```bash
   ssh-keygen -t ed25519 -C "terraform-cloud" -f ~/.ssh/terraform_cloud_ed25519
   ```

2. **Add SSH public key to Codeberg**:
   - Go to: <https://codeberg.org/user/settings/keys>
   - Add new SSH key
   - Paste content of `~/.ssh/terraform_cloud_ed25519.pub`
   - Title: "Terraform Cloud Read Access"

3. **Add SSH private key to Terraform Cloud**:
   - Terraform Cloud > Organization Settings > SSH Keys
   - Add SSH Key
   - Name: "codeberg-read-key"
   - Paste content of `~/.ssh/terraform_cloud_ed25519` (private key)

4. **Configure workspace to use SSH**:
   - Workspace Settings > Version Control
   - Repository: `git@codeberg.org:yourusername/hetzner-secure-infrastructure.git`
   - SSH Key: Select "codeberg-read-key"
   - Working Directory: `terraform/environments/production`
   - VCS Branch: `main`

#### Option B: Manual Upload (Simpler for Testing)

If SSH setup is complex, use manual workflow:

1. **Create workspace**:
   - Workflow: API-driven workflow
   - Name: `hetzner-production`

2. **Upload configuration manually**:

   ```bash
   cd terraform/environments/production
   tar -czf terraform-config.tar.gz *.tf *.tfvars
   # Upload via Terraform Cloud UI
   ```

### Step 3: Configure Terraform Cloud Variables

In Terraform Cloud workspace > Variables:

#### Terraform Variables

| Variable | Value | Sensitive | Category |
|----------|-------|-----------|----------|
| `hcloud_token` | your-hetzner-api-token | ✅ Yes | Terraform |
| `environment` | production | ❌ No | Terraform |
| `server_type` | cx23 | ❌ No | Terraform |
| `server_location` | nbg1 | ❌ No | Terraform |
| `architecture` | x86 | ❌ No | Terraform |
| `project_name` | wordpress-lms | ❌ No | Terraform |

#### Environment Variables

| Variable | Value | Sensitive | Category |
|----------|-------|-----------|----------|
| `HCLOUD_TOKEN` | your-hetzner-api-token | ✅ Yes | Environment |
| `TF_LOG` | INFO | ❌ No | Environment |

### Step 4: Configure Terraform Backend for Cloud

Update `terraform/environments/production/backend.tf`:

```hcl
# backend.tf
terraform {
  cloud {
    organization = "wordpress-lms-infrastructure"  # YOUR org name

    workspaces {
      name = "hetzner-production"
    }
  }
}
```

### Step 5: Update Production Configuration

**Edit `terraform/environments/production/terraform.production.tfvars`:**

```hcl
# Production Configuration

# Server Configuration (CHANGE after ARM testing)
server_name = "prod-de-wp-01"
server_type = "cx23"        # or "cax11" if ARM wins
server_location = "nbg1"    # Nuremberg, Germany
server_image = "debian-13"

# Architecture (CHANGE after testing)
architecture = "x86"  # or "arm64"

# Labels
environment = "production"
project_name = "wordpress-lms"

# All-in-One Deployment (recommended for start)
deploy_monitoring_server = false
deploy_openbao_server = false

# Naming Convention
# prod-{location}-{role}-{number}
# Example: prod-de-wp-01 (production, Germany, WordPress, instance 01)
```

### Step 6: Initialize Terraform Cloud Workflow

```bash
cd terraform/environments/production

# Login to Terraform Cloud
terraform login
# Follow browser prompt, paste token

# Initialize with cloud backend
terraform init

# This will:
# 1. Migrate state to Terraform Cloud
# 2. Configure remote execution
# 3. Connect to workspace
```

### Step 7: Deploy via Terraform Cloud

#### Method 1: Manual Trigger (Recommended for First Deploy)

1. Go to Terraform Cloud workspace
2. Click "Actions" > "Start new run"
3. Add message: "Initial production deployment"
4. Review plan
5. Click "Confirm & Apply"

#### Method 2: Git Push (Automated)

```bash
# Make changes to Terraform configuration
git add terraform/environments/production/

# Commit with clear message
git commit -m "Configure production environment for x86 CX23"

# Push to Codeberg
git push origin main

# Terraform Cloud automatically:
# 1. Detects git push
# 2. Runs terraform plan
# 3. Waits for manual approval
# 4. Applies changes (if approved)
```

### Step 8: Monitor Terraform Cloud Execution

1. **Watch plan execution**:
   - Terraform Cloud > Workspace > Runs
   - View plan output
   - Check resource changes

2. **Approve and apply**:
   - Review changes carefully
   - Comment: "Approved by [Your Name]"
   - Click "Confirm & Apply"

3. **Get outputs**:
   - After apply completes
   - View "Outputs" tab
   - Note server IP address

### Step 9: Configure Ansible for Production

```bash
cd ansible

# Create production group_vars
mkdir -p inventory/group_vars/production

# Create production configuration
cat > inventory/group_vars/production/main.yml <<'EOF'
---
# Production Environment Configuration

# Domain (CHANGE to your domain)
nginx_wordpress_server_name: "yourdomain.com"

# SSL (enabled for production)
nginx_wordpress_ssl_enabled: true
nginx_wordpress_ssl_certificate_email: "your-email@example.com"

# WordPress Configuration
wordpress_db_name: "wordpress"
wordpress_db_user: "wordpress"
wordpress_table_prefix: "wp_"

# Performance Settings
nginx_wordpress_enable_fastcgi_cache: true
nginx_wordpress_enable_rate_limiting: true
nginx_wordpress_cloudflare_enabled: true

# Monitoring (all-in-one)
monitoring_all_in_one: true

# Backups
wordpress_backup_enabled: true
wordpress_backup_retention_days: 30
EOF

# Create production vault
ansible-vault create inventory/group_vars/production/vault.yml
```

**In production vault:**

```yaml
---
# Production secrets - HIGHLY SENSITIVE

# MariaDB passwords (STRONG - 32+ chars)
vault_mysql_root_password: "GENERATE_STRONG_PASSWORD_32_CHARS"
vault_wordpress_db_password: "GENERATE_STRONG_PASSWORD_32_CHARS"

# Grafana admin password
vault_grafana_admin_password: "GENERATE_STRONG_PASSWORD_16_CHARS"

# WordPress admin (for initial setup)
vault_wordpress_admin_user: "admin"
vault_wordpress_admin_password: "GENERATE_STRONG_PASSWORD_16_CHARS"
vault_wordpress_admin_email: "your-email@example.com"
```

### Step 10: Run Ansible (Manual or Automated)

#### Option A: Manual Ansible (Recommended for Start)

```bash
# Set environment
export HCLOUD_TOKEN="your-hetzner-api-token"

# Test connection
ansible -i inventory/hetzner.hcloud.yml production -m ping

# Deploy full stack
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
  --limit production \
  --ask-vault-pass

# Or deploy incrementally
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
  --limit production \
  --tags common,security \
  --ask-vault-pass

ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
  --limit production \
  --tags wordpress \
  --ask-vault-pass
```

#### Option B: GitHub Actions (Optional - Set and Forget)

**Only if you want full automation**. This is **NOT required** for "set and forget" - Terraform Cloud handles infrastructure, Ansible can be manual for the 1-2 times/month you need it.

If you choose this path, you'd need to:

1. Mirror Codeberg → GitHub (adds complexity)
2. Store `HCLOUD_TOKEN` and vault password in GitHub Secrets
3. Create `.github/workflows/ansible-deploy.yml`
4. Trigger on Terraform Cloud success webhook

**Honest assessment**: For your use case (1-2 changes/month), manual Ansible is simpler and more reliable.

---

## Testing ARM vs x86 Architecture

### Decision Criteria

| Factor | x86 (CX23) | ARM (CAX11) | Winner |
|--------|------------|-------------|--------|
| **Price** | €5.04/mo | €4.45/mo | ARM (-12%) |
| **Performance** | Tested: 3,114 req/s | TBD | TBD |
| **Availability** | Limited stock | Always available | ARM |
| **Compatibility** | 100% | ~95% (some packages) | x86 |

### Testing Process

1. **Deploy x86 staging** (already done):

   ```bash
   cd terraform/environments/staging
   terraform apply -var="architecture=x86" -var="server_type=cx23"
   ```

2. **Run benchmarks** (see [docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md](../performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md)):
   - Result: 3,114 req/s, 32ms latency, A+ grade

3. **Deploy ARM staging**:

   ```bash
   # Destroy x86
   terraform destroy

   # Deploy ARM
   terraform apply -var="architecture=arm64" -var="server_type=cax11"
   ```

4. **Run identical benchmarks**:

   ```bash
   # SSH to server
   ssh malpanez@<arm-server-ip>

   # Install ApacheBench
   sudo apt install apache2-utils

   # Run benchmark (100k requests, 100 concurrency)
   ab -n 100000 -c 100 http://127.0.0.1/
   ```

5. **Compare results**:
   - Requests/sec (throughput)
   - Response time percentiles (latency)
   - Resource usage (CPU, RAM)
   - Cost per request

6. **Make decision**:
   - If ARM within 10% of x86 performance → Choose ARM (cheaper, better availability)
   - If ARM significantly slower → Choose x86 (better performance)

7. **Update production config**:

   ```bash
   # Edit terraform/environments/production/terraform.production.tfvars
   server_type = "cax11"  # or "cx23"
   architecture = "arm64"  # or "x86"
   ```

---

## Post-Deployment

### Verify Deployment

```bash
# Get server IP
SERVER_IP="<your-production-ip>"

# Test HTTP
curl -I http://$SERVER_IP/
# Should redirect to HTTPS (via Cloudflare)

# Test HTTPS (after DNS)
curl -I https://yourdomain.com/
# Should return: HTTP/2 200

# SSH to server
ssh malpanez@$SERVER_IP

# Check all services
systemctl status nginx php8.4-fpm mariadb valkey-server \
  prometheus grafana-server loki promtail

# Check logs
journalctl -u nginx -f
journalctl -u php8.4-fpm -f
```

### Configure DNS (GoDaddy → Cloudflare)

See detailed guide: [docs/infrastructure/CLOUDFLARE_SETUP.md](../infrastructure/CLOUDFLARE_SETUP.md)

**Quick steps:**

1. **Add site to Cloudflare**:
   - Login: <https://dash.cloudflare.com>
   - Add site: yourdomain.com
   - Select Free plan

2. **Configure DNS records**:

   ```
   A     @       <production-ip>   Proxied (orange cloud)
   A     www     <production-ip>   Proxied (orange cloud)
   ```

3. **Update nameservers at GoDaddy**:
   - GoDaddy > My Products > Domains > Manage
   - Nameservers > Change
   - Use custom nameservers from Cloudflare

4. **Wait for propagation** (2-24 hours, usually 2-4 hours):

   ```bash
   dig yourdomain.com
   # Should show Cloudflare IPs
   ```

5. **Configure Cloudflare settings**:
   - SSL/TLS: Full (strict)
   - Always Use HTTPS: ON
   - HSTS: Enable
   - Caching: Standard
   - Security Level: Medium

### Install WordPress & LearnDash

1. **Complete WordPress setup**:
   - Go to: <https://yourdomain.com>
   - Follow installation wizard
   - Create admin user (use vault password)

2. **Install LearnDash Pro**:
   - Download from: <https://www.learndash.com/your-account/>
   - WordPress Admin > Plugins > Add New > Upload Plugin
   - Upload `learndash-X.X.X.zip`
   - Activate
   - Enter license key

3. **Configure plugins**:
   - Redis Cache: Enable object caching
   - Nginx Helper: Configure FastCGI cache purging
   - Cloudflare: Connect API (optional)

### Set Up Monitoring Dashboards

1. **Access Grafana**:

   ```
   URL: http://<production-ip>:3000
   User: admin
   Pass: <vault_grafana_admin_password>
   ```

2. **Import dashboards**:
   - Node Exporter Full: Dashboard ID `1860`
   - Nginx Stats: Dashboard ID `12708`
   - MariaDB: Dashboard ID `7362`

3. **Configure alerts** (optional):
   - Grafana > Alerting > Contact Points
   - Add email, Slack, or other notification channel

---

## Troubleshooting

### Issue: Terraform Cloud Can't Connect to Codeberg

**Symptoms**: Workspace shows "VCS connection failed"

**Solutions**:

1. **Check SSH key**:

   ```bash
   # Test SSH connection manually
   ssh -T git@codeberg.org -i ~/.ssh/terraform_cloud_ed25519
   # Should return: "Hi username! You've successfully authenticated..."
   ```

2. **Verify SSH key in Terraform Cloud**:
   - Organization Settings > SSH Keys
   - Ensure key is correct (copy-paste error?)

3. **Check repository URL**:
   - Must be: `git@codeberg.org:username/repo.git`
   - NOT: `https://codeberg.org/username/repo.git`

4. **Alternative: Use API-driven workflow**:
   - Simpler for single-person projects
   - Upload configuration manually

### Issue: Ansible Can't Find Servers

**Symptoms**: `ansible-inventory --graph` shows no hosts

**Solutions**:

1. **Check HCLOUD_TOKEN**:

   ```bash
   echo $HCLOUD_TOKEN
   # Should show your token

   # If empty:
   export HCLOUD_TOKEN="your-token-here"
   ```

2. **Test Hetzner API**:

   ```bash
   hcloud server list
   # Should show your servers
   ```

3. **Check server labels**:

   ```bash
   hcloud server describe <server-name>
   # Look for labels: environment, role, project
   ```

4. **Verify hcloud collection**:

   ```bash
   ansible-galaxy collection list | grep hetzner
   # Should show: hetzner.hcloud

   # If missing:
   ansible-galaxy collection install hetzner.hcloud
   ```

### Issue: Terraform State Locked

**Symptoms**: "Error acquiring state lock"

**Solutions**:

1. **Wait for current run to finish** (if running in Terraform Cloud)

2. **Force unlock** (only if run crashed):

   ```bash
   # In Terraform Cloud UI:
   # Settings > Locking > Force Unlock

   # Or via CLI:
   terraform force-unlock <lock-id>
   ```

### Issue: Services Not Starting After Ansible

**Symptoms**: `systemctl status nginx` shows "failed"

**Solutions**:

1. **Check logs**:

   ```bash
   journalctl -u nginx -n 50
   journalctl -u php8.4-fpm -n 50
   ```

2. **Common issues**:
   - Port 80/443 already in use
   - Configuration syntax error
   - Missing PHP modules

3. **Verify configuration**:

   ```bash
   # Nginx
   sudo nginx -t

   # PHP-FPM
   sudo php-fpm8.4 -t
   ```

4. **Re-run Ansible with specific role**:

   ```bash
   ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
     --tags nginx_wordpress \
     --limit production \
     --ask-vault-pass
   ```

### Issue: Cloudflare SSL Error

**Symptoms**: "ERR_SSL_VERSION_OR_CIPHER_MISMATCH"

**Solutions**:

1. **Check Cloudflare SSL mode**:
   - Must be: Full (strict)
   - NOT: Flexible or Full

2. **Verify Let's Encrypt certificate**:

   ```bash
   ssh malpanez@<server-ip>
   sudo certbot certificates

   # Should show valid certificate for yourdomain.com
   ```

3. **Manually trigger certificate renewal**:

   ```bash
   sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
   ```

4. **Wait for DNS propagation**:
   - Certificate issuance requires DNS to point to server
   - Can take 2-24 hours

---

## Next Steps

### After Successful Deployment

1. **Test WordPress**:
   - Create test post
   - Create test course (LearnDash)
   - Test user registration
   - Test payment flow (WooCommerce + Stripe)

2. **Configure backups**:
   - Verify automated backups running
   - Test restore procedure
   - Document backup location

3. **Set up alerting**:
   - Configure Grafana alerts
   - Test alert delivery (email/Slack)
   - Create runbook for common alerts

4. **Security hardening**:
   - Review firewall rules
   - Test fail2ban (attempt failed logins)
   - Verify AppArmor profiles
   - Run security audit: `lynis audit system`

5. **Performance optimization**:
   - Enable Cloudflare CDN
   - Configure WordPress object cache (Valkey)
   - Optimize database (wp-optimize plugin)
   - Monitor Grafana for bottlenecks

6. **Content creation**:
   - Design landing page
   - Create first course
   - Record lessons
   - Design certificates

### Maintenance Schedule

| Task | Frequency | Command |
|------|-----------|---------|
| **System updates** | Weekly | `ansible-playbook playbooks/update.yml` |
| **Backup verification** | Monthly | Check `/var/backups/` |
| **SSL renewal** | Automatic | Certbot timer (check: `systemctl status certbot.timer`) |
| **Security audit** | Quarterly | `lynis audit system` |
| **Dependency updates** | Monthly | Terraform: `terraform init -upgrade`<br>Ansible: `ansible-galaxy collection install --upgrade` |

---

## Summary: Recommended Workflow

### For Your Use Case

Based on your requirements (set and forget, 1-2 changes/month):

**Recommended Setup:**

```
Codeberg (private repo)
    ↓
Terraform Cloud (infrastructure automation)
    - Auto-run on git push
    - Secure secrets storage
    - Email notifications
    - Free tier sufficient
    ↓
Hetzner Cloud (servers deployed)
    ↓
Ansible MANUAL (when needed)
    - Run from your local machine
    - Only when configuration changes
    - 1-2 times per month max
    - Simple, reliable, debuggable
```

**Why NOT GitHub Actions for Ansible:**

- Adds complexity (mirror Codeberg→GitHub)
- Auto-healing can hide problems
- Manual Ansible is more reliable for rare changes
- Easier to debug when run locally

**"Set and Forget" means:**

- Terraform Cloud auto-manages infrastructure
- Secrets stored securely
- No manual Terraform commands
- Email alerts if infrastructure fails

**NOT "automate everything":**

- Manual Ansible when you actually need it
- Simpler = fewer things to break
- Better for 1-2 changes/month frequency

---

**Documentation Version:** 1.0
**Last Updated:** 2025-01-01
**Status:** Production-ready

**Related Documentation:**

- [COMPLETE_TESTING_GUIDE.md](COMPLETE_TESTING_GUIDE.md) - Detailed testing procedures
- [CLOUDFLARE_SETUP.md](../infrastructure/CLOUDFLARE_SETUP.md) - DNS migration guide
- [SYSTEM_OVERVIEW.md](../architecture/SYSTEM_OVERVIEW.md) - Architecture documentation
- [X86_STAGING_BENCHMARK_WITH_MONITORING.md](../performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md) - Performance results
