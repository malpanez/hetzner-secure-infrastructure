# SSH 2FA + PAM Hardening Role

Ansible role for implementing multi-factor authentication (2FA) with Google Authenticator/Yubikey and PAM faillock protection against brute force attacks.

## Features

### Core Features

- ✅ **SSH Multi-Factor Authentication (2FA)**
  - Google Authenticator TOTP tokens
  - Yubikey U2F support
  - Automatic setup scripts included

- ✅ **Sudo 2FA Protection**
  - Require 2FA for privileged operations
  - Configurable per-user or per-group

- ✅ **PAM Faillock (Anti-Brute Force)**
  - Account lockout after failed attempts
  - Configurable lockout thresholds and durations
  - Protects SSH, sudo, and local console login

- ✅ **SSH Hardening**
  - Strong cryptographic algorithms only
  - Modern key exchange (Curve25519, Ed25519)
  - Weak algorithms disabled (DSA, ECDSA)
  - Custom security banners

- ✅ **Break-glass Emergency Access**
  - Dedicated group exempt from 2FA
  - Prevents lockout during emergencies
  - Documented recovery procedures

- ✅ **Audit Logging**
  - Integration with auditd
  - Track all authentication failures
  - Monitor PAM configuration changes

### Advanced Features

- Modular PAM configuration (uses `pam-auth-update`)
- Automatic strong SSH host key generation
- Idempotent deployment
- Full Molecule test coverage
- Multi-distro support (Debian/Ubuntu)

## Requirements

### Supported Operating Systems

- Debian 11+
- Ubuntu 20.04+
- Ubuntu 22.04+
- Ubuntu 24.04+

### Dependencies

- Ansible 2.9+
- Python 3.6+
- `community.general` collection

## Role Variables

### Feature Toggles

```yaml
# Enable 2FA for SSH (default: true)
ssh_2fa_enable_ssh: true

# Enable 2FA for sudo (default: true)
ssh_2fa_enable_sudo: true

# Enable faillock account lockout protection (default: true)
ssh_2fa_faillock_enabled: true

# Enable custom SSH banner (default: true)
ssh_2fa_banner_enabled: true

# Enable FIDO2-only SSH authentication (default: false)
# Restricts SSH to hardware security keys only
ssh_2fa_fido2_only: false

# Enable root-owned TOTP for sudo MFA (default: false)
# Stores TOTP secrets in root-owned directory
ssh_2fa_totp_root_owned: false
```

### Faillock Configuration

```yaml
# Number of failed attempts before account lockout
ssh_2fa_faillock_deny: 5

# Time window for counting failures (seconds)
# 900 = 15 minutes
ssh_2fa_faillock_interval: 900

# Account auto-unlock time (seconds)
# 600 = 10 minutes, 0 = manual unlock only
ssh_2fa_faillock_unlock_time: 600

# Apply lockout to root account
ssh_2fa_faillock_even_deny_root: false

# Root unlock time (if even_deny_root enabled)
ssh_2fa_faillock_root_unlock_time: 60

# Tally directory (/var/run/faillock = tmpfs, cleared on reboot)
ssh_2fa_faillock_dir: /var/run/faillock

# Enable audit logging for faillock events
ssh_2fa_faillock_audit_enabled: true
```

### SSH Configuration

```yaml
# SSH port
ssh_2fa_port: 22

# Authentication methods (publickey + 2FA)
ssh_2fa_auth_methods: "publickey,keyboard-interactive"

# Disable password authentication
ssh_2fa_password_authentication: "no"

# Maximum authentication attempts
ssh_2fa_max_auth_tries: 3

# Client timeout settings
ssh_2fa_client_alive_interval: 300
ssh_2fa_client_alive_count_max: 2
```

### Break-glass Configuration

```yaml
# Enable break-glass access
ssh_2fa_break_glass_enabled: true

# Users exempt from 2FA (emergency access)
ssh_2fa_break_glass_users:
  - malpanez
  - admin

# Require break-glass users to exist before enabling 2FA
ssh_2fa_require_break_glass_ready: false
```

### FIDO2 Configuration

```yaml
# Allowed public key algorithms for FIDO2
ssh_2fa_fido2_pubkey_algorithms:
  - sk-ssh-ed25519@openssh.com        # FIDO2 Ed25519
  - sk-ecdsa-sha2-nistp256@openssh.com # FIDO2 ECDSA
  - ssh-ed25519                        # Standard Ed25519 (fallback)
  - rsa-sha2-512                       # RSA with SHA-512
  - rsa-sha2-256                       # RSA with SHA-256
```

### Root-Owned TOTP Configuration

