# Deployment Status - 2026-01-02

## Current Status: Code Fixed, Server Destroyed

The infrastructure code has been fixed but NOT yet deployed. The Hetzner server was destroyed and left in that state per user request ("dejalo destruido mañana sigo").

## Issues Found and Fixed

### 1. AppArmor Blocking SSH (CRITICAL - FIXED ✅)
**Problem**: AppArmor was running in enforce mode, which blocked SSH connections after server reboot even though deployment appeared successful.

**Symptoms**:
- Ansible deployment completed successfully (406 tasks OK, 0 failed)
- HTTP port 80 worked (WordPress accessible)
- SSH port 22 refused connections after reboot
- HTTPS port 443 refused connections
- OpenBao inaccessible

**Root Cause**: AppArmor SSH profile in enforce mode was too restrictive and blocked legitimate SSH operations.

**Fix Applied**:
- Changed [ansible/roles/apparmor/defaults/main.yml](ansible/roles/apparmor/defaults/main.yml) line 14: `apparmor_enforce_mode: false`
- AppArmor now runs in **complain mode** (logs violations but doesn't block)
- Will allow testing and refinement of profiles without risking lockout

**Status**: ✅ Fixed in code, pending deployment test

---

### 2. Reboot Never Triggered (CRITICAL - FIXED ✅)
**Problem**: Server should reboot after kernel parameter changes (audit=1, AppArmor), but reboot never happened.

**Symptoms**:
- Security hardening role modified GRUB and set reboot flag
- AppArmor handler set reboot flag
- Reboot play showed: "Reboot is NOT required for this server"
- Kernel parameters never took effect without manual reboot

**Root Causes**:
1. **Variable name inconsistency**:
   - `security_hardening/tasks/main.yml` used `reboot_required: true`
   - `apparmor/handlers/main.yml` used `ansible_reboot_required: true`
   - Playbook checked for `reboot_required`

2. **Facts not persisting between plays**:
   - Facts set without `cacheable: true` don't persist
   - `gather_facts: false` in reboot play meant facts weren't loaded

**Fixes Applied**:
1. Standardized on `ansible_reboot_required` everywhere
2. Added `cacheable: true` to fact definitions
3. Changed `gather_facts: false` to `gather_facts: true` in reboot plays

**Files Modified**:
- [ansible/roles/security_hardening/tasks/main.yml](ansible/roles/security_hardening/tasks/main.yml) lines 216-222
- [ansible/playbooks/site.yml](ansible/playbooks/site.yml) lines 113-162 (reboot plays)

**Status**: ✅ Fixed in code, pending deployment test

---

### 3. Role Execution Order (HIGH - FIXED ✅)
**Problem**: Firewall role ran BEFORE SSH 2FA role, creating risk of SSH lockout.

**Risk**: If firewall activates before SSH is fully configured and tested, connection could be lost with no way to recover.

**Fix Applied**: Reordered roles in [ansible/playbooks/site.yml](ansible/playbooks/site.yml):
```yaml
# NEW ORDER (SAFE):
1. common
2. security_hardening
3. ssh_2fa          ← Runs FIRST
4. firewall         ← Runs AFTER SSH is configured
5. fail2ban
6. apparmor
```

**Status**: ✅ Fixed in code, pending deployment test

---

### 4. UFW Race Condition (HIGH - PARTIALLY MITIGATED ⚠️)
**Problem**: UFW firewall is disabled before adding rules. If rule addition fails, SSH could be locked out.

**Current Mitigation**:
- Added explicit SSH allow rule from management IP (37.228.206.5/32) BEFORE enabling UFW
- Rule defined in [ansible/roles/firewall/tasks/rules.yml](ansible/roles/firewall/tasks/rules.yml) lines 6-14
- Management IP configurable via `ssh_allowed_ips` in [ansible/inventory/group_vars/all/common.yml](ansible/inventory/group_vars/all/common.yml)

**Remaining Risk**:
- If SSH rule application fails silently, verification might not catch it
- No actual connectivity test, only rule existence check

**Status**: ⚠️ Partially mitigated, needs deployment testing

---

### 5. PAM 2FA Module Configuration (CRITICAL - NOT FIXED ❌)
**Problem**: Google Authenticator PAM module configuration could cause authentication loops or lockouts.

**Issues Identified**:
1. Module uses `required` control instead of `[default=ignore]`
2. Module may be inserted after `pam_unix.so` (wrong order)
3. Could cause authentication failures even with correct credentials

**Why Not Fixed**:
- Complex change affecting authentication stack
- Requires careful testing to avoid complete lockout
- Deferred pending successful basic deployment

**Affected File**: [ansible/roles/ssh_2fa/templates/sshd_2fa.conf.j2](ansible/roles/ssh_2fa/templates/sshd_2fa.conf.j2)

**Status**: ❌ Known issue, deferred for future fix

---

## Next Steps (When User Returns)

### Phase 1: Deploy and Test Basic Functionality
1. Review this status document
2. Deploy infrastructure: `cd terraform && terraform apply`
3. Run Ansible (user manually): `cd ansible && export HCLOUD_TOKEN="..." && ansible-playbook -u root playbooks/site.yml`
4. Verify SSH access works after deployment
5. Check that reboot actually triggered (if kernel params changed)
6. Verify AppArmor is in complain mode: `sudo aa-status`

### Phase 2: Verify Services
1. **WordPress**: Check HTTP access, verify admin login works
2. **HTTPS**: Verify SSL certificate and HTTPS redirect
3. **OpenBao**: Verify UI accessible, setup 90-day rotation
4. **Monitoring**: Check Grafana/Prometheus accessibility
5. **Firewall**: Verify only required ports open: `sudo ufw status numbered`

### Phase 3: Security Hardening
1. Review AppArmor logs in complain mode: `sudo aa-logprof`
2. Test SSH 2FA authentication flow
3. Fix PAM 2FA module configuration (if needed)
4. Consider moving AppArmor to enforce mode (after testing)

### Phase 4: Production Readiness
1. Capture 2FA QR codes for all users
2. Configure OpenBao credential rotation
3. Test backup/restore procedures
4. Document recovery procedures
5. Plan DNS migration from GoDaddy to Cloudflare

---

## Files Changed in This Session

All changes committed to git:

### Modified Files:
1. `ansible/roles/apparmor/defaults/main.yml` - Changed to complain mode
2. `ansible/roles/security_hardening/tasks/main.yml` - Fixed reboot variable
3. `ansible/playbooks/site.yml` - Reordered roles, fixed reboot detection
4. `ansible/inventory/group_vars/all/common.yml` - Added ssh_allowed_ips variable
5. `ansible/roles/firewall/tasks/rules.yml` - Added explicit SSH rule before enabling UFW

### New Files:
1. `DEPLOYMENT_STATUS.md` - This document

---

## Infrastructure Configuration

**Current Terraform Config** (`terraform.prod.tfvars`):
- **Architecture**: ARM64 (CAX11 - Ampere Altra Q80-30)
- **Instance Number**: 1
- **Server Naming**: `prod-web-arm-01`
- **Region**: Nuremberg (eu-central)
- **OS**: Ubuntu 24.04
- **Management IP**: 37.228.206.5/32 (allowed for SSH)

**Ansible Configuration**:
- Dynamic inventory using Hetzner Cloud plugin
- Initial connection as root user
- SSH key: `~/.ssh/github_ed25519`
- HCLOUD_TOKEN required as environment variable

---

## Known Working Configuration

This infrastructure previously worked before these issues emerged. Changes since last working state:
- Security hardening additions (audit=1, AppArmor enforce mode)
- PAM 2FA module configuration changes
- UFW firewall rule ordering

**What Changed**: Incremental security hardening introduced blocking mechanisms without proper testing between changes.

**Lesson Learned**: Test each security layer individually before adding the next one.

---

## Testing Strategy

When deploying next:

1. **Monitor During Deployment**:
   - Watch Ansible output for errors
   - Check if reboot actually happens (should see connection drop)
   - Verify tasks complete after reboot

2. **Immediate Post-Deployment**:
   - SSH should remain accessible at all times
   - If lockout occurs, use Hetzner Console for recovery

3. **Verification Commands**:
   ```bash
   # Check AppArmor mode
   sudo aa-status

   # Check if reboot happened (uptime should be recent)
   uptime

   # Check UFW status
   sudo ufw status numbered

   # Check kernel parameters
   cat /proc/cmdline | grep audit

   # Check services
   systemctl status sshd nginx mysql fail2ban
   ```

4. **If Lockout Occurs**:
   - Use Hetzner Cloud Console to access server
   - Check `/var/log/auth.log` for SSH denials
   - Check `dmesg` for AppArmor denials
   - Check UFW rules: `sudo ufw status verbose`

---

## Questions for Next Session

Before deploying, consider:

1. Should we deploy with 2FA disabled initially to ensure SSH access works?
2. Should we test without firewall first, then add it?
3. Do we want to capture logs during deployment for analysis?
4. Should root SSH access be kept enabled for initial troubleshooting?

---

## Contact and Recovery

**Server Access Methods** (in order of preference):
1. SSH as malpanez user with 2FA (once configured)
2. SSH as root (if not disabled)
3. Hetzner Cloud Console (always available)

**Recovery Procedure** if locked out:
1. Access via Hetzner Cloud Console
2. Disable UFW: `sudo ufw disable`
3. Put AppArmor in complain mode: `sudo aa-complain /etc/apparmor.d/*`
4. Restart SSH: `sudo systemctl restart sshd`
5. Investigate logs before re-enabling security
