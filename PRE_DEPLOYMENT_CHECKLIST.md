# Pre-Deployment Checklist - Testing 11 Commits

## Context

Testing all changes from the last session (11 commits) that fix critical SSH lockout issues:

1. **SSH 2FA Break-glass**: malpanez user exempt from 2FA (user + group double protection)
2. **Modular PAM**: Using pamd module with substack control
3. **AppArmor complain mode**: Won't block SSH anymore
4. **Reboot detection fixed**: ansible_reboot_required variable standardized
5. **Role execution order**: SSH 2FA configured BEFORE firewall
6. **Comprehensive logging**: deploy.sh creates timestamped logs
7. **Testing infrastructure**: tflint, Terratest stubs, Molecule config
8. **GRUB safety**: Pre-checks prevent duplicate kernel params
9. **Deployment docs corrected**: cloud-init creates malpanez, not Ansible
10. **Production safety**: OpenBao bootstrap improvements
11. **Backend documentation**: R2 and OpenBao options documented

## Risk Assessment

**CRITICAL FIXES** (prevent lockout):
- ✅ AppArmor in complain mode (was blocking SSH)
- ✅ malpanez break-glass access (no 2FA required)
- ✅ SSH 2FA before firewall activation
- ✅ Reboot detection fixed (kernel params will apply)

**MEDIUM CHANGES** (improve reliability):
- ✅ Modular PAM with substack (survives system updates)
- ✅ Timestamped logging (easier troubleshooting)
- ✅ GRUB safety checks (no duplicate params)

