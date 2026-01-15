# GRUB Boot Configuration Simplification

**Date**: 2026-01-14
**Status**: Completed
**Impact**: Eliminates unnecessary GRUB modifications causing boot complications

---

## Summary

Removed all unnecessary GRUB kernel parameter modifications for AppArmor and auditd on Debian 13. These parameters were causing boot failures and reboot loops, and are NOT required on modern Debian systems.

---

## Changes Made

### 1. AppArmor Role Simplification

**Files Modified**:
- `ansible/roles/apparmor/tasks/configure.yml`
- `ansible/roles/apparmor/defaults/main.yml`

**What Was Removed**:
- GRUB drop-in directory creation task
- GRUB drop-in deployment task (`/etc/default/grub.d/99-apparmor.cfg`)
- Variables: `apparmor_manage_grub`, `apparmor_grub_cmdline`
- Kernel parameters: `apparmor=1 security=apparmor`

**Why It Was Removed**:
```
Source: https://wiki.debian.org/AppArmor/HowToUse
Quote: "If you are using Debian 10 'Buster' or newer, AppArmor is enabled by default"

AppArmor has been ENABLED BY DEFAULT since Debian 10.
Kernel parameters are NOT needed.
```

### 2. Auditd Role Simplification

**Files Modified**:
- `ansible/roles/security_hardening/tasks/auditd.yml`
- `ansible/roles/security_hardening/defaults/main.yml`

**What Was Removed**:
- Kernel audit check task (`grep 'audit=' /proc/cmdline`)
- GRUB drop-in directory creation task
- GRUB drop-in deployment task (`/etc/default/grub.d/99-audit.cfg`)
- GRUB drop-in removal task (cleanup)
- Warning message task for missing audit=1
- GRUB update trigger task
- Conditional service start (only if audit=1 present)
- Variables: `security_hardening_manage_grub`, `security_hardening_audit_kernel_params`
- Kernel parameters: `audit=1 audit_backlog_limit=8192`

**Why It Was Removed**:
```
Source: https://www.server-world.info/en/note?os=Debian_13&p=audit&f=1
Quote: "Install auditd package, configure rules, and start service"

Auditd DOES NOT require kernel parameters on Debian 13.
audit=1 is ONLY for extreme compliance (DoD STIG) - not needed for production.
WARNING: audit=1 can cause emergency mode boot failures.
```

---

## What Remains

### Console Output Configuration ONLY

**File**: `ansible/roles/common/tasks/grub.yml`

The ONLY GRUB modification that remains is console output configuration for Hetzner Cloud Console visibility:

```yaml
# /etc/default/grub.d/00-console.cfg
GRUB_CMDLINE_LINUX="console=tty0 console=ttyS0,115200n8"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=7 systemd.show_status=true rd.systemd.show_status=yes"
```

**Purpose**:
- `console=tty0`: VGA console output (Hetzner Cloud Console viewer)
- `console=ttyS0,115200n8`: Serial console (for rescue/debugging)
- `loglevel=7`: Verbose boot messages (for troubleshooting)

**Why This Is Kept**:
- Essential for troubleshooting boot issues via Hetzner Cloud Console
- Does NOT interfere with boot process
- Does NOT cause emergency mode failures

---

## SSH 2FA Faillock - No Changes Needed

**File**: `ansible/roles/ssh_2fa/tasks/faillock.yml`

**Status**: **NO GRUB MODIFICATIONS**

Despite appearing in the grep search, this role does NOT touch GRUB at all. The search matched the word "GRUB" in comments (break-glass emergency instructions).

---

## Testing Checklist

After these changes, verify:

### 1. Clean Boot
```bash
# Server should boot without emergency mode
# No "root account is locked" messages
# No "cannot open access to console" errors
```

### 2. AppArmor Active
```bash
$ sudo aa-status
# Should show:
# - apparmor module is loaded
# - 2+ profiles in complain mode
# - sshd and fail2ban-server profiles loaded
```

### 3. Auditd Active
```bash
$ sudo systemctl status auditd
# Should be: active (running)

$ sudo auditctl -l
# Should show: audit rules configured
```

### 4. No GRUB Drop-ins (except console)
```bash
$ ls /etc/default/grub.d/
# Should show ONLY:
# - 00-console.cfg

# Should NOT show:
# - 99-apparmor.cfg (REMOVED)
# - 99-audit.cfg (REMOVED)
```

### 5. Console Access Works
```bash
# Hetzner Cloud Console should show boot messages
# Root account should be unlocked for console access
# SSH root login still blocked (prohibit-password)
```

---

## Root Cause Analysis

### Problem
Ansible roles were adding kernel parameters that:
1. Are NOT required on Debian 13
2. Cause boot failures and emergency mode
3. Trigger unnecessary reboots
4. Lock root account preventing console recovery

### Diagnosis Path
1. User reported "Cannot open access to console, the root account is locked"
2. System enters emergency mode repeatedly
3. AppArmor logs show profile loads during boot
4. Identified `audit=1` causing emergency mode
5. Discovered official documentation showing parameters NOT needed

### Solution
Remove ALL kernel parameter modifications except console output configuration.

---

## Documentation References

1. **AppArmor**: https://wiki.debian.org/AppArmor/HowToUse
   - "AppArmor is enabled by default" (Debian 10+)

2. **Auditd**: https://www.server-world.info/en/note?os=Debian_13&p=audit&f=1
   - No GRUB changes mentioned
   - Install package + start service = working auditd

3. **Hetzner Console**: Requires `console=tty0` for VGA output visibility

---

## Lessons Learned

1. **Read Official Documentation First**: We blindly added kernel parameters without verifying if they were needed
2. **Default != Required**: Just because CIS benchmarks recommend `audit=1` doesn't mean it's needed on modern systems
3. **Test Boot Process**: Always test server boot after GRUB changes (caused multiple lockouts)
4. **Keep It Simple**: Fewer GRUB modifications = fewer boot complications
5. **Emergency Access**: Root console access is critical for recovery - never lock it

---

## Migration Guide

### For Existing Servers

If you have servers with old GRUB configurations, clean them up:

```bash
# SSH into server
ssh malpanez@server

# Remove old drop-ins
sudo rm -f /etc/default/grub.d/99-apparmor.cfg
sudo rm -f /etc/default/grub.d/99-audit.cfg

# Update GRUB
sudo update-grub

# Verify only console configuration remains
ls -la /etc/default/grub.d/
# Should show: 00-console.cfg ONLY

# Verify services still work
sudo aa-status  # AppArmor should be active
sudo systemctl status auditd  # Should be active (running)

# Reboot to test
sudo reboot
```

### For New Servers

Simply run the updated Ansible playbook. It will:
- Install AppArmor (already enabled by default)
- Install auditd + configure rules
- Only configure console output in GRUB
- NO unnecessary kernel parameters

---

**Last Updated**: 2026-01-14
**Maintained by**: Infrastructure Team
**Questions**: Review official Debian documentation before adding kernel parameters