```yaml
# Base directory for root-owned TOTP secrets
ssh_2fa_totp_secret_base: /var/lib/pam-google-authenticator

# Group whose members require TOTP for sudo
ssh_2fa_mfa_required_group: mfa-required

# Users to provision with TOTP (optional)
ssh_2fa_totp_users:
  - alice
  - bob

# PAM Google Authenticator options for root-owned TOTP
ssh_2fa_pam_google_authenticator_root_owned_options: "secret=/var/lib/pam-google-authenticator/${USER}/.google_authenticator user=root"
```

### Package Requirements

```yaml
ssh_2fa_packages:
  - openssh-server
  - libpam-google-authenticator
  - libpam-modules
  - libpam-modules-bin
  - libqrencode4
  - qrencode
```

## Example Playbook

### Basic Usage

```yaml
---
- name: Deploy SSH 2FA with faillock protection
  hosts: all
  become: true
  roles:
    - role: ssh_2fa
```

### Custom Configuration

```yaml
---
- name: Deploy SSH 2FA with custom settings
  hosts: all
  become: true
  roles:
    - role: ssh_2fa
      vars:
        ssh_2fa_faillock_deny: 3
        ssh_2fa_faillock_unlock_time: 1800
        ssh_2fa_break_glass_users:
          - admin
          - emergency
```

### Disable Faillock (2FA only)

```yaml
---
- name: Deploy SSH 2FA without faillock
  hosts: all
  become: true
  roles:
    - role: ssh_2fa
      vars:
        ssh_2fa_faillock_enabled: false
```

## Usage

### Setting Up 2FA for Users

#### Option 1: Google Authenticator (TOTP)

```bash
# Run as the user who needs 2FA
google-authenticator

# Follow prompts:
# - Scan QR code with Google Authenticator app
# - Save emergency scratch codes
# - Answer setup questions
```

#### Option 2: Yubikey (U2F)

```bash
# Run the provided setup script
sudo /usr/local/bin/setup-2fa-yubikey.sh

# Follow prompts to register Yubikey
```

### Managing Faillock

#### Check User Lockout Status

```bash
# Check specific user
sudo faillock --user <username>

# List all locked users
sudo faillock
```

#### Unlock User Account

```bash
# Unlock specific user
sudo faillock --user <username> --reset

# Unlock all users
sudo faillock --reset
```

#### Monitor Failed Attempts

```bash
# View faillock tally directory
ls -la /var/run/faillock/

# View audit logs for faillock events
sudo ausearch -k faillock_tally
```

### Emergency Access (Break-glass)

#### Scenario: Locked Out of SSH

**Method 1: Console Access (IPMI/KVM)**

```bash
# Boot to single-user mode
# In GRUB, edit kernel line and add: single

# Or boot normally and login at console
# Root is exempt from lockout if even_deny_root=false
```

**Method 2: Temporarily Disable 2FA**

```bash
# From console/IPMI as root:
sudo pam-auth-update --disable faillock --package
```

**Method 3: Reset Faillock Counters**

```bash
# Clear all failed attempt counters
sudo faillock --reset

# Or remove tally files
sudo rm -rf /var/run/faillock/*
```

## Break-glass Procedures

### Documented Recovery Paths

1. **Console/IPMI Access**
   - Physical console or remote IPMI/KVM
   - Root account can login (if `even_deny_root: false`)
   - Break-glass users in `ansible-automation` group

2. **Emergency Unlock Commands**
   ```bash
   # Unlock specific user
   sudo faillock --user <username> --reset

   # Disable faillock temporarily
   sudo pam-auth-update --disable faillock --package

   # Re-enable after emergency
   sudo pam-auth-update --enable faillock --package
   ```

3. **Boot to Single-User Mode**
   - Edit GRUB: append `single` to kernel line
   - System boots with minimal services
   - No PAM authentication required

4. **Reboot to Clear Faillock (if tmpfs)**
   - Default: `/var/run/faillock` (tmpfs)
   - Cleared on reboot
   - Use persistent directory for production

## Transition from Break-glass to Full 2FA

This section describes how to transition deployment users (like `malpanez`) from break-glass access to full 2FA after infrastructure is deployed and verified.

### Current Setup (During Deployment)

The `malpanez` user is configured as a break-glass user for safe deployment:

```yaml
ssh_2fa_break_glass_enabled: true
ssh_2fa_break_glass_users:
  - malpanez  # Deployment user, no 2FA during setup
```

**Benefits:**
- Can deploy and modify infrastructure without 2FA prompts
- Member of `ansible-automation` group (SSH key only)
- Fast iteration during development
- Emergency access if 2FA configuration fails

