# SSH 2FA with Break-Glass Strategy

**Date**: 2026-01-09
**Status**: ✅ Implemented

---

## Overview

This document describes the SSH 2FA (Two-Factor Authentication) implementation with break-glass mechanism for Ansible automation.

---

## Security Philosophy

### Defense in Depth Layers

```
Internet → Hetzner Cloud Firewall → UFW → Fail2ban → SSH 2FA → OS Hardening
```

1. **Hetzner Cloud Firewall**: First line of defense
2. **UFW (Uncomplicated Firewall)**: Local firewall, only ports 22, 80, 443
3. **Fail2ban**: Blocks IPs after failed login attempts
4. **SSH 2FA**: Requires SSH key + TOTP code
5. **OS Hardening**: CIS benchmarks, AppArmor, kernel hardening

### Why 2FA is Critical

Even with SSH keys only:

- Stolen/leaked SSH private keys can grant access
- Compromised developer workstation exposes keys
- 2FA adds second factor that attackers don't have

---

## Implementation

### Authentication Flow

#### For Regular Users (2FA Required)

```
ssh user@server
1. SSH Key authentication (publickey) ✓
2. TOTP Code prompt (keyboard-interactive) ✓
3. Access granted
```

#### For Ansible Automation (Break-Glass)

```
ansible-playbook -i inventory site.yml
1. SSH Key authentication (publickey) ✓
2. User in 'ansible-automation' group → Skip TOTP ✓
3. Access granted (Ansible runs without interaction)
```

---

## Configuration

### SSH Configuration (`/etc/ssh/sshd_config.d/50-2fa.conf`)

```sshd
# Enable 2FA globally
KbdInteractiveAuthentication yes
ChallengeResponseAuthentication yes
UsePAM yes

# Exception: ansible-automation group bypasses 2FA
Match Group ansible-automation
    AuthenticationMethods publickey
Match All
AuthenticationMethods publickey,keyboard-interactive

# Standard settings
PubkeyAuthentication yes
```

### PAM Configuration (`/etc/pam.d/sshd`)

```pam
@include common-auth

# Skip 2FA for ansible-automation group
auth [success=1 default=ignore] pam_succeed_if.so quiet user ingroup ansible-automation

# Require Google Authenticator for everyone else
auth required pam_google_authenticator.so nullok forward_pass
```

### User Groups

| User | Groups | 2FA Required | Purpose |
|------|--------|--------------|---------|
| `malpanez` | `ansible-automation` | ❌ No | Ansible automation user |
| `admin` | `sudo` | ✅ Yes | Human administrator |
| `root` | - | 🚫 Disabled | Root login prohibited |

---

## Environment-Specific Configuration

### Staging (`env_stag.yml`)

```yaml
ssh_2fa_enabled: true
ssh_2fa_break_glass_enabled: true
ssh_2fa_break_glass_users:
  - malpanez  # Ansible automation
```

**Why**: Allows Ansible automation while maintaining 2FA for manual access

### Production (`env_prod.yml`)

```yaml
ssh_2fa_enabled: true
ssh_2fa_break_glass_enabled: true
ssh_2fa_break_glass_users:
  - ansible  # Dedicated Ansible service account
```

**Recommendation**: Create dedicated `ansible` user for production

---

## Break-Glass Scenarios

### Scenario 1: Lost TOTP Device

**Problem**: Admin loses phone with Google Authenticator

**Solution**:

1. Admin cannot access server with regular account
2. Use break-glass account (`malpanez`) with only SSH key
3. SSH to server: `ssh -i ~/.ssh/key malpanez@server`
4. Reset 2FA: `google-authenticator` as admin user
5. Set up new TOTP device

### Scenario 2: Ansible Automation Blocked