**LOW RISK** (documentation/testing):
- ✅ Testing infrastructure (doesn't affect deployment)
- ✅ Documentation corrections (code unchanged)

## Pre-Deployment Steps

### 1. Environment Check

```bash
# Verify you're in the right directory
pwd
# Expected: /home/malpanez/repos/hetzner-secure-infrastructure

# Check HCLOUD_TOKEN is set
echo $HCLOUD_TOKEN | head -c 10
# Should show first 10 chars of token

# Verify SSH key exists
ls -l ~/.ssh/github_ed25519
# Should exist and be readable

# Check current IP (must match terraform.prod.tfvars)
curl -s ifconfig.me
# Expected: 37.228.206.5 (from ssh_allowed_ips)
```

### 2. Code Quality Check

```bash
# Run all linters
make lint

# Expected output:
# ✓ Terraform formatting OK
# ✓ tflint passed
# ✓ Ansible lint passed
# ✓ YAML lint passed
```

### 3. Review Critical Files

```bash
# Verify AppArmor is in complain mode
grep "apparmor_enforce_mode:" ansible/roles/apparmor/defaults/main.yml
# Expected: apparmor_enforce_mode: false

# Verify malpanez is break-glass user
grep -A2 "ssh_2fa_break_glass_users:" ansible/roles/ssh_2fa/defaults/main.yml
# Expected: - malpanez

# Verify ansible-automation group has no 2FA
grep -A1 "Match Group ansible-automation" ansible/roles/ssh_2fa/templates/sshd_2fa.conf.j2
# Expected: AuthenticationMethods publickey

# Verify reboot variable is standardized
grep "ansible_reboot_required" ansible/roles/security_hardening/tasks/main.yml
# Should find the variable (not reboot_required)
```

### 4. Terraform Plan Review

```bash
cd terraform

# Initialize (should be fast, local backend)
terraform init

# Plan deployment
terraform plan -var-file=terraform.prod.tfvars -out=tfplan

# Review plan carefully:
# - Should create 1 server (prod-wp-arm-01)
# - Should create DNS records if enable_cloudflare=true
# - Check server_type: cax11 (ARM64)
# - Check location: nbg1
# - Verify cloud-init will create malpanez user

# Show plan in detail
terraform show tfplan
```

## Deployment Steps (Execute Carefully)

### Step 1: Deploy Infrastructure (Terraform)

```bash
cd terraform

# Apply plan
terraform apply tfplan

# WAIT for completion (2-3 minutes)
# cloud-init runs automatically:
#   - Creates malpanez user
#   - Adds SSH key
#   - Configures sudo

# Save server IP
export SERVER_IP=$(terraform output -raw server_ipv4)
echo "Server IP: $SERVER_IP"

# CRITICAL: Wait 30 seconds for cloud-init to finish
sleep 30
```

### Step 2: Verify Initial Access (Before Ansible)

```bash
# Test SSH as malpanez (should work - cloud-init created user)
ssh -i ~/.ssh/github_ed25519 -o ConnectTimeout=10 malpanez@$SERVER_IP 'whoami && groups'

# Expected output:
# malpanez
# malpanez sudo

# If this FAILS, DO NOT proceed with Ansible
# - Check Hetzner Console for cloud-init logs
# - Verify IP address is correct
```

### Step 3: Run Ansible Deployment (MONITOR CLOSELY)

```bash
cd ../ansible

# Export HCLOUD_TOKEN for dynamic inventory
export HCLOUD_TOKEN="..."

# Run deployment with logging
./deploy.sh playbooks/site.yml

# WATCH for these critical points:
# 1. SSH 2FA role completes (malpanez added to ansible-automation group)
# 2. Firewall role activates (SSH should remain accessible)
# 3. AppArmor role completes (complain mode, not enforce)
# 4. Reboot play triggers (server will disconnect)
# 5. Ansible reconnects after reboot (should succeed)

# The deployment should take 15-25 minutes
# Log file: ansible/logs/ansible-YYYYMMDD-HHMMSS.log
```

### Step 4: Verify Access After Ansible (CRITICAL)

```bash
# Test SSH immediately after Ansible completes
ssh -i ~/.ssh/github_ed25519 malpanez@$SERVER_IP

# If SSH FAILS:
# 1. DO NOT PANIC
# 2. Access Hetzner Cloud Console (always available)
# 3. Check logs in /var/log/auth.log
# 4. Disable UFW: sudo ufw disable
# 5. Check AppArmor: sudo aa-status
# 6. Restart SSH: sudo systemctl restart sshd

# If SSH WORKS:
# - You should connect WITHOUT 2FA prompt (break-glass)
# - Check you're in ansible-automation group: groups
# - Expected: malpanez sudo ansible-automation
```

### Step 5: Verify System State

```bash
# Connected via SSH as malpanez

# 1. Check if reboot happened (uptime should be recent)
uptime
# If kernel params changed, uptime should be < 5 minutes

# 2. Verify kernel parameters applied
cat /proc/cmdline | grep -E "audit=1|apparmor=1"
# Expected: audit=1 apparmor=1 security=apparmor

# 3. Verify AppArmor is in COMPLAIN mode
sudo aa-status
# Expected: "0 profiles are in enforce mode" or all in complain mode

# 4. Verify UFW is active with correct rules
sudo ufw status numbered
# Expected: Rules for SSH (22), HTTP (80), HTTPS (443)
# SSH rule should allow from 37.228.206.5/32

# 5. Check PAM configuration
cat /etc/pam.d/sshd | grep sshd-2fa
# Expected: auth substack sshd-2fa

# 6. Verify services are running
sudo systemctl status nginx mysql fail2ban openbao --no-pager
# All should be "active (running)"
```

### Step 6: Test Services

```bash
# On your local machine

# 1. Test HTTP (should redirect to HTTPS)
curl -I http://$SERVER_IP
# Expected: 301 or 302 redirect to https://

# 2. Test HTTPS (may have self-signed cert warning)
curl -k https://$SERVER_IP
# Expected: WordPress page HTML

# 3. Test WordPress admin
# Open browser: http://$SERVER_IP/wp-admin
# Should redirect to HTTPS and show login page

# 4. Test OpenBao UI (if accessible)
# Open browser: https://$SERVER_IP:8200
# Should show OpenBao interface

# 5. Test Grafana (if accessible)
# Open browser: http://$SERVER_IP:3000
# Should show Grafana login
```

### Step 7: Review Deployment Log

```bash
cd ansible

# Check latest log for errors
less logs/latest.log

# Search for failures
grep -i "failed\|error" logs/latest.log

# Check if reboot happened
grep -i "reboot" logs/latest.log

# Verify all roles completed
grep "PLAY RECAP" logs/latest.log
# Should show "failed=0" for all hosts
```

## Success Criteria

All of these must be TRUE:

- ✅ SSH access as malpanez works WITHOUT 2FA
- ✅ malpanez is in ansible-automation group
- ✅ AppArmor is in complain mode (not enforce)
- ✅ Kernel parameters applied (audit=1, apparmor=1)
- ✅ Reboot happened (uptime is recent)
- ✅ UFW is active with SSH rule from management IP
- ✅ All services running (nginx, mysql, fail2ban, openbao)
- ✅ WordPress accessible via HTTP/HTTPS
- ✅ Ansible log shows "failed=0"
- ✅ No errors in /var/log/auth.log

## Failure Recovery

### If SSH is Blocked

1. **Access Hetzner Console**:
   - Login to cloud.hetzner.com
   - Navigate to your server
   - Click "Console" button
   - Login as root (password in Hetzner console)

2. **Diagnose Issue**:
   ```bash
   # Check auth log for SSH denials
   tail -100 /var/log/auth.log

   # Check AppArmor denials
   dmesg | grep -i apparmor

   # Check UFW status
   ufw status verbose

   # Check SSH service
   systemctl status sshd
   ```

3. **Emergency Recovery**:
   ```bash
   # Disable UFW temporarily
   ufw disable

   # Put AppArmor in complain mode
   aa-complain /etc/apparmor.d/*

   # Restart SSH
   systemctl restart sshd

   # Try SSH from local machine again
   ```

### If Services Don't Start

```bash
# Check service status
systemctl status nginx mysql fail2ban openbao

# Check service logs
journalctl -u nginx -n 50
journalctl -u mysql -n 50
journalctl -u openbao -n 50

# Check ports
ss -tlnp | grep -E "22|80|443|3306|8200"
```

### If WordPress Shows Errors

```bash
# Check nginx error log
tail -50 /var/log/nginx/error.log

# Check PHP-FPM
systemctl status php8.3-fpm

# Check MySQL connection
mysql -u root -p -e "SHOW DATABASES;"
```

## Rollback Plan

If deployment fails completely and you can't recover:

```bash
# Destroy server (keeps Terraform state clean)
cd terraform
terraform destroy -var-file=terraform.prod.tfvars

# Review what went wrong
cd ../ansible
cat logs/latest.log

# Fix the issue in code
# Re-test with Vagrant first if possible

# Try deployment again
```

## Post-Deployment Tasks

Once everything works:

1. **Capture QR codes for 2FA** (if setting up for other users)
2. **Document the server IP** in your password manager
3. **Setup OpenBao credential rotation** (90-day cycle)
4. **Configure WordPress** (install themes/plugins)
5. **Plan DNS migration** to Cloudflare (currently on GoDaddy)
6. **Setup automated backups** (database + files)
7. **Test recovery procedures** (restore from backup)

## Notes for This Deployment

- **First deployment**: Testing all 11 commits together
- **Server destroyed**: Starting from scratch
- **Backend**: Local (terraform.tfstate on local machine)
- **DNS**: Still on GoDaddy (Cloudflare migration pending)
- **Architecture**: ARM64 (cax11 - Ampere Altra)
- **Critical fix**: AppArmor complain mode (was blocking SSH)
- **Critical fix**: malpanez break-glass (no 2FA lockout)
- **Critical fix**: Reboot detection works now

## Questions Before Starting?

Before running `terraform apply`, ask yourself:

1. Is my current IP (curl ifconfig.me) matching terraform.prod.tfvars?
2. Do I have HCLOUD_TOKEN exported?
3. Do I have access to Hetzner Cloud Console (emergency access)?
4. Have I read the recovery procedures above?
5. Am I ready to monitor the Ansible deployment for 20 minutes?
6. Do I have the SSH key file at ~/.ssh/github_ed25519?

If all YES → proceed with deployment.
If any NO → fix it first.
