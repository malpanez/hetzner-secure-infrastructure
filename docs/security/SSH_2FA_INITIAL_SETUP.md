# SSH 2FA Initial Setup Guide

**Purpose**: How to capture and configure your 2FA for SSH access
**Date**: 2026-01-02

---

## Understanding the Setup

When Ansible configures SSH 2FA on your server, it:
1. Installs Google Authenticator (`libpam-google-authenticator`)
2. Configures SSH to require both SSH key + TOTP code
3. Generates a TOTP secret for your user
4. Creates a QR code you need to scan with your phone

---

## Step-by-Step Initial Setup

### Option 1: Manual Setup (First Time)

If you're setting up 2FA for the first time on a server:

```bash
# 1. SSH to server (before 2FA is enabled)
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# 2. Run Google Authenticator setup
google-authenticator

# Follow the prompts:
# - "Do you want authentication tokens to be time-based?" → YES
# - Scan the QR code with your phone (Google Authenticator app)
# - Save emergency scratch codes in a secure location
# - "Do you want me to update your ~/.google_authenticator file?" → YES
# - "Do you want to disallow multiple uses?" → YES
# - "Do you want to increase window?" → NO
# - "Do you want to enable rate-limiting?" → YES

# 3. Test 2FA works
# Exit and reconnect - you should be prompted for:
# 1. SSH key passphrase (if set)
# 2. Verification code (from Google Authenticator app)
```

### Option 2: Ansible Automated Setup

If Ansible has already configured 2FA, you need to retrieve the setup:

```bash
# 1. SSH to server (using break-glass key if 2FA is already active)
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# 2. Check if 2FA is already configured
ls -la ~/.google_authenticator

# 3. If file exists, you can regenerate the QR code
google-authenticator -t -d -f -r 3 -R 30 -w 3

# This will:
# - Show QR code in terminal
# - Display secret key
# - Generate new emergency codes
```

---

## Capturing the QR Code

### Method 1: Direct Terminal Display (SSH from Linux/Mac)

The QR code displays directly in your terminal:

```
┌─────────────────────────────────┐
│█████████████████████████████████│
│██ ▄▄▄▄▄ █▀█ █▄▄▀▀▀▄█ ▄▄▄▄▄ ██│
│██ █   █ █▀▀▀█ ▀█▄ ▄█ █   █ ██│
│██ █▄▄▄█ █▀ █▀▀█  █▀█ █▄▄▄█ ██│
│██▄▄▄▄▄▄▄█▄▀ ▀▄█▄▀ █▄▄▄▄▄▄▄██│
│██  ▄█▀▄▄ ▀▀▀▄ ▀▀█▄▄▀█▄█ ▀▄ ██│
└─────────────────────────────────┘

Your new secret key is: JBSWY3DPEHPK3PXP
```

**Scan this with Google Authenticator app on your phone**

### Method 2: Get Secret Key (Manual Entry)

If you can't scan the QR code:

1. The secret key is displayed below QR code
2. Open Google Authenticator app
3. Tap "+" → "Enter a setup key"
4. Enter:
   - Account name: `malpanez@hetzner`
   - Your key: `JBSWY3DPEHPK3PXP` (example)
   - Type of key: Time based

### Method 3: SSH from Windows (WSL/PowerShell)

If QR code doesn't display properly:

```bash
# Generate QR code as image
qrencode -o ~/2fa-qr.png "otpauth://totp/malpanez@hetzner?secret=JBSWY3DPEHPK3PXP"

# Copy to local machine
scp -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP:~/2fa-qr.png .

# Open the image and scan with phone
```

---

## Emergency Scratch Codes

**CRITICAL**: Save these codes! Each can be used ONCE if you lose your phone:

```
12345678
87654321
11223344
44332211
99887766
```

**How to use**:
1. SSH to server: `ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP`
2. When prompted for "Verification code:", enter one of these codes
3. Code is consumed - can't be reused
4. Generate new codes: `google-authenticator -r`

**Where to store**:
- ✅ Password manager (1Password, Bitwarden, LastPass)
- ✅ Encrypted file on USB drive
- ✅ Printed paper in safe
- ❌ NOT in plaintext on your computer
- ❌ NOT in cloud notes (Evernote, Google Keep)

---

## Recommended 2FA Apps

### Best Options

1. **Google Authenticator** (iOS/Android)
   - Simple, reliable
   - No backup (lose phone = lose codes)
   - Free

2. **Authy** (iOS/Android/Desktop)
   - Cloud backup (encrypted)
   - Multi-device sync
   - Free
   - **Recommended** if you want backup

3. **1Password** (if you use it)
   - Integrates with password manager
   - Automatic backup
   - Costs $2.99-7.99/month

### Setup in Google Authenticator

```
1. Open Google Authenticator app
2. Tap "+" (bottom right)
3. Select "Scan a QR code"
4. Point camera at QR code in terminal
5. Entry appears: "malpanez@hetzner" with 6-digit code
6. Done!
```

---

## Testing Your 2FA Setup

### Test 1: SSH Login

```bash
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# You should see:
# 1. SSH key accepted
# 2. Prompt: "Verification code:"
# 3. Enter 6-digit code from authenticator app
# 4. Login successful
```

### Test 2: Break-Glass Access

Test that your ansible user still works WITHOUT 2FA:

```bash
# After ansible user is created
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP

# Should NOT prompt for verification code
# Should login directly with key only
```

