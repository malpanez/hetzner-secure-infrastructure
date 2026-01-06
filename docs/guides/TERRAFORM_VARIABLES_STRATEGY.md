# Terraform Variables Strategy - Definitive Guide

**Date**: 2026-01-02
**Purpose**: Clear, consistent strategy for managing Terraform variables
**Status**: This is the ONLY way to do it - no alternatives, no confusion

---

## The Rule (Simple)

**ONE clear rule**:

| Type of Data | Where to Store It | Why |
|--------------|-------------------|-----|
| **Secrets** (API tokens, passwords) | Terraform Cloud Variables | Encrypted, never visible in logs |
| **Configuration** (server size, location) | `terraform.prod.tfvars` file | Version controlled, trackable changes |

---

## What Goes Where

### ✅ Terraform Cloud Variables (Secrets Only)

**Add these in Terraform Cloud UI** → Your Workspace → Variables:

| Variable Name | Value | Category | Sensitive | HCL |
|---------------|-------|----------|-----------|-----|
| `HCLOUD_TOKEN` | `your_actual_token_here` | **env** | ✅ YES | ❌ NO |

**That's it. Just ONE variable.**

### ✅ terraform.prod.tfvars File (All Other Config)

**Add these in `terraform.prod.tfvars` file** (version controlled):

```hcl
# Server Configuration
environment      = "prod"
architecture     = "arm64"
server_size      = "small"
location         = "nbg1"
instance_number  = 1
admin_username   = "malpanez"

# SSH Configuration
ssh_public_key  = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIPpkXKskfAW7Hm2SVJbPYxYavcDQfANwPB/xZVs4198u miguel@homelabforge.dev"
ssh_port        = 22
ssh_allowed_ips = ["0.0.0.0/0"]

# HTTP/HTTPS
allow_http  = true
allow_https = true

# DNS
domain              = "twomindstrading.com"
reverse_dns_enabled = true
enable_cloudflare   = false

# Optional Features
volume_size        = 0
enable_floating_ip = false
prevent_destroy    = true

# Labels
labels = {
  project     = "wordpress-trading-academy"
  owner       = "malpanez"
  environment = "production"
}
```

---

## Why This Way?

### Terraform Cloud Variables (Secrets)

- ✅ Encrypted at rest
- ✅ Never appear in Terraform logs
- ✅ Can't accidentally commit to Git
- ✅ Easy to rotate (change in UI, no code change)

### tfvars File (Config)

- ✅ Version controlled (track why you changed from x86 to ARM64)
- ✅ Reviewable in Git diffs
- ✅ Documented (comments explain decisions)
- ✅ Rollback-able (git revert if config breaks something)

---

## Complete Setup Instructions

### Step 1: Add Secret to Terraform Cloud (ONE TIME - 2 min)

1. Go to: <https://app.terraform.io>
2. Navigate: `twomindstrading` org → `twomindstrading-production` workspace
3. Click **Variables** in left menu
4. Click **+ Add variable**
5. Fill in:
   - **Variable category**: Environment variable
   - **Key**: `HCLOUD_TOKEN`
   - **Value**: Your Hetzner API token (from <https://console.hetzner.cloud> → Security → API tokens)
   - **Sensitive**: ✅ Check this box
   - **Description**: Terraform Hetzner API Key
6. Click **Add variable**

**Done. Never touch this again unless rotating the token.**

### Step 2: Use terraform.prod.tfvars File (EVERY DEPLOYMENT)

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Plan with tfvars file
terraform plan -var-file=terraform.prod.tfvars

# Apply with tfvars file
terraform apply -var-file=terraform.prod.tfvars
```

**That's it. Always use `-var-file=terraform.prod.tfvars`**

---

## Do NOT Add These to Terraform Cloud

❌ **DO NOT** add these as Terraform Cloud variables:

- `environment`
- `architecture`
- `server_size`
- `location`
- `instance_number`
- `ssh_public_key`
- Any other non-secret config

**Why?** Because these belong in version control, not in a UI.

---

## Workflow

### Daily Operations

```bash
# 1. Edit infrastructure config
vim terraform/terraform.prod.tfvars

# 2. Review your changes
git diff terraform/terraform.prod.tfvars

# 3. Plan deployment
terraform plan -var-file=terraform.prod.tfvars

# 4. Apply
terraform apply -var-file=terraform.prod.tfvars

# 5. Commit config changes
git add terraform/terraform.prod.tfvars
git commit -m "Update server config: Changed to ARM64 for better performance"
git push
```

### Token Rotation (Rare - Maybe Once a Year)

```bash
# 1. Generate new token in Hetzner Cloud
# 2. Update in Terraform Cloud UI (workspace → Variables → HCLOUD_TOKEN)
# 3. Test: terraform plan -var-file=terraform.prod.tfvars
```

---

## What If I Want to Add a New Variable?

### Ask Yourself: "Is this a secret?"

**YES - It's a secret** (password, API token):
→ Add to **Terraform Cloud** as **environment variable**
→ Mark as **Sensitive**

**NO - It's just config** (server size, location):
→ Add to **terraform.prod.tfvars** file
→ Commit to Git

---

## Example: Adding Cloudflare

When you're ready to enable Cloudflare:

### Secret (Cloudflare API Token)

**Add to Terraform Cloud**:

- Key: `CLOUDFLARE_API_TOKEN`
- Value: Your Cloudflare token
- Category: Environment variable
- Sensitive: ✅ YES

### Config (Enable Cloudflare)

**Add to terraform.prod.tfvars**:

```hcl
enable_cloudflare = true  # Change from false to true
```

Then deploy:

```bash
terraform plan -var-file=terraform.prod.tfvars
terraform apply -var-file=terraform.prod.tfvars
```

---

## Summary: The Complete Picture

### Terraform Cloud (UI)

```
Variables:
└── HCLOUD_TOKEN (env, sensitive) ← ONLY THIS
```

### terraform.prod.tfvars (File in Git)

```hcl
environment      = "prod"
architecture     = "arm64"
server_size      = "small"
location         = "nbg1"
instance_number  = 1
# ... all other config ...
```

### Deployment Command (ALWAYS)

```bash
terraform apply -var-file=terraform.prod.tfvars
```

---

## Why Was I Confused?

The Terraform Cloud Setup guide mentioned adding **Terraform variables** to the UI. That was **optional** - you can do it either way:

**Option A** (What I recommend - SIMPLER):

- Secrets in Terraform Cloud
- Config in tfvars file
- Use: `terraform apply -var-file=terraform.prod.tfvars`

**Option B** (Also valid, but more complex):

- Secrets in Terraform Cloud
- Config ALSO in Terraform Cloud
- Use: `terraform apply` (no -var-file needed)

**Option A is simpler** because:

- Version control for config
- One source of truth (the file)
- Easy to see what changed

---

## Final Answer

**What you have now:**

- ✅ `HCLOUD_TOKEN` in Terraform Cloud ← CORRECT
- ✅ `terraform.prod.tfvars` file exists ← CORRECT

**What to do:**

1. Always deploy with: `terraform apply -var-file=terraform.prod.tfvars`
2. Never add non-secret variables to Terraform Cloud UI
3. Commit terraform.prod.tfvars to Git

**This is the way. No exceptions. No alternatives.**

---

## Verification Checklist

Before deploying, verify:

- [ ] Terraform Cloud has ONLY `HCLOUD_TOKEN` variable
- [ ] `terraform.prod.tfvars` exists and has all config
- [ ] No other variables in Terraform Cloud UI
- [ ] You use `-var-file=terraform.prod.tfvars` when running terraform

---

**Status**: This is the definitive, final answer. No more confusion.