### Transition Strategy (After Deployment Complete)

Once all infrastructure is deployed, tested, and verified, transition to full security:

**Step 1: Create Dedicated Ansible Service Account (Recommended)**

```yaml
# In your playbook or group_vars
ssh_2fa_create_ansible_user: true
ssh_2fa_ansible_user_name: ansible
ssh_2fa_ansible_sudo_method: group  # Best practice: group-based
ssh_2fa_ansible_user_sudo_nopasswd: true  # For automation
```

This creates a dedicated `ansible` user with:
- **Break-glass SSH access**: Member of `ansible-automation` group (SSH key only, no 2FA)
- **NOPASSWD sudo**: Via `/etc/sudoers.d/ansible-automation` for the group
- **Separate from admin users**: `malpanez` stays in built-in `sudo` group for admin access
- **Best practice**: Uses custom group instead of polluting `sudo`/`wheel` with service accounts

**Why group-based sudo?**
- Multiple service accounts can share the same policy
- `malpanez` user keeps existing `sudo` group membership (unaffected)
- `ansible` user only needs `ansible-automation` group membership
- Both users can use the same SSH public key
- Easier to audit: `getent group ansible-automation` shows all break-glass users

**Step 2: Provision 2FA for malpanez**

```bash
# Option A: Standard TOTP (Google Authenticator app)
ssh malpanez@server
google-authenticator
# Scan QR code, save emergency codes

# Option B: YubiKey FIDO2 for SSH + OATH for sudo
# On client: Generate FIDO2 key
ssh-keygen -t ed25519-sk -O resident -O verify-required -f ~/.ssh/id_fido2_malpanez

# On server: Provision YubiKey OATH for sudo
sudo /usr/local/bin/provision-yubikey-oath.sh malpanez
sudo usermod -aG mfa-required malpanez
```

**Step 3: Test 2FA Works**

```bash
# Test from a different session (keep current SSH session open!)
ssh malpanez@server
# Should prompt for: SSH key + TOTP code

# Test sudo (if root-owned TOTP enabled)
sudo -v
# Should prompt for: password + TOTP code
```

**Step 4: Remove from Break-glass**

Update your inventory or group_vars:

```yaml
# Remove malpanez from break-glass list
ssh_2fa_break_glass_users: []

# Or keep for emergencies but with 2FA provisioned
ssh_2fa_break_glass_users:
  - emergency_admin  # Different user for true emergencies
```

Re-run the playbook:

```bash
ansible-playbook -i inventory/production site.yml --tags ssh-2fa
```

**Step 5: Verify Full 2FA Enforcement**

```bash
# Check SSH config
ssh malpanez@server 'sudo grep -A20 "Match All" /etc/ssh/sshd_config.d/50-2fa.conf'
# Should show: AuthenticationMethods publickey,keyboard-interactive

# Verify malpanez NOT in break-glass group
ssh malpanez@server 'groups'
# Should NOT show ansible-automation group
```

### Recommended Final Configuration

```yaml
---
# Production hardened configuration
ssh_2fa_enable_ssh: true
ssh_2fa_enable_sudo: true
ssh_2fa_faillock_enabled: true

# FIDO2-only SSH (optional)
ssh_2fa_fido2_only: true

# Root-owned TOTP for sudo
ssh_2fa_totp_root_owned: true
ssh_2fa_mfa_required_group: mfa-required

# Create dedicated ansible service user
ssh_2fa_create_ansible_user: true

# Break-glass: Only dedicated service account
ssh_2fa_break_glass_enabled: true
ssh_2fa_break_glass_users: []  # ansible user via ansible-automation group only

# Users requiring sudo TOTP
ssh_2fa_totp_users:
  - malpanez
  - ops_user
```

### Rollback Procedure

If issues occur after removing break-glass:

```bash
# Via console/IPMI
sudo vi /etc/ssh/sshd_config.d/50-2fa.conf

# Add at the top (before Match All):
# Match User malpanez
#     AuthenticationMethods publickey

sudo systemctl restart sshd
```

Or temporarily disable 2FA:

```bash
# Via console
sudo mv /etc/ssh/sshd_config.d/50-2fa.conf /etc/ssh/sshd_config.d/50-2fa.conf.disabled
sudo systemctl restart sshd
```

## Security Considerations

### PAM Stack Ordering

The role uses a modular approach with `pam-auth-update` to ensure correct ordering:

1. `pam_faillock.so preauth` (check if locked)
2. `pam_unix.so` (password/key authentication)
3. `pam_google_authenticator.so` (2FA token)
4. `pam_faillock.so authfail` (record failure)
5. `pam_faillock.so authsucc` (clear on success)

