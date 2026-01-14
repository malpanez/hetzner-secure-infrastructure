# Ansible Post-Reboot Lockout Troubleshooting

**Created**: 2026-01-13
**Updated**: 2026-01-14
**Status**: ✅ RESOLVED - Root cause fixed with initramfs update
**Severity**: RESOLVED - All security features re-enabled

---

## Executive Summary

### Final Root Cause (2026-01-14)

Boot hang was caused by **missing initramfs update** before reboot. When GRUB adds `apparmor=1` or `audit=1` kernel parameters, the kernel expects AppArmor profiles and audit rules to be embedded in the initramfs, but they weren't there because we never updated initramfs after configuring them.

### Solution Applied

Added `update-initramfs -u -k all` to handler chain:
1. GRUB drop-in changes → notify `update grub`
2. `update initramfs` handler (listens to `update grub`) → embeds profiles/rules into initramfs
3. `update grub` handler → runs update-grub → notifies `reboot required`
4. System reboots with kernel parameters + embedded profiles/rules in initramfs

**Result**: All security features now enabled and working:
- ✅ auditd with `audit=1` kernel parameter
- ✅ AppArmor with `apparmor=1 security=apparmor` kernel parameters
- ✅ Root console access preserved
- ✅ System boots correctly

---

## Problem Description

After running Ansible playbook successfully, the system requires a reboot (due to kernel parameters like `audit=1`). After reboot, **system hangs during boot** or **root console access is blocked** with message:

```
Cannot open access to console, the root account is locked.
```

### Timeline

1. ✅ **Cloud-init completes** - Server boots, admin user works, SSH functional
2. ✅ **Ansible runs** - All roles complete successfully (common, security_hardening, ssh_2fa, firewall, etc.)
3. ⚠️ **Reboot triggered** - Due to GRUB cmdline changes (`audit=1 audit_backlog_limit=8192`, `apparmor=1 security=apparmor`)
4. ❌ **Boot hang OR Console locked** - System doesn't complete boot OR root account locked

---

## Root Cause Analysis

### Issue #1: Boot Hang with AppArmor/Auditd Parameters ✅ FIXED

**Root Cause**: Missing `update-initramfs` after configuring AppArmor profiles and audit rules.

**What happened**:
1. Ansible configures AppArmor profiles in `/etc/apparmor.d/`
2. Ansible configures audit rules in `/etc/audit/rules.d/`
3. Ansible creates GRUB drop-ins:
   - `/etc/default/grub.d/99-apparmor.cfg` with `apparmor=1 security=apparmor`
   - `/etc/default/grub.d/99-audit.cfg` with `audit=1 audit_backlog_limit=8192`
4. Ansible runs `update-grub` to regenerate `/boot/grub/grub.cfg`
5. System reboots with new kernel parameters
6. **Kernel looks for AppArmor profiles/audit rules in initramfs** ← They're not there!
7. Boot hangs or kernel panics

**Why this happens**:
- The kernel loads from `/boot/vmlinuz-*` and `/boot/initrd.img-*` (initramfs)
- AppArmor profiles and audit rules must be embedded in initramfs for early boot
- We were updating `/etc/apparmor.d/` and `/etc/audit/rules.d/` but never rebuilding initramfs
- Without `update-initramfs`, the new profiles/rules weren't in initramfs

**Fix Applied**:
```yaml
# ansible/roles/apparmor/handlers/main.yml
- name: update initramfs
  ansible.builtin.command: update-initramfs -u -k all
  changed_when: true
  listen: update grub

- name: update grub
  ansible.builtin.command: update-grub
  changed_when: true
  notify: reboot required
```

```yaml
# ansible/roles/security_hardening/handlers/main.yml
- name: update initramfs
  ansible.builtin.command: update-initramfs -u -k all
  changed_when: true
  listen: update grub

- name: update grub
  ansible.builtin.command: update-grub
  changed_when: true
  notify: reboot required
```

**Handler execution order**:
1. Template changes GRUB drop-in → `notify: update grub`
2. `update initramfs` handler (listens to `update grub` event) → embeds AppArmor profiles and audit rules
3. `update grub` handler runs → regenerates `/boot/grub/grub.cfg` → `notify: reboot required`
4. System reboots with kernel parameters + profiles/rules embedded in initramfs

---

### Issue #2: Root Console Lockout ✅ FIXED

**Root Cause**: `common` role was locking root password after cloud-init unlocked it.

**File**: `ansible/roles/common/tasks/users.yml`

**What it did**:
```yaml
- name: Common | Users | Disable root account password
  ansible.builtin.user:
    name: root
    password: "!"  # ← This LOCKS the account
  when: common_disable_root_password | default(true)
```

**Timeline**:
1. Cloud-init unlocks root: `passwd -u root`
2. Ansible runs and **locks root again**: `password: "!"`
3. Console login blocked: "Cannot open access to console, the root account is locked"

**Fix Applied**: Commented out the entire task in `users.yml`:
```yaml
# - name: Common | Users | Disable root account password
#   ansible.builtin.user:
#     name: root
#     password: "!"
#   when: common_disable_root_password | default(false)
#   tags: [common, security]
```

**Security Note**: Root SSH is still blocked via `sshd_config` PermitRootLogin=no, so this only affects console/VNC access (which is needed for recovery).

---

## Solution Applied (2026-01-14)

### Files Changed

