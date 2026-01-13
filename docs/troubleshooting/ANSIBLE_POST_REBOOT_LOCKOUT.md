# Ansible Post-Reboot Lockout Troubleshooting

**Created**: 2026-01-13
**Updated**: 2026-01-13
**Status**: ✅ WORKAROUND APPLIED - Auditd disabled
**Severity**: MEDIUM - Workaround deployed, can re-enable later

---

## Problem Description

After running Ansible playbook successfully, the system requires a reboot (due to kernel parameters like `audit=1`). After reboot, **root console access is blocked** with message:

```
Cannot open access to console, the root account is locked.
```

### Timeline

1. ✅ **Cloud-init completes** - Server boots, admin user works, SSH functional
2. ✅ **Ansible runs** - All roles complete successfully (common, security_hardening, ssh_2fa, firewall, etc.)
3. ⚠️ **Reboot triggered** - Due to GRUB cmdline changes (`audit=1 audit_backlog_limit=8192`)
4. ❌ **Console locked** - Root account locked, cannot access via Hetzner Console (VNC)
5. ❓ **SSH may or may not work** - Depends on what locked the account

---

## Root Cause Analysis

### What We Know

1. **Cloud-init works correctly**:
   - `disable_root: false` is set
   - `passwd -u root` unlocks root account
   - Console access works BEFORE Ansible runs