### Break-glass Best Practices

- **Always configure break-glass before enabling 2FA**
- Verify break-glass users have SSH keys
- Test break-glass access before full deployment
- Document recovery procedures
- Keep at least one break-glass user per system

### Faillock Configuration Trade-offs

| Setting | Low Security | Balanced | High Security |
|---------|--------------|----------|---------------|
| `deny` | 10 | 5 | 3 |
| `unlock_time` | 300 | 600 | 1800 |
| `even_deny_root` | false | false | true |

## Testing

### Run Molecule Tests

```bash
cd ansible/roles/ssh_2fa
molecule test
```

### Manual Testing

```bash
# Test SSH 2FA
ssh user@hostname
# Should prompt for SSH key + 2FA token

# Test faillock
for i in {1..6}; do
  ssh baduser@hostname
done
sudo faillock --user baduser

# Test break-glass
ssh breakglass-user@hostname
# Should only prompt for SSH key (no 2FA)
```

## Troubleshooting

### Issue: Locked Out of SSH

**Solution:**
1. Access via console/IPMI
2. Check faillock status: `sudo faillock --user <username>`
3. Reset: `sudo faillock --user <username> --reset`

### Issue: 2FA Not Working

**Check PAM configuration:**
```bash
# Verify 2FA module is enabled
grep -r pam_google_authenticator /etc/pam.d/

# Check sshd config
grep ChallengeResponseAuthentication /etc/ssh/sshd_config.d/*.conf

# Test PAM stack manually (requires pamtester)
pamtester sshd <username> authenticate
```

### Issue: Faillock Not Activating

**Verify faillock is enabled:**
```bash
# Check pam-auth-update status
pam-auth-update --list

# Verify PAM configuration
grep pam_faillock /etc/pam.d/common-auth

# Check faillock.conf
cat /etc/security/faillock.conf
```

### Issue: Break-glass Not Working

**Verify group membership:**
```bash
# Check user is in ansible-automation group
groups <username>

# Check PAM rule
grep ansible-automation /etc/pam.d/sshd-2fa
```

## Advanced Features

### FIDO2 Security Key Authentication

The role supports FIDO2 hardware security keys (YubiKey 5+, SoloKey, etc.) for SSH authentication.

**Configuration:**

```yaml
# Enable FIDO2-only SSH authentication
ssh_2fa_fido2_only: true

# Restrict to FIDO2 and strong key algorithms
ssh_2fa_fido2_pubkey_algorithms:
  - sk-ssh-ed25519@openssh.com
  - sk-ecdsa-sha2-nistp256@openssh.com
  - ssh-ed25519
  - rsa-sha2-512
  - rsa-sha2-256
```

**Generating FIDO2 Keys:**

```bash
# On client workstation
ssh-keygen -t ed25519-sk -O resident -O verify-required \
           -f ~/.ssh/id_fido2 \
           -C "user@two-minds-trading"

# Options:
#   -O resident: Store key on security key (portable)
#   -O verify-required: Require PIN/biometric for each use

# Copy public key to server
cat ~/.ssh/id_fido2.pub  # Add to server's ~/.ssh/authorized_keys
```

**Authentication Workflow:**

1. User runs: `ssh -i ~/.ssh/id_fido2 user@server`
2. YubiKey LED flashes - user touches key
3. If PIN enabled - user enters PIN
4. SSH session established

**Requirements:**

- OpenSSH 8.2+ (client and server)
- libfido2 library on client
- FIDO2-compliant security key

### Root-Owned TOTP for Sudo MFA

Advanced configuration that stores TOTP secrets in root-owned directories, preventing users from tampering with their own secrets.

**Configuration:**

```yaml
# Enable root-owned TOTP for sudo
ssh_2fa_totp_root_owned: true

# Secret storage location
ssh_2fa_totp_secret_base: /var/lib/pam-google-authenticator

# Group requiring TOTP for sudo
ssh_2fa_mfa_required_group: mfa-required

# Users to provision (optional)
ssh_2fa_totp_users:
  - alice
  - bob
```

**Architecture:**

This feature uses a PAM substack approach to guarantee TOTP execution for sudo operations:

1. User runs sudo command
2. PAM checks if user in `mfa-required` group
3. If yes, password + TOTP code required
4. TOTP secret read from `/var/lib/pam-google-authenticator/${USER}/.google_authenticator`
5. Secret owned by root:root (0400) - user cannot read/modify

**Provisioning TOTP Secrets:**