**Problem**: Ansible playbook requires interaction (shouldn't happen)

**Solution**:

1. User `malpanez` in `ansible-automation` group
2. SSH authentication uses only publickey (no TOTP)
3. Ansible continues working without modification

### Scenario 3: Emergency Access

**Problem**: All admins unavailable, need immediate access

**Solution**:

1. Use break-glass account
2. Document access in audit logs
3. Review logs post-incident
4. Rotate keys if compromise suspected

---

## Security Considerations

### Pros of Break-Glass Approach

✅ **Ansible automation works** - No manual intervention needed
✅ **2FA enabled for humans** - Interactive sessions protected
✅ **Audit trail maintained** - All access logged
✅ **Emergency access preserved** - No complete lockout
✅ **Fail2ban still active** - Brute force protection remains

### Cons and Mitigations

❌ **Break-glass user has SSH key only** (less secure than 2FA)
✅ **Mitigation**:

- Break-glass user only accessible from specific IPs (add to Hetzner firewall)
- SSH key protected with strong passphrase
- Key stored in encrypted vault
- Fail2ban blocks brute force attempts
- Audit logs monitored

❌ **Stolen SSH key grants access**
✅ **Mitigation**:

- Rotate SSH keys regularly
- Use hardware keys (YubiKey) for production
- Monitor SSH access logs
- Alert on unexpected logins

---

## Best Practices

### For Staging Environment

1. **Use `malpanez` for Ansible** - Already configured as break-glass
2. **Create admin user for manual access** - Requires 2FA
3. **Set up Google Authenticator** - For admin user only
4. **Test 2FA** - Verify TOTP works before deploying to production

### For Production Environment

1. **Create dedicated `ansible` user** - Service account for automation
2. **Add `ansible` to `ansible-automation` group** - Break-glass enabled
3. **All human admins require 2FA** - No exceptions
4. **Hardware keys preferred** - YubiKey for TOTP generation
5. **IP whitelist** - Hetzner Cloud Firewall restricts SSH to known IPs

### SSH Key Management

1. **Generate strong keys**: ED25519 or RSA 4096-bit
2. **Passphrase protect keys**: Encrypted at rest
3. **Store securely**: Vault, password manager, or hardware key
4. **Rotate regularly**: Every 90 days for break-glass accounts
5. **Audit access**: Review SSH logs weekly

---

## Testing

### Test 2FA for Regular User

```bash
# Create admin user (requires 2FA)
sudo useradd -m -s /bin/bash -G sudo admin
sudo passwd admin

# Set up Google Authenticator as admin
sudo su - admin
google-authenticator

# Test SSH login (should prompt for TOTP)
ssh admin@server
# Enter TOTP code from Google Authenticator
```

### Test Break-Glass User

```bash
# Test Ansible automation user (no 2FA)
ssh -i ~/.ssh/github_ed25519 malpanez@server
# Should login immediately without TOTP prompt

# Verify group membership
id malpanez
# Output should include: groups=...,ansible-automation
```

### Test Ansible Automation

```bash
# Run Ansible playbook
cd ansible
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml

# Should complete without asking for TOTP
# Playbook runs fully automated
```

---

## Monitoring and Alerts

### What to Monitor

1. **Failed SSH attempts** - Fail2ban logs
2. **Successful SSH logins** - `/var/log/auth.log`
3. **Break-glass account usage** - Alert when `malpanez` logs in manually
4. **2FA failures** - Multiple failed TOTP attempts
5. **New SSH keys added** - Changes to `~/.ssh/authorized_keys`

### Alert Triggers

```yaml
# Example alerts for production
alerts:
  - name: Break-glass account used
    condition: SSH login by ansible-automation group member
    action: Send notification to security team

  - name: Multiple 2FA failures
    condition: 5+ failed TOTP attempts in 5 minutes
    action: Temporary IP ban + notification

  - name: SSH from unknown IP
    condition: SSH login from IP not in whitelist
    action: Block + immediate notification
```

---

## Migration Path

### Current State (Staging)

- SSH 2FA: ✅ Enabled with break-glass
- Break-glass user: `malpanez`
- Ansible: Works without interaction

### Future State (Production)

1. **Create dedicated `ansible` user**

   ```bash
   sudo useradd -m -s /bin/bash ansible
   sudo usermod -aG ansible-automation ansible
   sudo mkdir /home/ansible/.ssh
   sudo cp /home/malpanez/.ssh/authorized_keys /home/ansible/.ssh/
   sudo chown -R ansible:ansible /home/ansible/.ssh
   ```

2. **Update Ansible inventory**

   ```yaml
   ansible_user: ansible
   ansible_ssh_private_key_file: ~/.ssh/ansible_ed25519
   ```

3. **Enable 2FA for `malpanez`**

   ```bash
   # Remove from ansible-automation group
   sudo gpasswd -d malpanez ansible-automation

   # Set up Google Authenticator
   su - malpanez
   google-authenticator
   ```

4. **Restrict break-glass to emergencies only**
   - Document `ansible` user as automation account
   - Use `malpanez` only for interactive admin tasks (with 2FA)

---

## Troubleshooting

### Problem: Ansible asks for TOTP

**Cause**: User not in `ansible-automation` group

**Solution**:

```bash
# Check group membership
id $USER

# Add to group
sudo usermod -aG ansible-automation $USER

# Verify
id $USER | grep ansible-automation

# Restart SSH
sudo systemctl restart sshd
```

### Problem: 2FA not prompting for TOTP

**Cause**: Google Authenticator not configured

**Solution**:

```bash
# Set up Google Authenticator
google-authenticator

# Scan QR code with phone
# Save backup codes securely
```

### Problem: Locked out completely

**Cause**: Lost TOTP device + break-glass disabled

**Solution**:

```bash
# Via Hetzner console (KVM access)
# 1. Boot into rescue mode
# 2. Mount filesystem
# 3. Edit /etc/ssh/sshd_config.d/50-2fa.conf
# 4. Comment out AuthenticationMethods line
# 5. Reboot
# 6. SSH in and fix 2FA
```

---

## References

- [Google Authenticator PAM](https://github.com/google/google-authenticator-libpam)
- [OpenSSH Match Directive](https://man.openbsd.org/sshd_config#Match)
- [PAM Configuration](https://linux.die.net/man/8/pam.d)
- [Fail2ban](https://www.fail2ban.org/)
- [YubiKey SSH](https://developers.yubico.com/SSH/)

---

**Author**: Infrastructure Team
**Last Updated**: 2026-01-01
**Version**: 1.0