2. **Something in Ansible locks root**:
   - Happens between Ansible completion and reboot
   - NOT a cloud-init issue (that runs on first boot only)
   - NOT a GRUB/kernel issue (that doesn't lock accounts)

3. **Roles executed BEFORE reboot**:
   ```yaml
   1. common               # User creation, packages
   2. security_hardening   # ← SUSPECT: audit, sysctl, GRUB
   3. ssh_2fa             # ← SUSPECT: PAM, faillock
   4. firewall            # UFW rules
   5. fail2ban            # Intrusion prevention
   6. apparmor            # ← SUSPECT: AppArmor profiles
   ```

### Prime Suspects

#### 1. **PAM Configuration** (`ssh_2fa` role)

**Files**:
- `ansible/roles/ssh_2fa/templates/pam-ssh-2fa.j2`
- `/etc/pam.d/sshd-2fa` (deployed by Ansible)

**Theory**: PAM misconfiguration could lock root on reboot.

**Check**:
```bash
# Via Hetzner Console (if accessible) or Rescue Mode
cat /etc/pam.d/sshd
cat /etc/pam.d/sshd-2fa
cat /etc/security/faillock.conf
```

**Key settings**:
```ini
# Should be false (root exempt from faillock)
ssh_2fa_faillock_even_deny_root: false  # Default in defaults/main.yml:186
```

#### 2. **Auditd + GRUB** (`security_hardening` role)

**Files**:
- `ansible/roles/security_hardening/tasks/auditd.yml`
- `/etc/default/grub` (modified by Ansible)

**Changes made**:
```bash
GRUB_CMDLINE_LINUX_DEFAULT="... audit=1 audit_backlog_limit=8192"
```

**Theory**: First boot with `audit=1` might trigger strict audit mode that blocks console.

**Check**:
```bash
# Check if audit is active
cat /proc/cmdline | grep audit
systemctl status auditd
```

#### 3. **AppArmor Profiles** (`apparmor` role)

**Theory**: AppArmor profile might restrict console login.

**Check**:
```bash
aa-status
# Check if any profile blocks getty or login
```

---

## Investigation Steps

### Step 1: Access Server via Rescue Mode

```bash
# 1. Hetzner Console → Server → Rescue tab
# 2. Enable Rescue Mode → Reboot
# 3. SSH with rescue credentials (shown on screen)

# 4. Mount root filesystem
mount /dev/sda1 /mnt
chroot /mnt
```

### Step 2: Check Root Account Status

```bash
# Inside chroot

# Check if root is locked
passwd -S root
# Should show: "root P ..." (P = password set, unlocked)
# If shows "root L ...", root is LOCKED

# Check /etc/shadow
grep "^root:" /etc/shadow
# Should NOT have "!" or "*" in password field
```

### Step 3: Check PAM Configuration

```bash
# Check all PAM files
ls -la /etc/pam.d/
cat /etc/pam.d/sshd
cat /etc/pam.d/sshd-2fa
cat /etc/pam.d/login        # Console login
cat /etc/pam.d/common-auth

# Check faillock config
cat /etc/security/faillock.conf | grep -v "^#" | grep -v "^$"

# Check if faillock has locked root
faillock --user root
```

### Step 4: Check Audit Configuration

```bash
# Check GRUB config
cat /etc/default/grub | grep CMDLINE

# Check audit rules
cat /etc/audit/rules.d/*.rules

# Check auditd config
cat /etc/audit/auditd.conf
```

### Step 5: Check SystemD Journal

```bash
# Check logs from last boot
journalctl -b -1  # Previous boot
journalctl -b -1 | grep -i "root\|lock\|denied\|fail"

# Check PAM logs
journalctl -b -1 -u systemd-logind
```

---

## Temporary Workarounds

### Workaround 1: Disable Problematic Role

Edit `ansible/playbooks/site.yml` and skip suspect role:

```yaml
# Temporarily disable ssh_2fa
- role: ssh_2fa
  tags: [security, ssh, 2fa]
  when: false  # ← Add this to skip
```

Or run with `--skip-tags`:
```bash
ansible-playbook playbooks/site.yml --skip-tags 2fa
```

### Workaround 2: Fix Root Account in Rescue Mode

```bash
# 1. Boot to rescue mode
# 2. Mount and chroot
mount /dev/sda1 /mnt
chroot /mnt

# 3. Unlock root
passwd -u root

# 4. Set a known password (for console access)
passwd root
# Enter a strong password

# 5. Exit and reboot normally
exit
reboot
```

### Workaround 3: Disable audit=1 Temporarily

```bash
# In rescue mode
mount /dev/sda1 /mnt
chroot /mnt

# Edit GRUB
vi /etc/default/grub
# Remove "audit=1 audit_backlog_limit=8192"

# Update GRUB
update-grub

# Reboot
exit
reboot
```

---

## Solution Candidates

### Option 1: Ensure Root Unlock Persists

Add to Ansible (`common` or `security_hardening` role):

```yaml
- name: Ensure root account is unlocked for console access
  ansible.builtin.command: passwd -u root
  changed_when: false
  tags: [security, console-access]
```

### Option 2: Exclude Root from Faillock

Verify in `ansible/roles/ssh_2fa/defaults/main.yml`:

```yaml
# MUST be false
ssh_2fa_faillock_even_deny_root: false
```

### Option 3: Fix PAM Stack

Ensure PAM doesn't lock root on console:

```bash
# /etc/pam.d/login should NOT have pam_faillock for root
# Or add nullok_secure to allow root with password
```

---

## Testing Checklist

After implementing fix:

```bash
# 1. Deploy fresh server
terraform apply -var-file=production.tfvars

# 2. Verify console access (BEFORE Ansible)
# Hetzner Console → Should work with password from email

# 3. Run Ansible
ansible-playbook playbooks/site.yml --ask-vault-pass

# 4. Before reboot, check root status
ansible all -m command -a "passwd -S root"
# Should show: root P ...

# 5. Manually reboot (don't let Ansible reboot yet)
ansible all -m reboot -a "reboot_timeout=600"

# 6. After reboot, verify console access
# Hetzner Console → Should still work

# 7. Verify SSH access
ssh malpanez@<server-ip>

# 8. Check logs
journalctl -b | grep -i "root\|lock"
```

---

## References

### Internal Documentation
- [SSH and Console Access](./SSH_CONSOLE_ACCESS.md) - SSH vs Console behavior
- [Ansible Site Playbook](../../ansible/playbooks/site.yml) - Role execution order
- [Security Hardening Role](../../ansible/roles/security_hardening/) - Audit configuration
- [SSH 2FA Role](../../ansible/roles/ssh_2fa/) - PAM and faillock setup

### External Resources
- [PAM Configuration](https://linux.die.net/man/5/pam.conf)
- [Faillock Documentation](https://man7.org/linux/man-pages/man8/pam_faillock.8.html)
- [Linux Audit System](https://linux-audit.com/configuring-and-auditing-linux-systems-with-audit-daemon/)
- [Debian Security](https://www.debian.org/doc/manuals/securing-debian-manual/)

---

## Solution / Workaround

### ✅ Temporary Solution (Applied 2026-01-13)

**Root Cause Identified**: `security_hardening` role's auditd configuration modifies GRUB with `audit=1` kernel parameter, which causes boot hang after reboot.

**Workaround Applied**:
```yaml
# File: ansible/roles/security_hardening/defaults/main.yml
security_hardening_auditd_enabled: false
security_hardening_manage_grub: false
```

**Impact**:
- ✅ System boots normally after Ansible + reboot
- ✅ Console access preserved
- ✅ All other security hardening (sysctl, unattended-upgrades, etc.) still active
- ⚠️ Audit logging disabled (can re-enable later)

**To Re-enable Auditd Later** (after fixing boot sequence):
```bash
# Edit inventory/group_vars/all/main.yml or host_vars
security_hardening_auditd_enabled: true
security_hardening_manage_grub: true

# Run only security_hardening role
ansible-playbook playbooks/site.yml --tags security,auditd
```

---

## Status Updates

### 2026-01-13 - Root Cause Found and Workaround Applied
- ✅ Identified culprit: `security_hardening/tasks/auditd.yml`
- ✅ GRUB modification with `audit=1 audit_backlog_limit=8192` causes boot hang
- ✅ Disabled auditd temporarily in role defaults
- ✅ Documentation updated with workaround
- 🔄 Can re-enable later with proper boot sequence fix

### Next Steps (Optional - For Full Audit Support)
1. Investigate why `audit=1` causes boot hang on Debian 13 + Hetzner
2. Test alternative auditd configurations
3. Consider delaying auditd enablement until second Ansible run
4. Add pre-reboot validation checks
4. Identify exact task that locks root account
5. Implement targeted fix