### Test 3: Emergency Codes

```bash
# Test one scratch code (use the last one)
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP
# Enter scratch code instead of TOTP code
# Should work ONCE

# Regenerate codes after testing
google-authenticator -r
```

---

## Current Configuration Status

### Your Account (malpanez)

- **SSH Key**: `~/.ssh/github_ed25519`
- **2FA**: ✅ ENABLED (after Ansible runs ssh_2fa role)
- **Sudo**: ✅ Passwordless (for specific commands)
- **Break-glass**: ✅ Emergency scratch codes

### Ansible Automation User

- **SSH Key**: `~/.ssh/ansible_automation` (Ed25519)
- **2FA**: ❌ DISABLED (key-based only)
- **Purpose**: Automated deployments
- **Security**: Enhanced logging + Fail2ban monitoring

---

## Troubleshooting

### QR Code Not Displaying

```bash
# If terminal doesn't support QR codes
google-authenticator -t -d -f -r 3 -R 30 -w 3 -s ~/.google_authenticator

# Look for this line:
# Your new secret key is: JBSWY3DPEHPK3PXP

# Manually create URL
echo "otpauth://totp/malpanez@hetzner?secret=JBSWY3DPEHPK3PXP&issuer=Hetzner"

# Visit: https://www.qr-code-generator.com/
# Paste URL, generate QR code, scan with phone
```

### Lost Phone / Can't Access 2FA

**Option 1: Use Emergency Scratch Code**
```bash
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP
# Enter scratch code when prompted
```

**Option 2: Use Ansible User**
```bash
# Login with ansible user (no 2FA)
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP

# Become your user
sudo -u malpanez bash

# Regenerate 2FA
google-authenticator

# Scan new QR code with new phone
```

**Option 3: Break-Glass SSH (if configured)**
```bash
# Use emergency SSH key (if you set one up)
ssh -i ~/.ssh/emergency_key malpanez@YOUR_SERVER_IP
```

### 2FA Codes Not Working

**Check time sync**:
```bash
# On server
timedatectl

# Time should be accurate to within 30 seconds
# If not:
sudo timedatectl set-ntp true
```

**Check phone time**:
- Settings → Date & Time → Set Automatically

**Regenerate if needed**:
```bash
# Remove old config
rm ~/.google_authenticator

# Generate new
google-authenticator

# Scan new QR code
```

---

## Migration to New Phone

### Before Losing Access to Old Phone

**Method 1: Transfer Within App (Authy only)**
- Authy has cloud backup
- Login on new phone with same account
- Codes transfer automatically

**Method 2: Re-scan QR Code**
```bash
# SSH to server
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# Show QR code again (doesn't regenerate)
qrencode -t UTF8 "$(cat ~/.google_authenticator | head -1 | sed 's/^/otpauth:\/\/totp\/malpanez@hetzner?secret=/')"

# Scan with new phone
```

**Method 3: Generate New Secret**
```bash
# Regenerate entirely
google-authenticator

# Scan new QR with new phone
# Old phone codes stop working
```

### After Losing Old Phone

Use emergency scratch codes or ansible user to regain access, then regenerate.

---

## Security Best Practices

### Do This ✅

1. **Save emergency codes** in password manager
2. **Test 2FA** before logging out
3. **Keep phone charged** (obvious but important)
4. **Use Authy** if you want cloud backup
5. **Test break-glass** ansible user access
6. **Regenerate codes** after using scratch codes
7. **Document** where you saved codes

### Don't Do This ❌

1. ❌ Don't disable 2FA because "it's annoying"
2. ❌ Don't share TOTP secret key
3. ❌ Don't screenshot QR code and leave on phone
4. ❌ Don't use SMS-based 2FA (insecure)
5. ❌ Don't panic if you lose phone (use scratch codes)

---

## Quick Reference Commands

```bash
# Show current 2FA status
cat ~/.google_authenticator

# Regenerate QR code (same secret)
qrencode -t UTF8 "otpauth://totp/malpanez@hetzner?secret=$(head -1 ~/.google_authenticator)"

# Generate new scratch codes (keeps same secret)
google-authenticator -r

# Completely reset 2FA
rm ~/.google_authenticator && google-authenticator

# Test SSH with 2FA
ssh -i ~/.ssh/github_ed25519 malpanez@YOUR_SERVER_IP

# Test ansible user (no 2FA)
ssh -i ~/.ssh/ansible_automation ansible@YOUR_SERVER_IP

# Check if 2FA is enforced in SSH config
grep -r "AuthenticationMethods" /etc/ssh/sshd_config.d/
```

---

## Summary

**What you need**:
1. ✅ SSH key (`~/.ssh/github_ed25519`)
2. ✅ Google Authenticator app on phone
3. ✅ Emergency scratch codes saved safely
4. ✅ Ansible automation key for break-glass access

**Setup process**:
1. Run Ansible playbook (configures 2FA)
2. SSH to server manually
3. Run `google-authenticator`
4. Scan QR code with phone
5. Save scratch codes
6. Test login

**In case of emergency**:
1. Use scratch code to login
2. Or use ansible user to regain access
3. Regenerate 2FA with `google-authenticator`

---

**Related Documentation**:
- [SSH 2FA Break-Glass Procedure](SSH_2FA_BREAK_GLASS.md)
- [Deployment Automation Setup](../guides/DEPLOYMENT_AUTOMATION_SETUP.md)
