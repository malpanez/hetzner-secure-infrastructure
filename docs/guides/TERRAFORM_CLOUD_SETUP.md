# Terraform Cloud Setup Guide

**Date**: 2026-01-09
**Purpose**: Configure Terraform Cloud for remote state management and secret storage
**Benefit**: Keep secrets secure, enable team collaboration, track infrastructure changes

---

## Why Terraform Cloud?

### Benefits

1. **Remote State Storage**: No sensitive data in local files
2. **Secret Management**: Store Hetzner API token securely
3. **State Locking**: Prevent concurrent modifications
4. **Audit Trail**: Track all infrastructure changes
5. **Free Tier**: Up to 500 resources/month (we'll use <10)

---

## Step 1: Create Terraform Cloud Account (5 min)

### 1.1 Sign Up

1. Go to: <https://app.terraform.io/signup/account>
2. Create account (use same email as Cloudflare for consistency)
3. Verify email address

### 1.2 Create Organization

1. After login, click "Create Organization"
2. Organization name: `hetzner-wordpress-lms` (or your preference)
3. Email: your email address
4. Click "Create organization"

---

## Step 2: Create Workspace (5 min)

### 2.1 Create New Workspace

1. Click "New workspace"
2. Choose workflow: **CLI-driven workflow**
3. Workspace name: `wordpress-lms-production`
4. Click "Create workspace"

### 2.2 Configure Workspace Settings

Navigate to workspace settings:

**General Settings**:

- Execution Mode: **Remote**
- Terraform Working Directory: `terraform/` (if your tf files are in terraform/ subdirectory)
- Auto apply: **Disabled** (require manual approval for safety)

**Variables** (Critical - Add These):

#### Environment Variables (Sensitive)

| Variable | Value | Sensitive | Description |
|----------|-------|-----------|-------------|
| `HCLOUD_TOKEN` | `your_hetzner_api_token` | ✅ YES | Hetzner Cloud API token |
| `TF_VAR_hcloud_token` | `your_hetzner_api_token` | ✅ YES | Alternative format |

#### Terraform Variables (HCL)

| Variable | Value | Sensitive | HCL | Description |
|----------|-------|-----------|-----|-------------|
| `environment` | `production` | ❌ NO | ❌ NO | Environment name |
| `architecture` | `arm64` | ❌ NO | ❌ NO | ARM64 for 2.68x performance |
| `server_size` | `small` | ❌ NO | ❌ NO | CAX11 (2 vCPU, 4GB RAM) |
| `location` | `nbg1` | ❌ NO | ❌ NO | Nuremberg datacenter |
| `instance_number` | `1` | ❌ NO | ✅ YES | Instance number (number type) |
| `ssh_public_key_path` | `~/.ssh/github_ed25519.pub` | ❌ NO | ❌ NO | Your SSH key path |

**To add variables**:

1. Click "Variables" in workspace menu
2. Click "Add variable"
3. Select "Environment variable" or "Terraform variable"
4. Enter key, value, check "Sensitive" if needed
5. Click "Add variable"

---

## Step 3: Configure Local Terraform to Use Cloud (2 min)

### 3.1 Update backend.tf

Edit `/home/malpanez/repos/hetzner-secure-infrastructure/terraform/backend.tf`:

```hcl
# Terraform Cloud Backend Configuration
terraform {
  cloud {
    organization = "hetzner-wordpress-lms"  # Your org name from Step 1.2

    workspaces {
      name = "wordpress-lms-production"     # Your workspace name from Step 2.1
    }
  }

  required_version = ">= 1.14"
}

# Note: This replaces local backend
# Old local backend config is commented out below for reference
/*
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
}
*/
```

### 3.2 Login to Terraform Cloud from CLI

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Login to Terraform Cloud
terraform login

# This will:
# 1. Open browser to generate API token
# 2. Ask you to paste token in terminal
# 3. Save token to ~/.terraform.d/credentials.tfrc.json
```

**Alternative** (if browser doesn't open):

1. Generate token manually: <https://app.terraform.io/app/settings/tokens>
2. Create `~/.terraform.d/credentials.tfrc.json`:

```json
{
  "credentials": {
    "app.terraform.io": {
      "token": "YOUR_TERRAFORM_CLOUD_API_TOKEN_HERE"
    }
  }
}
```

### 3.3 Reinitialize Terraform

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Reinitialize with new backend
terraform init -migrate-state

# Answer "yes" when prompted to migrate state to Terraform Cloud
```

**What this does**:

- Uploads current state to Terraform Cloud
- Deletes local `terraform.tfstate` (now managed remotely)
- Configures workspace for remote execution

---

## Step 4: Verify Terraform Cloud Integration (1 min)

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Test plan with Terraform Cloud
terraform plan

# You should see:
# - "Running plan in Terraform Cloud..."
# - Plan executes remotely
# - Output shown in terminal
```

**Check Terraform Cloud UI**:

1. Go to <https://app.terraform.io>
2. Navigate to your workspace
3. Click "Runs" tab
4. You should see the plan execution

---

## Step 5: Deploy Infrastructure via Terraform Cloud (5 min)

### 5.1 Create Deployment Plan

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Create plan (executes remotely in Terraform Cloud)
terraform plan -out=tfplan

# Review plan output in terminal
```

### 5.2 Apply Plan

```bash
# Apply the plan
terraform apply

# You'll see:
# - "Running apply in Terraform Cloud..."
# - Confirmation prompt
# - Apply executes remotely
# - Server created!
```

**Monitor in Terraform Cloud UI**:

1. Go to workspace → Runs
2. Watch apply progress in real-time
3. See detailed logs
4. View state changes

### 5.3 Get Server IP

```bash
# Get outputs from remote state
terraform output

# Or specific output
terraform output -raw server_ipv4
```

---

## Step 6: Migrate DNS to Cloudflare (15 min)

Now that server is deployed, configure Cloudflare DNS.

### 6.1 Create Cloudflare Account

1. Go to: <https://dash.cloudflare.com/sign-up>
2. Use **same email as Terraform Cloud** for consistency
3. Verify email

### 6.2 Add Domain to Cloudflare

1. Click "Add a Site"
2. Enter your domain name
3. Select **Free** plan ($0/month)
4. Cloudflare scans existing DNS records

### 6.3 Get Cloudflare Nameservers

Cloudflare will provide two nameservers:

```
example1.ns.cloudflare.com
example2.ns.cloudflare.com
```

**Write these down!**

### 6.4 Update GoDaddy DNS

1. Login to: <https://account.godaddy.com>
2. Navigate: **My Products** → **Domains**
3. Find your domain → Click **Manage DNS**
4. Scroll to **Nameservers** section
5. Click **Change**
6. Select **Custom Nameservers**
7. Remove GoDaddy nameservers
8. Add Cloudflare nameservers (both)
9. Click **Save**

**DNS Propagation**: 2-48 hours (usually 2-6 hours)

### 6.5 Configure DNS Records in Cloudflare

While waiting for nameserver propagation, configure DNS:

1. Go to Cloudflare dashboard → Your domain → DNS → Records
2. Add these records:

| Type | Name | Content | Proxy Status | TTL |
|------|------|---------|--------------|-----|
| A | @ | YOUR_SERVER_IP | ✅ Proxied | Auto |
| A | www | YOUR_SERVER_IP | ✅ Proxied | Auto |
| CNAME | * | @ | ✅ Proxied | Auto (optional wildcard) |

**Important**: Enable "Proxy" (orange cloud icon) for DDoS protection + CDN!

### 6.6 Configure Cloudflare Security Settings

**SSL/TLS**:

- Navigate: SSL/TLS → Overview
- Mode: **Full (strict)**
- Always Use HTTPS: **ON**
- Minimum TLS Version: **TLS 1.2**

**Security**:

- Navigate: Security → Settings
- Security Level: **Medium**
- Bot Fight Mode: **ON**
- Challenge Passage: **30 minutes**

**Speed**:

- Navigate: Speed → Optimization
- Auto Minify: Enable **HTML**, **CSS**, **JS**
- Brotli: **ON**
- Rocket Loader: **OFF** (can break WordPress admin)

**Caching**:

- Navigate: Caching → Configuration
- Caching Level: **Standard**
- Browser Cache TTL: **4 hours**

---

## Step 7: Secure Your Secrets (Critical!)

### 7.1 Secrets Stored in Terraform Cloud

✅ **Already secure** (you added these in Step 2.2):

- Hetzner API token (`HCLOUD_TOKEN`)
- Infrastructure variables

### 7.2 Secrets Stored in Ansible Vault

✅ **Already secure**:

- All passwords encrypted with AES256
- Vault password: `8ZpBU0IW4pWNKuXm4b7hQxF5e/jmfspQYzrSSLhuXu8=`

Location: `ansible/inventory/group_vars/all/secrets.yml`

### 7.3 Secrets to Protect Locally

**DO NOT commit these files**:

```bash
# Check .gitignore includes:
cat .gitignore | grep -E "(tfvars|credentials|vault|token)"

# Should show:
# *.tfvars
# !*.tfvars.example
# .terraform/
# terraform.tfstate*
# **/secrets.yml
# .vault_pass
# ~/.terraform.d/credentials.tfrc.json
```

**Remove sensitive files from Git** (if accidentally committed):

```bash
# Remove from Git but keep locally
git rm --cached terraform/terraform.staging.tfvars
git rm --cached VAULT_SETUP_INSTRUCTIONS.md  # Contains plaintext passwords!
git commit -m "Remove sensitive files from Git"
git push
```

---

## Step 8: Verification Checklist

After completing all steps:

### Terraform Cloud

- [ ] Organization created
- [ ] Workspace created and configured
- [ ] Environment variables added (HCLOUD_TOKEN)
- [ ] Terraform variables added
- [ ] Local CLI authenticated (`terraform login`)
- [ ] State migrated to cloud (`terraform init -migrate-state`)
- [ ] Test plan executes remotely (`terraform plan`)

### Cloudflare

- [ ] Account created (same email as Terraform Cloud)
- [ ] Domain added
- [ ] Nameservers copied from Cloudflare
- [ ] GoDaddy nameservers updated
- [ ] DNS records configured (A records for @ and www)
- [ ] SSL/TLS set to "Full (strict)"
- [ ] Security settings configured

### Infrastructure

- [ ] Server deployed via Terraform Cloud
- [ ] Server IP address obtained (`terraform output server_ipv4`)
- [ ] Server accessible via SSH

---

## Managing Infrastructure Going Forward

### Daily Operations

**Check infrastructure status**:

```bash
terraform plan  # Shows any drift from desired state
```

**Deploy changes**:

```bash
# Edit terraform files
terraform plan   # Review changes
terraform apply  # Apply after confirmation
```

**View state remotely**:

```bash
terraform show   # Shows current state from Terraform Cloud
```

### Team Collaboration

If you add team members later:

1. **Invite to Terraform Cloud**:
   - Workspace → Settings → Team Access
   - Add team member email
   - Set permissions (Plan/Apply/Admin)

2. **They run**:

   ```bash
   terraform login
   terraform init
   ```

3. **Shared state automatically syncs** between team members

### Backup and Recovery

**Terraform Cloud automatically**:

- ✅ Backs up state after every apply
- ✅ Keeps version history (can roll back)
- ✅ Stores encrypted in their infrastructure

**To download state backup** (for local archive):

```bash
terraform state pull > terraform.tfstate.backup.json
```

---

## Cost Summary

| Service | Tier | Monthly Cost | What You Get |
|---------|------|--------------|--------------|
| **Terraform Cloud** | Free | €0 | 500 resources, unlimited users |
| **Cloudflare** | Free | €0 | CDN, DDoS, WAF, SSL, DNS |
| **Hetzner CAX11** | Standard | €4.05 | 2 vCPU ARM64, 4GB RAM, 40GB NVMe |
| **Total** |  | **€4.05/month** | Production-ready infrastructure! |

---

## Troubleshooting

### "Invalid Hetzner Cloud API Token"

**Fix**:

1. Check token in Terraform Cloud workspace variables
2. Ensure variable name is `HCLOUD_TOKEN` or `TF_VAR_hcloud_token`
3. Mark as "Sensitive"
4. Generate new token at: <https://console.hetzner.cloud> → Security → API tokens

### "Failed to migrate state"

**Fix**:

```bash
# Force reinit
rm -rf .terraform/
terraform init -reconfigure
```

### "Cloudflare nameservers not working"

**Check**:

```bash
# Check current nameservers
dig NS yourdomain.com +short

# Should show Cloudflare nameservers
# If still showing GoDaddy, wait 2-24 hours for propagation
```

### "DNS_PROBE_FINISHED_NXDOMAIN"

**Fix**:

- Wait for DNS propagation (2-24 hours)
- Clear browser DNS cache: chrome://net-internals/#dns
- Try different DNS server: `dig @8.8.8.8 yourdomain.com`

---

## Next Steps After Setup

Once Terraform Cloud + Cloudflare are configured:

1. **Deploy infrastructure**: `terraform apply`
2. **Run Ansible deployment**: [DEPLOY_FROM_SCRATCH.md](../DEPLOY_FROM_SCRATCH.md)
3. **Setup 2FA**: [SSH_2FA_INITIAL_SETUP.md](../security/SSH_2FA_INITIAL_SETUP.md)
4. **Create ansible automation user**: `./scripts/production-setup-today.sh`
5. **Complete OpenBao setup**: Follow script output
6. **Install WordPress plugins** (after DNS propagates)

---

## Documentation

- [DEPLOY_FROM_SCRATCH.md](../DEPLOY_FROM_SCRATCH.md) - Complete deployment guide
- [EXECUTION_GUIDE.md](../../EXECUTION_GUIDE.md) - All questions answered
- [GO_LIVE_TODAY_CHECKLIST.md](../../GO_LIVE_TODAY_CHECKLIST.md) - Quick reference

---

## Security Notes

### What's Protected

✅ **Terraform Cloud**:

- API tokens stored encrypted
- State files encrypted at rest
- TLS for all communication
- SOC 2 Type II compliant

✅ **Cloudflare**:

- DDoS protection (Layer 3/4/7)
- WAF (Web Application Firewall)
- Bot mitigation
- SSL/TLS encryption
- Rate limiting

✅ **Local**:

- `.gitignore` prevents committing secrets
- Ansible Vault encrypts passwords (AES256)
- SSH keys protected with filesystem permissions

### What to Never Commit

❌ Never commit:

- `terraform.tfvars` (contains sensitive variables)
- `terraform.tfstate*` (contains infrastructure details)
- `VAULT_SETUP_INSTRUCTIONS.md` (contains plaintext passwords)
- `~/.terraform.d/credentials.tfrc.json` (Terraform Cloud token)
- `ansible/inventory/group_vars/all/secrets.yml` (encrypted but sensitive)

---

## Ready?

Follow this order:

1. ✅ **This guide** - Setup Terraform Cloud + Cloudflare
2. ➡️ [DEPLOY_FROM_SCRATCH.md](../DEPLOY_FROM_SCRATCH.md) - Deploy infrastructure
3. ➡️ [Production setup script](../../scripts/production-setup-today.sh) - Automation setup

**Total setup time**: ~30 minutes + DNS propagation (2-48 hours)

Good luck! 🚀
