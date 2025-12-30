# Troubleshooting Guide

> **Common issues, solutions, and debugging procedures for Hetzner Secure Infrastructure**

## Table of Contents

- [Quick Diagnostics](#quick-diagnostics)
- [SSH Access Issues](#ssh-access-issues)
- [Terraform/OpenTofu Issues](#terraformopentofu-issues)
- [Ansible Deployment Issues](#ansible-deployment-issues)
- [AppArmor Issues](#apparmor-issues)
- [2FA Authentication Issues](#2fa-authentication-issues)
- [Firewall Issues](#firewall-issues)
- [Fail2ban Issues](#fail2ban-issues)
- [Performance Issues](#performance-issues)
- [Recovery Procedures](#recovery-procedures)

---

## Quick Diagnostics

### Health Check Script

Run this script to quickly diagnose common issues:

```bash
#!/bin/bash
# health-check.sh - Quick system diagnostics

echo "=== System Health Check ==="
echo

# SSH Service
echo "[1/10] Checking SSH service..."
sudo systemctl status sshd >/dev/null 2>&1 && echo "✅ SSH is running" || echo "❌ SSH is NOT running"

# Firewall
echo "[2/10] Checking firewall..."
sudo ufw status | grep -q "Status: active" && echo "✅ UFW is active" || echo "❌ UFW is NOT active"

# Fail2ban
echo "[3/10] Checking Fail2ban..."
sudo systemctl status fail2ban >/dev/null 2>&1 && echo "✅ Fail2ban is running" || echo "❌ Fail2ban is NOT running"

# AppArmor
echo "[4/10] Checking AppArmor..."
sudo aa-status >/dev/null 2>&1 && echo "✅ AppArmor is loaded" || echo "❌ AppArmor is NOT loaded"

# Disk Space
echo "[5/10] Checking disk space..."
df -h / | awk 'NR==2 {print "💾 Disk usage: " $5 " used, " $4 " available"}'

# Memory
echo "[6/10] Checking memory..."
free -h | awk 'NR==2 {print "🧠 Memory: " $3 " used, " $7 " available"}'

# CPU Load
echo "[7/10] Checking CPU load..."
uptime | awk '{print "⚙️  Load average: " $(NF-2) $(NF-1) $NF}'

# Updates
echo "[8/10] Checking for updates..."
sudo apt update -qq 2>/dev/null
UPDATES=$(apt list --upgradable 2>/dev/null | grep -c upgradable)
echo "📦 $UPDATES package(s) available for update"

# Security Updates
echo "[9/10] Checking for security updates..."
SEC_UPDATES=$(apt list --upgradable 2>/dev/null | grep -c security)
echo "🔒 $SEC_UPDATES security update(s) available"

# Failed Login Attempts
echo "[10/10] Checking failed login attempts..."
FAILED=$(sudo grep "Failed password" /var/log/auth.log | tail -10 | wc -l)
echo "🚫 $FAILED recent failed login attempts"

echo
echo "=== Health Check Complete ==="
```

### Log Collection

Collect all relevant logs for troubleshooting:

```bash
#!/bin/bash
# collect-logs.sh - Gather diagnostic information

TIMESTAMP=$(date +%Y%m%d-%H%M%S)
LOG_DIR="/tmp/diagnostics-$TIMESTAMP"

mkdir -p "$LOG_DIR"

echo "Collecting diagnostic information to $LOG_DIR..."

# System info
uname -a > "$LOG_DIR/system-info.txt"
df -h > "$LOG_DIR/disk-usage.txt"
free -h > "$LOG_DIR/memory-usage.txt"

# Service status
systemctl status sshd > "$LOG_DIR/ssh-status.txt" 2>&1
systemctl status fail2ban > "$LOG_DIR/fail2ban-status.txt" 2>&1
systemctl status ufw > "$LOG_DIR/ufw-status.txt" 2>&1

# AppArmor
sudo aa-status > "$LOG_DIR/apparmor-status.txt" 2>&1

# Firewall
sudo ufw status verbose > "$LOG_DIR/ufw-rules.txt" 2>&1

# Fail2ban
sudo fail2ban-client status > "$LOG_DIR/fail2ban-overview.txt" 2>&1
sudo fail2ban-client status sshd > "$LOG_DIR/fail2ban-sshd.txt" 2>&1

# Logs
sudo cp /var/log/auth.log "$LOG_DIR/" 2>/dev/null
sudo cp /var/log/fail2ban.log "$LOG_DIR/" 2>/dev/null
sudo journalctl -u ssh -n 100 > "$LOG_DIR/ssh-journal.txt" 2>&1

# Create archive
tar czf "$LOG_DIR.tar.gz" -C /tmp "diagnostics-$TIMESTAMP"
echo "Diagnostics saved to: $LOG_DIR.tar.gz"
```

---

## SSH Access Issues

### Issue: "Connection refused" or "Connection timed out"

**Symptoms:**
```
ssh: connect to host X.X.X.X port 22: Connection refused
# or
ssh: connect to host X.X.X.X port 22: Connection timed out
```

**Diagnosis:**

1. **Check if SSH service is running:**
   ```bash
   # Via Hetzner Console
   sudo systemctl status sshd
   ```

2. **Check firewall rules:**
   ```bash
   # UFW
   sudo ufw status verbose

   # Hetzner Cloud Firewall
   # Check via Hetzner Cloud Console or CLI
   hcloud firewall describe <firewall-id>
   ```

3. **Check SSH is listening:**
   ```bash
   sudo ss -tlnp | grep :22
   ```

**Solutions:**

**Solution 1: Restart SSH service**
```bash
sudo systemctl restart sshd
sudo systemctl status sshd
```

**Solution 2: Fix firewall rules**
```bash
# UFW
sudo ufw allow 22/tcp
sudo ufw reload

# Verify
sudo ufw status verbose
```

**Solution 3: Check Hetzner Cloud Firewall**
```bash
# Via Terraform
cd terraform/environments/production
tofu plan
tofu apply

# Or via Hetzner CLI
hcloud firewall add-rule <firewall-id> --direction in --protocol tcp --port 22 --source-ip 0.0.0.0/0
```

**Solution 4: Fix SSH configuration**
```bash
# Validate SSH config
sudo sshd -t

# Check for syntax errors
sudo sshd -T | grep -i port
```

### Issue: "Permission denied (publickey)"

**Symptoms:**
```
miguel@X.X.X.X: Permission denied (publickey).
```

**Diagnosis:**

1. **Check authorized_keys:**
   ```bash
   # Via Hetzner Console
   cat ~/.ssh/authorized_keys
   ls -la ~/.ssh/authorized_keys
   ```

2. **Check SSH logs:**
   ```bash
   sudo journalctl -u ssh -n 50 | grep "Authentication"
   sudo tail -f /var/log/auth.log
   ```

3. **Verify SSH key locally:**
   ```bash
   # On your local machine
   ssh-add -l
   cat ~/.ssh/id_ed25519_sk.pub
   ```

**Solutions:**

**Solution 1: Re-deploy authorized_keys via Ansible**
```bash
cd ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags ssh
```

**Solution 2: Fix permissions**
```bash
# Via Hetzner Console
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
chown -R $USER:$USER ~/.ssh
```

**Solution 3: Add key manually (temporary)**
```bash
# Via Hetzner Console
echo "YOUR_PUBLIC_KEY" >> ~/.ssh/authorized_keys
chmod 600 ~/.ssh/authorized_keys
```

**Solution 4: Check AppArmor isn't blocking**
```bash
sudo aa-status | grep sshd
sudo aa-notify -s 1 -v

# Temporarily put in complain mode
sudo aa-complain /etc/apparmor.d/usr.sbin.sshd
sudo systemctl restart sshd

# Test SSH, then re-enable
sudo aa-enforce /etc/apparmor.d/usr.sbin.sshd
```

### Issue: "Keyboard-interactive authentication failed"

**Symptoms:**
```
Authenticated with partial success.
keyboard-interactive/pam:
```
Then hangs or fails.

**Diagnosis:**

1. **Check 2FA is properly configured:**
   ```bash
   # Via Hetzner Console
   test -f ~/.google_authenticator && echo "TOTP configured" || echo "TOTP NOT configured"
   ls -la /dev/hidraw*  # For Yubikey
   ```

2. **Check PAM configuration:**
   ```bash
   sudo cat /etc/pam.d/sshd | grep google_authenticator
   ```

**Solutions:**

**Solution 1: Re-run 2FA setup**
```bash
# Via Hetzner Console
sudo /usr/local/bin/setup-2fa-yubikey.sh $USER
```

**Solution 2: Temporarily disable 2FA**
```bash
# EMERGENCY ONLY - Re-enable immediately after fixing
sudo sed -i 's/^auth required pam_google_authenticator.so/#&/' /etc/pam.d/sshd
sudo systemctl restart sshd

# After SSH access restored, re-enable:
sudo sed -i 's/^#auth required pam_google_authenticator.so/auth required pam_google_authenticator.so/' /etc/pam.d/sshd
sudo systemctl restart sshd
```

**Solution 3: Check Yubikey permissions**
```bash
# Add user to plugdev group
sudo usermod -aG plugdev $USER

# Fix hidraw permissions
sudo chmod 666 /dev/hidraw*
```

### Issue: "Too many authentication failures"

**Symptoms:**
```
Received disconnect from X.X.X.X port 22:2: Too many authentication failures
```

**Diagnosis:**

SSH is trying too many keys before the correct one.

**Solutions:**

**Solution 1: Specify the key explicitly**
```bash
ssh -i ~/.ssh/id_ed25519_sk miguel@X.X.X.X
```

**Solution 2: Configure SSH client**
```bash
# ~/.ssh/config
Host hetzner-server
  HostName X.X.X.X
  User miguel
  IdentityFile ~/.ssh/id_ed25519_sk
  IdentitiesOnly yes
```

Then connect:
```bash
ssh hetzner-server
```

**Solution 3: Clear SSH agent**
```bash
ssh-add -D  # Remove all keys
ssh-add ~/.ssh/id_ed25519_sk  # Add only the needed key
```

### Issue: Locked out completely

**Symptoms:**
Cannot SSH into server, no alternative access method.

**Solutions:**

**Solution 1: Use Hetzner Console (Web-based)**
1. Log into Hetzner Cloud Console
2. Select your server
3. Click "Console" button
4. Log in with user credentials
5. Fix SSH configuration

**Solution 2: Enable Rescue Mode**
```bash
# Via Hetzner CLI
hcloud server enable-rescue <server-id>
hcloud server reset <server-id>

# SSH into rescue system
ssh root@<server-ip>

# Mount main partition
mkdir /mnt/main
mount /dev/sda1 /mnt/main

# Fix SSH config
nano /mnt/main/etc/ssh/sshd_config

# Reboot into normal mode
hcloud server disable-rescue <server-id>
reboot
```

**Solution 3: Rebuild from Terraform**
```bash
cd terraform/environments/production
tofu destroy -target=hcloud_server.main
tofu apply
```

---

## Terraform/OpenTofu Issues

### Issue: "Error: Backend initialization required"

**Symptoms:**
```
Error: Backend initialization required, please run "tofu init"
```

**Solutions:**

```bash
cd terraform/environments/production
tofu init -reconfigure
```

### Issue: "Error: Backend configuration changed"

**Symptoms:**
```
Error: Backend configuration changed

The backend configuration has changed. Run "tofu init" to migrate the state.
```

**Solutions:**

**Solution 1: Migrate state**
```bash
tofu init -migrate-state
```

**Solution 2: Reconfigure backend**
```bash
tofu init -reconfigure
```

**Solution 3: Force copy**
```bash
tofu init -force-copy
```

### Issue: "Error: Invalid provider credentials"

**Symptoms:**
```
Error: error getting server: invalid input in 'Authorization' header (invalid_input)
```

**Diagnosis:**

```bash
# Check environment variable
echo $HCLOUD_TOKEN

# Verify token is valid
hcloud server list
```

**Solutions:**

```bash
# Set token
export HCLOUD_TOKEN="your-hetzner-api-token"

# Or use .envrc with direnv
echo 'export HCLOUD_TOKEN="your-token"' > .envrc
direnv allow
```

### Issue: "Error: Resource already exists"

**Symptoms:**
```
Error: server with name "prod-server-1" already exists
```

**Diagnosis:**

Resource exists in Hetzner but not in Terraform state.

**Solutions:**

**Solution 1: Import existing resource**
```bash
tofu import hcloud_server.main <server-id>
```

**Solution 2: Remove from Hetzner Cloud**
```bash
# Via CLI
hcloud server delete <server-id>

# Or via console
# Then re-run tofu apply
```

**Solution 3: Use unique names**
```bash
# terraform.tfvars
server_name = "prod-server-2"
```

### Issue: State lock error

**Symptoms:**
```
Error: Error acquiring the state lock
Lock Info:
  ID:        xxx
  Path:      xxx
  Operation: OperationTypeApply
```

**Solutions:**

**Solution 1: Wait for lock to release**
```bash
# Another process may be running
# Wait and retry
```

**Solution 2: Force unlock (DANGEROUS)**
```bash
# Only if you're SURE no other process is running
tofu force-unlock <lock-id>
```

---

## Ansible Deployment Issues

### Issue: "Host unreachable"

**Symptoms:**
```
fatal: [X.X.X.X]: UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host via ssh"}
```

**Diagnosis:**

1. **Test SSH manually:**
   ```bash
   ssh miguel@X.X.X.X
   ```

2. **Check inventory:**
   ```bash
   ansible-inventory -i inventory/hetzner.yml --list
   ```

**Solutions:**

**Solution 1: Update inventory**
```bash
cd terraform/environments/production
tofu output -json > ../../../ansible/inventory/terraform-output.json

cd ../../../ansible
ansible-inventory -i inventory/hetzner.yml --list
```

**Solution 2: Specify SSH key**
```bash
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml \
  --private-key ~/.ssh/id_ed25519_sk
```

**Solution 3: Test connectivity**
```bash
ansible all -i inventory/hetzner.yml -m ping
```

### Issue: "Authentication or permission failure"

**Symptoms:**
```
fatal: [X.X.X.X]: FAILED! => {"msg": "to use the 'ssh' connection type with passwords, you must install the sshpass program"}
```

**Solutions:**

Ansible is trying password auth. Ensure SSH key is configured:

```bash
# ansible.cfg
[defaults]
private_key_file = ~/.ssh/id_ed25519_sk
```

Or specify on command line:
```bash
ansible-playbook ... --private-key ~/.ssh/id_ed25519_sk
```

### Issue: "Privilege escalation required"

**Symptoms:**
```
fatal: [X.X.X.X]: FAILED! => {"msg": "Missing sudo password"}
```

**Solutions:**

**Solution 1: Provide sudo password**
```bash
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --ask-become-pass
```

**Solution 2: Configure passwordless sudo**
```bash
# Via sudo config (already done by common role)
# Verify:
ssh miguel@X.X.X.X "sudo -n true" && echo "Passwordless sudo works" || echo "Sudo requires password"
```

### Issue: "Tasks timing out"

**Symptoms:**
```
fatal: [X.X.X.X]: FAILED! => {"msg": "Timeout (12s) waiting for privilege escalation prompt"}
```

**Solutions:**

**Solution 1: Increase timeout**
```bash
# ansible.cfg
[defaults]
timeout = 60
```

**Solution 2: Check SSH multiplexing**
```bash
# ansible.cfg
[ssh_connection]
ssh_args = -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

### Issue: AppArmor role fails

**Symptoms:**
```
TASK [apparmor : Load AppArmor profiles] ***
fatal: [X.X.X.X]: FAILED! => {"changed": false, "msg": "apparmor_parser: Unable to replace ..."}
```

**Diagnosis:**

```bash
# Check syntax
sudo apparmor_parser -QK /etc/apparmor.d/usr.sbin.sshd
```

**Solutions:**

**Solution 1: Fix profile syntax**
```bash
# Test profile
sudo apparmor_parser -QK /etc/apparmor.d/usr.sbin.sshd

# View errors
sudo dmesg | grep -i apparmor
```

**Solution 2: Run in complain mode first**
```bash
# ansible/roles/apparmor/defaults/main.yml
apparmor_enforce: false  # Use complain mode

# Re-run playbook
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags apparmor

# Monitor for violations
sudo aa-notify -s 1 -v

# Switch to enforce
apparmor_enforce: true
```

---

## AppArmor Issues

### Issue: Service denied by AppArmor

**Symptoms:**
```
apparmor="DENIED" operation="open" profile="/usr/sbin/sshd" name="/some/file" pid=1234
```

**Diagnosis:**

1. **Check AppArmor logs:**
   ```bash
   sudo dmesg | grep -i apparmor
   sudo journalctl | grep -i apparmor
   sudo aa-notify -s 1 -v
   ```

2. **Check profile mode:**
   ```bash
   sudo aa-status | grep sshd
   ```

**Solutions:**

**Solution 1: Put profile in complain mode**
```bash
sudo aa-complain /etc/apparmor.d/usr.sbin.sshd
sudo systemctl restart sshd

# Test functionality
# Review logs for denials
sudo aa-notify -s 1 -v

# Update profile to allow needed operations
sudo nano /etc/apparmor.d/usr.sbin.sshd

# Re-enable enforce mode
sudo aa-enforce /etc/apparmor.d/usr.sbin.sshd
```

**Solution 2: Update profile**
```bash
# Add missing rules
sudo nano /etc/apparmor.d/usr.sbin.sshd

# Example: Allow reading specific file
/some/file r,

# Reload profile
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.sshd
```

**Solution 3: Use aa-logprof**
```bash
# Generate rules from logs
sudo aa-logprof

# Follow prompts to allow/deny operations
# This will update the profile automatically
```

### Issue: Profile won't load

**Symptoms:**
```
AppArmor parser error for /etc/apparmor.d/usr.sbin.sshd in profile /usr/sbin/sshd at line XX: syntax error
```

**Solutions:**

```bash
# Validate syntax
sudo apparmor_parser -QK /etc/apparmor.d/usr.sbin.sshd

# Common syntax errors:
# - Missing comma after rule
# - Unmatched braces {}
# - Invalid capability name
# - Typo in include path

# Compare with working profile
sudo apparmor_parser -QK /etc/apparmor.d/bin.ping
```

---

## 2FA Authentication Issues

### Issue: TOTP code not accepted

**Symptoms:**
```
Password:
Verification code:
Permission denied, please try again.
```

**Diagnosis:**

1. **Check time synchronization:**
   ```bash
   # TOTP requires accurate time
   timedatectl status
   ```

2. **Verify Google Authenticator is configured:**
   ```bash
   test -f ~/.google_authenticator && echo "Configured" || echo "Not configured"
   cat ~/.google_authenticator
   ```

**Solutions:**

**Solution 1: Sync time**
```bash
# On server
sudo systemctl restart systemd-timesyncd
sudo timedatectl set-ntp true
timedatectl status

# On Windows (PowerShell as admin)
w32tm /resync
```

**Solution 2: Use backup codes**
```bash
# Backup codes are in ~/.google_authenticator
# Via Hetzner Console:
cat ~/.google_authenticator | grep "^[0-9]"
```

**Solution 3: Regenerate 2FA**
```bash
# Via Hetzner Console
rm ~/.google_authenticator
/usr/local/bin/setup-2fa-yubikey.sh $USER
```

### Issue: Yubikey not detected

**Symptoms:**
```
Enter authenticator response:
[No response when touching Yubikey]
```

**Diagnosis:**

```bash
# Check hidraw devices
ls -la /dev/hidraw*

# Check permissions
getfacl /dev/hidraw0
```

**Solutions:**

**Solution 1: Fix permissions**
```bash
sudo chmod 666 /dev/hidraw*

# Or add user to plugdev group
sudo usermod -aG plugdev $USER
```

**Solution 2: Check udev rules**
```bash
# Create udev rule for Yubikey
sudo nano /etc/udev/rules.d/70-yubikey.rules

# Add:
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="1050", MODE="0666"

# Reload
sudo udevadm control --reload-rules
sudo udevadm trigger
```

**Solution 3: Verify AppArmor allows hidraw**
```bash
sudo aa-status | grep sshd

# Check profile
sudo grep hidraw /etc/apparmor.d/usr.sbin.sshd

# Should see:
/dev/hidraw* rw,
```

### Issue: 2FA breaks sudo

**Symptoms:**
```
sudo: PAM account management error: Authentication service cannot retrieve authentication info
```

**Solutions:**

**Solution 1: Fix PAM config for sudo**
```bash
# /etc/pam.d/sudo should NOT have google_authenticator
sudo nano /etc/pam.d/sudo

# Remove or comment out:
# auth required pam_google_authenticator.so
```

**Solution 2: Use nullok for sudo**
```bash
# /etc/pam.d/sudo
auth required pam_google_authenticator.so nullok
```

---

## Firewall Issues

### Issue: Firewall blocking legitimate traffic

**Symptoms:**
Service works when firewall is disabled but not when enabled.

**Diagnosis:**

```bash
# Check UFW logs
sudo tail -f /var/log/ufw.log

# Check firewall rules
sudo ufw status numbered
```

**Solutions:**

**Solution 1: Add missing rule**
```bash
sudo ufw allow <port>/tcp comment 'Service description'
sudo ufw reload
```

**Solution 2: Verify rule order**
```bash
# Rules are processed in order
# More specific rules should come before general ones
sudo ufw status numbered

# Delete rule
sudo ufw delete <number>

# Re-add in correct order
sudo ufw insert 1 allow from <specific-ip> to any port 22
```

### Issue: Cannot enable UFW

**Symptoms:**
```
ERROR: problem running ufw-init
```

**Solutions:**

```bash
# Reset UFW
sudo ufw --force reset

# Reconfigure
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw limit 22/tcp
sudo ufw enable
```

### Issue: Accidentally locked out by firewall

**Solutions:**

**Via Hetzner Console:**
```bash
# Disable UFW
sudo ufw disable

# Fix rules
sudo ufw allow 22/tcp
sudo ufw enable
```

---

## Fail2ban Issues

### Issue: Fail2ban not banning

**Symptoms:**
Multiple failed SSH attempts but no bans.

**Diagnosis:**

```bash
# Check Fail2ban status
sudo fail2ban-client status sshd

# Check logs
sudo tail -f /var/log/fail2ban.log

# Test filter
sudo fail2ban-regex /var/log/auth.log /etc/fail2ban/filter.d/sshd.conf
```

**Solutions:**

**Solution 1: Verify configuration**
```bash
# Check jail
sudo fail2ban-client get sshd maxretry
sudo fail2ban-client get sshd findtime
sudo fail2ban-client get sshd bantime

# Should be:
# maxretry = 3
# findtime = 600
# bantime = 3600
```

**Solution 2: Restart Fail2ban**
```bash
sudo systemctl restart fail2ban
sudo fail2ban-client status
```

### Issue: Legitimate IP banned

**Symptoms:**
Your own IP got banned by Fail2ban.

**Solutions:**

```bash
# Unban IP
sudo fail2ban-client set sshd unbanip <your-ip>

# Add to whitelist
sudo nano /etc/fail2ban/jail.d/defaults-debian.conf

# Add under [DEFAULT]:
ignoreip = 127.0.0.1/8 ::1 <your-ip>

# Restart
sudo systemctl restart fail2ban
```

---

## Performance Issues

### Issue: High CPU usage

**Diagnosis:**

```bash
# Check processes
top
htop

# Check specific services
systemctl status <service>
journalctl -u <service> -n 50
```

**Solutions:**

**Solution 1: Identify culprit**
```bash
# Top CPU consumers
ps aux --sort=-%cpu | head -10

# Kill if needed
sudo systemctl stop <service>
```

**Solution 2: Check for attacks**
```bash
# SSH brute force
sudo fail2ban-client status sshd

# Connection floods
sudo ss -s
```

### Issue: High memory usage

**Diagnosis:**

```bash
free -h
ps aux --sort=-%mem | head -10
```

**Solutions:**

```bash
# Clear cache (safe)
sudo sync && sudo sysctl -w vm.drop_caches=3

# Restart memory-heavy services
sudo systemctl restart <service>
```

### Issue: Disk space full

**Diagnosis:**

```bash
df -h
du -sh /* | sort -h
```

**Solutions:**

```bash
# Clear logs
sudo journalctl --vacuum-time=7d
sudo journalctl --vacuum-size=100M

# Clear apt cache
sudo apt clean

# Find large files
sudo find / -type f -size +100M -exec ls -lh {} \;
```

---

## Recovery Procedures

### Complete System Recovery

**Scenario:** Server is completely broken, need to rebuild.

```bash
# 1. Backup critical data (if accessible)
ssh miguel@X.X.X.X "sudo tar czf /tmp/backup.tar.gz /etc /home"
scp miguel@X.X.X.X:/tmp/backup.tar.gz ./

# 2. Destroy server
cd terraform/environments/production
tofu destroy

# 3. Recreate infrastructure
tofu apply

# 4. Re-run Ansible
cd ../../../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml

# 5. Restore data
scp backup.tar.gz miguel@X.X.X.X:/tmp/
ssh miguel@X.X.X.X "sudo tar xzf /tmp/backup.tar.gz -C /"

# 6. Reconfigure 2FA
ssh miguel@X.X.X.X "sudo /usr/local/bin/setup-2fa-yubikey.sh miguel"
```

### Rollback Ansible Changes

```bash
# Use backup configs created by Ansible
ssh miguel@X.X.X.X

# Find backups (created with timestamp)
ls -la /etc/ssh/sshd_config.*

# Restore
sudo cp /etc/ssh/sshd_config.TIMESTAMP /etc/ssh/sshd_config
sudo systemctl restart sshd
```

### Emergency Access

**If completely locked out:**

1. **Hetzner Console** (Web UI) - Always available
2. **Rescue Mode** - Boot into rescue system
3. **Rebuild** - Destroy and recreate from Terraform

---

## Getting Help

### Before Asking for Help

Gather this information:

```bash
# Run diagnostics
./scripts/health-check.sh > diagnostics.txt
./scripts/collect-logs.sh

# Include:
# - Error messages (exact text)
# - Steps to reproduce
# - What you've already tried
# - Diagnostic output
```

### Support Channels

- **Codeberg Issues**: https://codeberg.org/malpanez/twomindstrading_hetzner/issues
- **Hetzner Support**: https://www.hetzner.com/support
- **Community Forums**: Reddit /r/hetzner, /r/selfhosted

### Reporting Security Issues

**DO NOT** open public issues for security vulnerabilities.

Email: security@codeberg.org (Codeberg security team)

Include:
- Vulnerability description
- Steps to reproduce
- Potential impact
- Suggested fix (if any)

---

## Appendix: Useful Commands

### SSH Debugging

```bash
# Verbose SSH connection
ssh -vvv miguel@X.X.X.X

# Test SSH config
sudo sshd -t

# Show parsed SSH config
sudo sshd -T

# Monitor SSH connections
sudo journalctl -u ssh -f
```

### Ansible Debugging

```bash
# Dry run
ansible-playbook ... --check --diff

# Verbose output
ansible-playbook ... -vvv

# Step-by-step execution
ansible-playbook ... --step

# Run specific tasks
ansible-playbook ... --tags tag1,tag2

# Skip tasks
ansible-playbook ... --skip-tags tag1,tag2
```

### Terraform/OpenTofu Debugging

```bash
# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# Plan with detailed output
tofu plan -out=plan.out
tofu show plan.out

# State inspection
tofu state list
tofu state show resource.name
```

### System Debugging

```bash
# System logs
sudo journalctl -xe
sudo journalctl -f  # Follow
sudo journalctl --since "1 hour ago"

# Service logs
sudo journalctl -u servicename -f

# Kernel messages
sudo dmesg
sudo dmesg -w  # Follow

# Authentication logs
sudo tail -f /var/log/auth.log
```

---

**Document Version:** 1.0.0
**Last Updated:** 2025-12-25
**Maintained by:** DevOps Team