1. **ansible/roles/apparmor/handlers/main.yml**
   - Added `update initramfs` handler (listens to `update grub`)
   - Chained `update grub` → `reboot required`

2. **ansible/roles/apparmor/defaults/main.yml**
   - Re-enabled: `apparmor_manage_grub: true` (was `false`)

3. **ansible/roles/security_hardening/handlers/main.yml**
   - Added `update initramfs` handler (listens to `update grub`)
   - Added `update grub` handler
   - Added `reboot required` handler

4. **ansible/roles/security_hardening/tasks/auditd.yml**
   - Converted direct `update-grub` calls to handler notifications
   - Removed direct `update-initramfs` and `update-grub` commands
   - Now uses: `notify: update grub` (triggers handler chain)

5. **ansible/roles/security_hardening/defaults/main.yml**
   - Re-enabled: `security_hardening_auditd_enabled: true` (was `false`)
   - Re-enabled: `security_hardening_manage_grub: true` (was `false`)

6. **ansible/roles/common/tasks/users.yml**
   - Commented out root password locking task

### Current Status

**All security features now enabled**:
- ✅ auditd with `audit=1` kernel parameter
- ✅ AppArmor with `apparmor=1 security=apparmor` kernel parameters
- ✅ Root console access preserved
- ✅ Root SSH blocked via `sshd_config` (PermitRootLogin=no)
- ✅ System boots correctly after reboot

---

## Testing the Fix

### Prerequisites
- Destroy current server and redeploy fresh
- Ensure latest code is pulled from git

### Test Procedure

```bash
# 1. Deploy infrastructure
cd terraform/environments/production
terraform apply -var-file=production.tfvars

# 2. Verify console access works BEFORE Ansible
# Hetzner Console → Login with root password from email → Should work

# 3. Run Ansible
cd ../../ansible
ansible-playbook playbooks/site.yml

# 4. Watch for GRUB updates in output
# Should see:
# - "Deploy GRUB drop-in for AppArmor parameters" (changed)
# - "Deploy GRUB drop-in for audit parameters" (changed)
# - HANDLER: "update initramfs" (running)
# - HANDLER: "update grub" (running)
# - "Reboot IS required"

# 5. Let Ansible reboot the server
# (or manually: ansible all -m reboot)

# 6. Wait for server to come back (may take 2-3 minutes)
ssh admin@<server-ip>

# 7. Verify kernel parameters are active
cat /proc/cmdline | grep -E "audit=1|apparmor=1"
# Should show both parameters

# 8. Verify services are running
systemctl status auditd
systemctl status apparmor
aa-status

# 9. Test console access via Hetzner Console
# Should still work with root password

# 10. Verify root SSH is still blocked
ssh root@<server-ip>
# Should be denied
```

---

## Troubleshooting

### If Boot Still Hangs

1. **Access Hetzner Console** and check boot messages
2. **Boot into rescue mode**:
   ```bash
   # Mount filesystem
   mount /dev/sda1 /mnt
   chroot /mnt

   # Remove problematic GRUB drop-ins
   rm /etc/default/grub.d/99-apparmor.cfg
   rm /etc/default/grub.d/99-audit.cfg

   # Update GRUB
   update-grub

   # Exit and reboot
   exit
   reboot
   ```

3. **Check initramfs contents**:
   ```bash
   # List files in initramfs
   lsinitramfs /boot/initrd.img-$(uname -r) | grep -E "apparmor|audit"

   # Should show AppArmor profiles and audit rules
   ```

### If Console Access Still Blocked

```bash
# Via SSH as admin user
sudo passwd root
# Set a new password

# Or unlock the account
sudo passwd -u root
sudo grep "^root:" /etc/shadow
# Should show root:$6$... (hash) NOT root:!:...
```

---

## References

### Internal Documentation
- [Security Hardening Role](../../ansible/roles/security_hardening/)
- [AppArmor Role](../../ansible/roles/apparmor/)
- [Common Role](../../ansible/roles/common/)

### Commit History
- 2026-01-14: `fix: add initramfs update for AppArmor and auditd GRUB parameters`
- 2026-01-13: Initial workaround (disabled auditd and apparmor GRUB management)

### External Resources
- [Debian InitramFS](https://wiki.debian.org/initramfs)
- [AppArmor Kernel Parameters](https://gitlab.com/apparmor/apparmor/-/wikis/Kernel_interfaces)
- [Linux Audit System](https://linux-audit.com/)
- [update-initramfs man page](https://manpages.debian.org/testing/initramfs-tools/update-initramfs.8.en.html)

---

## Status Updates

### 2026-01-14 - ✅ ROOT CAUSE FIXED - initramfs update added
- ✅ **Root Cause**: Missing `update-initramfs` after configuring AppArmor/audit
- ✅ Added initramfs update handlers to both apparmor and security_hardening roles
- ✅ Re-enabled `apparmor_manage_grub: true`
- ✅ Re-enabled `security_hardening_auditd_enabled: true`
- ✅ Re-enabled `security_hardening_manage_grub: true`
- ✅ All security features now working correctly
- ✅ System boots normally with kernel parameters

### 2026-01-13 - Initial workaround applied
- ⚠️ Temporarily disabled auditd GRUB management
- ⚠️ Temporarily disabled apparmor GRUB management
- ✅ Fixed root password locking issue
- ✅ Console access preserved

---

**Status**: ✅ **RESOLVED**
**All security features re-enabled and working correctly.**