```bash
# Standard TOTP (scan QR with app)
sudo /usr/local/bin/provision-totp-sudo.sh <username>

# YubiKey OATH (store TOTP on YubiKey)
sudo /usr/local/bin/provision-yubikey-oath.sh <username>

# Add user to MFA group
sudo usermod -aG mfa-required <username>

# Test
su - <username> -c 'sudo -v'
# Prompts for: password + TOTP code
```

**Using YubiKey for TOTP:**

```bash
# Install YubiKey Manager
pip3 install yubikey-manager

# Generate codes
ykman oath accounts code 'username@hostname'
# Touch YubiKey when LED flashes
```

**Security Benefits:**

- Users cannot disable/modify their own TOTP
- Secrets stored outside user home directories
- Root-only access to secrets
- Survives home directory deletion
- Centralized secret management

### Combined FIDO2 + Root-Owned TOTP

For maximum security, combine both features:

```yaml
# SSH: FIDO2 security keys only
ssh_2fa_fido2_only: true

# Sudo: Password + TOTP (root-owned)
ssh_2fa_totp_root_owned: true
```

**Workflow:**

1. **SSH Access:** User authenticates with FIDO2 key (touch YubiKey)
2. **Sudo Operations:** User provides password + TOTP code (from same YubiKey)
3. **Two Different YubiKey Functions:**
   - FIDO2 resident key for SSH
   - OATH/TOTP applet for sudo

**Provisioning Example:**

```bash
# 1. Client generates FIDO2 SSH key
ssh-keygen -t ed25519-sk -O resident -O verify-required

# 2. Server provisions YubiKey OATH
sudo /usr/local/bin/provision-yubikey-oath.sh alice
sudo usermod -aG mfa-required alice

# 3. User logs in
ssh -i ~/.ssh/id_ed25519_sk alice@server  # Touch YubiKey
sudo whoami  # Enter password + touch YubiKey for TOTP
```

## Compliance Mapping

This role helps meet requirements from:

- **NIST 800-53:** IA-2, IA-5, AC-7, IA-2(1) (Multi-factor authentication)
- **CIS Benchmarks:** 5.2.x (SSH hardening), 5.3.x (PAM)
- **ISO 27001:** A.9.2 (User access management), A.9.4.2 (Secure log-on)
- **PCI DSS:** 8.2 (Multi-factor authentication), 8.3 (Secure authentication)

## Files Created/Modified

### Created Files

**Core 2FA and Faillock:**

- `/etc/security/faillock.conf` - Faillock configuration
- `/etc/pam.d/sshd-2fa` - SSH 2FA PAM module
- `/etc/pam.d/sudo-2fa` - Sudo 2FA PAM module (standard mode)
- `/etc/ssh/sshd_config.d/50-2fa.conf` - SSH 2FA config
- `/etc/ssh/sshd_config.d/99-hardening.conf` - SSH hardening
- `/etc/audit/rules.d/99-faillock.rules` - Faillock audit rules
- `/usr/share/pam-configs/faillock` - Faillock PAM profile
- `/usr/local/bin/setup-2fa-yubikey.sh` - Yubikey setup script

**FIDO2 Security Keys (when `ssh_2fa_fido2_only: true`):**

- `/etc/ssh/sshd_config.d/20-fido2.conf` - FIDO2-only SSH config with PubkeyAcceptedAlgorithms restriction

**Root-Owned TOTP (when `ssh_2fa_totp_root_owned: true`):**

- `/etc/pam.d/mfa-totp` - MFA TOTP PAM substack for sudo
- `/var/lib/pam-google-authenticator/` - Root-owned TOTP secret base directory
- `/var/lib/pam-google-authenticator/${USER}/.google_authenticator` - Per-user TOTP secrets (root:root 0400)
- `/usr/local/bin/provision-totp-sudo.sh` - TOTP provisioning script
- `/usr/local/bin/provision-yubikey-oath.sh` - YubiKey OATH provisioning script

### Modified Files

- `/etc/pam.d/sshd` - Includes `sshd-2fa` module
- `/etc/pam.d/sudo` - Includes `sudo-2fa` module OR mfa-totp substack (if root-owned TOTP enabled)
- `/etc/ssh/sshd_config` - Include directive for drop-ins

## License

MIT

## Author Information

Created by: Miguel Alpañez Alcalde
Organization: Two Minds Trading Infrastructure
Date: 2026-01-07

## References

- [PAM Documentation](http://www.linux-pam.org/)
- [pam_faillock(8)](https://man7.org/linux/man-pages/man8/pam_faillock.8.html)
- [Google Authenticator PAM](https://github.com/google/google-authenticator-libpam)
- [OpenSSH Security Best Practices](https://www.openssh.com/security.html)
