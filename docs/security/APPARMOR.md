# AppArmor Complete Guide for Debian

## 📚 Table of Contents

1. [What is AppArmor?](#what-is-apparmor)
2. [AppArmor vs SELinux](#apparmor-vs-selinux)
3. [Installation and Setup](#installation-and-setup)
4. [Understanding Profiles](#understanding-profiles)
5. [Creating Custom Profiles](#creating-custom-profiles)
6. [Managing Profiles](#managing-profiles)
7. [Troubleshooting](#troubleshooting)
8. [Best Practices](#best-practices)
9. [Real World Examples](#real-world-examples)

---

## What is AppArmor?

**AppArmor** (Application Armor) is a **Mandatory Access Control (MAC)** security system for Linux. It confines programs to a limited set of resources through **profiles**.

### Key Concepts

- **Profile**: Defines what resources a program can access
- **Enforce mode**: Violations are blocked and logged
- **Complain mode**: Violations are logged but allowed (for testing)
- **Path-based**: Controls access based on file paths (unlike SELinux which is label-based)

### Why AppArmor?

✅ **Easier than SELinux** - Path-based policies are more intuitive  
✅ **Default in Debian/Ubuntu** - Built-in and well-supported  
✅ **Defense in depth** - Additional layer beyond DAC (file permissions)  
✅ **Protects against 0-days** - Limits damage from compromised processes

---

## AppArmor vs SELinux

| Feature | AppArmor | SELinux |
|---------|----------|---------|
| **Approach** | Path-based | Label-based |
| **Complexity** | Lower | Higher |
| **Default in** | Debian, Ubuntu, SUSE | RHEL, CentOS, Fedora |
| **Learning curve** | Easier | Steeper |
| **Granularity** | Good | Excellent |
| **Performance** | Similar | Similar |

**Use AppArmor when:**

- You're on Debian/Ubuntu
- You want simpler profile management
- Path-based security model makes sense for your use case

**Use SELinux when:**

- You're on RHEL/CentOS
- You need very fine-grained control
- You have experience with it

---

## Installation and Setup

### On Debian 12/13

```bash
# Install AppArmor
sudo apt update
sudo apt install -y apparmor apparmor-utils apparmor-profiles apparmor-profiles-extra

# Enable AppArmor (should be default)
sudo systemctl enable apparmor
sudo systemctl start apparmor

# Verify it's running
sudo systemctl status apparmor

# Check kernel parameters
cat /proc/cmdline | grep apparmor
# Should see: apparmor=1 security=apparmor
```

### Enable in GRUB (if not enabled)

```bash
# Edit GRUB config
sudo nano /etc/default/grub

# Add to GRUB_CMDLINE_LINUX_DEFAULT:
GRUB_CMDLINE_LINUX_DEFAULT="quiet apparmor=1 security=apparmor"

# Update GRUB
sudo update-grub

# Reboot
sudo reboot
```

### Verify Installation

```bash
# Check AppArmor status
sudo aa-status

# Output shows:
# - apparmor module is loaded
# - X profiles are loaded
# - Y profiles are in enforce mode
# - Z profiles are in complain mode
```

---

## Understanding Profiles

### Profile Locations

```bash
/etc/apparmor.d/          # Main profiles directory
/etc/apparmor.d/local/    # Local customizations
/etc/apparmor.d/tunables/ # Tunable variables
/etc/apparmor.d/abstractions/ # Reusable components
```

### Profile Structure

```
#include <tunables/global>

/path/to/binary {
  #include <abstractions/base>
  
  capability cap_name,
  
  /path/to/file r,    # read
  /path/to/file w,    # write
  /path/to/file rw,   # read-write
  /path/to/file ix,   # execute (inherit)
  /path/to/file Px,   # execute (profile transition)
  /path/to/file Ux,   # execute (unconfined)
  
  network inet stream,
  
  # Child profile
  profile child_name {
    ...
  }
}
```

### Access Modes

| Mode | Meaning |
|------|---------|
| `r` | Read |
| `w` | Write |
| `a` | Append |
| `k` | Lock |
| `l` | Link |
| `ix` | Execute & inherit profile |
| `Px` | Execute with profile transition |
| `Cx` | Execute with child profile |
| `Ux` | Execute unconfined |
| `m` | Memory map executable |

### Capabilities

AppArmor can restrict Linux capabilities:

```
capability chown,           # Change file ownership
capability dac_override,    # Bypass file read/write/execute checks
capability dac_read_search, # Bypass file read/execute checks
capability kill,            # Send signals
capability net_admin,       # Network administration
capability net_raw,         # Use RAW/PACKET sockets
capability setgid,          # Change GID
capability setuid,          # Change UID
capability sys_admin,       # System administration
capability sys_chroot,      # Use chroot()
```

---

## Creating Custom Profiles

### Method 1: Auto-generate with aa-genprof (Recommended for beginners)

```bash
# 1. Put AppArmor in complain mode for the binary
sudo aa-complain /usr/bin/your-program

# 2. Generate profile interactively
sudo aa-genprof /usr/bin/your-program

# 3. In another terminal, use the program normally
# This generates access patterns

# 4. Back in aa-genprof terminal, scan logs
# Answer questions about each access

# 5. Save the profile

# 6. Set to enforce mode
sudo aa-enforce /usr/bin/your-program
```

### Method 2: Manual Creation

```bash
# Create profile file
sudo nano /etc/apparmor.d/usr.bin.myapp

# Basic template:
#include <tunables/global>

/usr/bin/myapp {
  #include <abstractions/base>
  
  # Binary itself
  /usr/bin/myapp mr,
  
  # Config files
  /etc/myapp/** r,
  
  # Data directory
  owner /var/lib/myapp/** rw,
  
  # Temp files
  /tmp/myapp-* rw,
  
  # Logs
  /var/log/myapp/*.log w,
  
  # Network (if needed)
  network inet stream,
  network inet6 stream,
  
  # Capabilities (if needed)
  capability net_bind_service,
}

# Load profile
sudo apparmor_parser -r /etc/apparmor.d/usr.bin.myapp

# Set to enforce
sudo aa-enforce /usr/bin/myapp
```

### Method 3: Use aa-logprof to refine existing profile

```bash
# Run app in complain mode
sudo aa-complain /usr/bin/myapp

# Use the application
# ... generate traffic/access patterns ...

# Review and update profile based on logs
sudo aa-logprof

# Answer questions about denied accesses
# Save changes

# Set back to enforce mode
sudo aa-enforce /usr/bin/myapp
```

---

## Managing Profiles

### Common Commands

```bash
# View status of all profiles
sudo aa-status

# View specific profile status
sudo aa-status --pretty-print | grep -A 5 sshd

# List all profiles
ls /etc/apparmor.d/

# Put profile in complain mode (testing)
sudo aa-complain /etc/apparmor.d/usr.sbin.sshd

# Put profile in enforce mode (production)
sudo aa-enforce /etc/apparmor.d/usr.sbin.sshd

# Disable profile
sudo aa-disable /etc/apparmor.d/usr.sbin.sshd
# This creates a symlink in /etc/apparmor.d/disable/

# Re-enable disabled profile
sudo aa-enable /etc/apparmor.d/usr.sbin.sshd
# Removes the symlink

# Reload specific profile
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.sshd

# Reload all profiles
sudo systemctl reload apparmor

# View denials in real-time
sudo aa-notify -s 1 -v

# Or from dmesg
sudo dmesg | grep -i apparmor | grep -i denied

# Or from audit log
sudo journalctl -b | grep -i apparmor | grep -i denied
```

### Profile Modes

1. **Enforce Mode** (Production):

   ```bash
   sudo aa-enforce /etc/apparmor.d/usr.sbin.sshd
   ```

   - Blocks violations
   - Logs denials

2. **Complain Mode** (Testing):

   ```bash
   sudo aa-complain /etc/apparmor.d/usr.sbin.sshd
   ```

   - Allows violations
   - Logs would-be denials
   - Perfect for testing

3. **Disabled**:

   ```bash
   sudo aa-disable /etc/apparmor.d/usr.sbin.sshd
   ```

   - Profile not loaded

---

## Troubleshooting

### Problem: Service fails after enabling AppArmor profile

**Solution:**

```bash
# 1. Put in complain mode
sudo aa-complain /etc/apparmor.d/usr.sbin.myservice

# 2. Restart service
sudo systemctl restart myservice

# 3. Check logs for denials
sudo journalctl -xe | grep apparmor
sudo dmesg | grep -i apparmor | grep -i denied

# 4. Use aa-logprof to add missing permissions
sudo aa-logprof

# 5. Try enforce mode again
sudo aa-enforce /etc/apparmor.d/usr.sbin.myservice
```

### Problem: Can't see what's being denied

**Solution:**

```bash
# Install apparmor-notify (for desktop)
sudo apt install apparmor-notify

# Or watch logs
sudo tail -f /var/log/syslog | grep apparmor

# Or use aa-notify
sudo aa-notify -s 1 -v

# Or check audit logs
sudo ausearch -m avc -ts recent
```

### Problem: Profile is too permissive

**Solution:**

```bash
# Review profile
sudo nano /etc/apparmor.d/usr.sbin.myapp

# Look for overly broad rules:
# BAD:  /** rwx,        (allows everything)
# BAD:  /tmp/** rwx,    (too broad)
# GOOD: /tmp/myapp-* rw,

# Remove Ux (unconfined execute) if possible
# Change: /bin/bash Ux,
# To:     /bin/bash Px -> bash_profile,

# Reload
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp
```

### Problem: Need to temporarily disable AppArmor

**For specific profile:**

```bash
sudo aa-disable /etc/apparmor.d/usr.sbin.sshd
```

**For entire system (NOT recommended):**

```bash
sudo systemctl stop apparmor
sudo systemctl disable apparmor

# To re-enable:
sudo systemctl enable apparmor
sudo systemctl start apparmor
```

---

## Best Practices

### 1. Start in Complain Mode

Always test new profiles in complain mode first:

```bash
sudo aa-complain /etc/apparmor.d/usr.sbin.myapp
# Use the application extensively
sudo aa-logprof  # Review and add permissions
sudo aa-enforce /etc/apparmor.d/usr.sbin.myapp
```

### 2. Use Abstractions

Don't reinvent the wheel. Use built-in abstractions:

```
#include <abstractions/base>           # Basic system access
#include <abstractions/authentication> # PAM, etc.
#include <abstractions/nameservice>    # DNS, /etc/hosts, etc.
#include <abstractions/ssl_certs>      # SSL certificates
#include <abstractions/python>         # Python apps
#include <abstractions/perl>           # Perl apps
```

### 3. Principle of Least Privilege

Only grant what's needed:

```
# BAD
/var/log/** rw,

# GOOD
/var/log/myapp/myapp.log w,
```

### 4. Use Owner Rules

Restrict to file owner:

```
# Anyone can read:
/home/*/.ssh/config r,

# Only owner can read:
owner /home/*/.ssh/config r,
```

### 5. Document Your Profiles

```
# AppArmor profile for MyApp
# Purpose: Web application serving static content
# Requirements:
#   - Read access to /var/www
#   - Network binding on port 8080
#   - No write access needed
```

### 6. Regular Audits

```bash
# Monthly: Review denials
sudo aa-notify -s 30 -v > apparmor-denials.txt

# Quarterly: Review all profiles
sudo aa-status

# Annually: Review and update profiles
```

### 7. Test Profile Changes

```bash
# Before making profile changes:
sudo cp /etc/apparmor.d/usr.sbin.myapp /etc/apparmor.d/usr.sbin.myapp.backup

# After changes:
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp
# Test thoroughly

# If problems:
sudo mv /etc/apparmor.d/usr.sbin.myapp.backup /etc/apparmor.d/usr.sbin.myapp
sudo apparmor_parser -r /etc/apparmor.d/usr.sbin.myapp
```

---

## Real World Examples

### Example 1: SSH Daemon (SSHD)

Our Ansible deployment includes a complete SSHD profile. Key points:

```
/usr/sbin/sshd {
  #include <abstractions/authentication>
  #include <abstractions/nameservice>
  
  # Capabilities needed
  capability sys_chroot,      # For privilege separation
  capability setuid,          # To drop privileges
  capability setgid,
  
  # SSH config
  /etc/ssh/sshd_config r,
  /etc/ssh/ssh_host_*_key r,
  
  # PAM (for 2FA)
  /etc/pam.d/sshd r,
  owner @{HOME}/.google_authenticator r,
  
  # Yubikey FIDO2
  /dev/hidraw* rw,
  
  # User shells (transition)
  /bin/bash Ux,  # Unconfined for user sessions
}
```

**Why this works:**

- SSH needs special capabilities for privilege separation
- Yubikey FIDO2 needs hidraw device access
- User shells run unconfined (users aren't confined by SSH profile)

### Example 2: Web Server (Nginx)

```
#include <tunables/global>

/usr/sbin/nginx {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/ssl_certs>
  
  capability dac_override,
  capability setuid,
  capability setgid,
  capability net_bind_service,
  
  # Binary
  /usr/sbin/nginx mr,
  
  # Config
  /etc/nginx/** r,
  
  # Web content (read-only)
  /var/www/** r,
  /usr/share/nginx/** r,
  
  # Logs
  /var/log/nginx/*.log w,
  
  # Runtime
  /run/nginx.pid rw,
  
  # Network
  network inet stream,
  network inet6 stream,
  
  # No write to web content!
}
```

### Example 3: Fail2ban

See the complete profile in `ansible/roles/apparmor/templates/apparmor.d/usr.bin.fail2ban-server.j2`

Key points:

- Needs to read log files
- Needs net_admin capability for iptables
- Child profile for iptables commands
- No write access to anything except its own state

### Example 4: Custom Python Application

```
#include <tunables/global>

/usr/bin/python3.11 flags=(attach_disconnected) {
  #include <abstractions/base>
  #include <abstractions/python>
  
  # Python binary
  /usr/bin/python3.11 mr,
  
  # Your app
  /opt/myapp/** r,
  /opt/myapp/myapp.py r,
  
  # App-specific data
  owner /var/lib/myapp/** rw,
  
  # Config (read-only)
  /etc/myapp/*.conf r,
  
  # Logs
  /var/log/myapp/*.log w,
  
  # Temp files (scoped to app)
  owner /tmp/myapp-* rw,
  
  # Network if needed
  network inet stream,
  
  # Database socket
  /var/run/postgresql/.s.PGSQL.5432 rw,
  
  # No shell access
  deny /bin/** x,
  deny /usr/bin/** x,
  
  # Specific libraries only
  /usr/lib/python3/dist-packages/** r,
}
```

---

## Quick Reference Card

```bash
# STATUS
sudo aa-status                    # Overall status
sudo aa-status --pretty-print     # Pretty output

# MODE CHANGES
sudo aa-enforce /path/to/profile  # Enforce mode
sudo aa-complain /path/to/profile # Complain mode
sudo aa-disable /path/to/profile  # Disable
sudo aa-enable /path/to/profile   # Re-enable

# PROFILE DEVELOPMENT
sudo aa-genprof /usr/bin/app      # Generate profile
sudo aa-logprof                   # Update from logs

# RELOAD
sudo apparmor_parser -r /path/to/profile  # Reload one
sudo systemctl reload apparmor            # Reload all

# MONITORING
sudo aa-notify -s 1 -v            # Watch denials
sudo dmesg | grep apparmor        # Kernel messages
sudo journalctl | grep apparmor   # Journal

# DEBUGGING
sudo aa-complain /path/to/profile # Set to complain
# ... use the app ...
sudo dmesg | tail -50             # See denials
sudo aa-logprof                   # Update profile
```

---

## Additional Resources

- **Official Documentation**: <https://gitlab.com/apparmor/apparmor/-/wikis/home>
- **Debian Wiki**: <https://wiki.debian.org/AppArmor>
- **Ubuntu AppArmor**: <https://ubuntu.com/server/docs/security-apparmor>
- **Profile Repository**: <https://gitlab.com/apparmor/apparmor/-/tree/master/profiles>

---

## Summary

AppArmor provides **path-based mandatory access control** that:

✅ Is **easier** than SELinux  
✅ Works **out of the box** on Debian/Ubuntu  
✅ Provides **defense in depth**  
✅ Can **limit damage** from compromised processes  

**Remember:**

1. Always test in **complain mode** first
2. Use **abstractions** to simplify profiles
3. Follow **least privilege** principle
4. **Monitor** denials regularly
5. **Document** your custom profiles

With AppArmor properly configured, you significantly reduce your attack surface and limit the damage from both known and unknown vulnerabilities.
