# Troubleshooting Guide

## Network Issues in WSL2

### Problem: "Network is unreachable" when installing Ansible collections

**Error**:

```
ERROR! Unknown error when attempting to call Galaxy at 'https://galaxy.ansible.com/api/':
<urlopen error [Errno 101] Network is unreachable>
```

**Causes**:

1. WSL2 networking issues
2. VPN interference
3. DNS resolution problems
4. Firewall blocking

### Solutions

#### Solution 1: Fix WSL2 DNS

```bash
# In WSL2
sudo rm /etc/resolv.conf
sudo bash -c 'echo "nameserver 8.8.8.8" > /etc/resolv.conf'
sudo bash -c 'echo "[network]" > /etc/wsl.conf'
sudo bash -c 'echo "generateResolvConf = false" >> /etc/wsl.conf'
sudo chattr +i /etc/resolv.conf

# In Windows PowerShell (restart WSL)
wsl --shutdown
wsl
```

#### Solution 2: Install Collections Manually

Download and install collections offline:

```bash
# On a machine with internet
ansible-galaxy collection download prometheus.prometheus
ansible-galaxy collection download grafana.grafana
ansible-galaxy role download geerlingguy.mysql

# Copy .tar.gz files to WSL2, then:
ansible-galaxy collection install prometheus-prometheus-*.tar.gz
ansible-galaxy collection install grafana-grafana-*.tar.gz
ansible-galaxy role install geerlingguy.mysql-*.tar.gz
```

#### Solution 3: Use Vagrant Instead

**Recommended**: Use Vagrant from Windows PowerShell (avoids WSL2 networking):

```powershell
# From Windows PowerShell
cd C:\path\to\hetzner-secure-infrastructure
vagrant up wordpress-aio
```

Vagrant provisions with Ansible automatically and has better network stability.

## Docker Issues

### Problem: Cannot pull Debian image

**Error**:

```
Unable to find image 'debian:12' locally
docker: Error response from daemon: failed to resolve reference
```

**Solutions**:

1. **Check Docker daemon**:

```bash
docker info
systemctl status docker
```

1. **Pull image manually**:

```bash
docker pull debian:13  # Latest stable (Trixie)
docker pull debian:12  # LTS (Bookworm)
```

1. **Use local image**:

```bash
# Check available images
docker images | grep debian

# Use what you have
docker run -d --name wordpress-test --privileged -p 8080:80 debian:latest /sbin/init
```

## Ansible Collection Installation

### Missing Collections

**Required**:

- `prometheus.prometheus`
- `grafana.grafana`
- `community.general`
- `ansible.posix`

**Required Roles**:

- `geerlingguy.mysql`

### Install All Requirements

```bash
cd ansible
ansible-galaxy install -r requirements.yml --force
```

### Verify Installation

```bash
ansible-galaxy collection list
ansible-galaxy role list
```

### Expected Output

```
# Collections
community.general      12.0.1
grafana.grafana        2.2.4
prometheus.prometheus  0.x.x
ansible.posix         1.x.x

# Roles
geerlingguy.mysql     4.x.x
```

## Vagrant Issues

### VirtualBox Not Found

**From WSL2**:

```
Vagrant can only be run from Windows, not WSL2
```

**Solution**: Run from Windows PowerShell:

```powershell
cd C:\Users\YourUser\path\to\repo
vagrant up wordpress-aio
```

### VM Won't Start

```powershell
# Check VirtualBox
VBoxManage --version

# Check Hyper-V (conflicts with VirtualBox)
bcdedit /enum | findstr hypervisorlaunchtype

# If Hyper-V is enabled, disable it:
bcdedit /set hypervisorlaunchtype off
# Restart Windows
```

### Ansible Provisioning Fails

```powershell
# Re-run just the Ansible provisioning
vagrant provision wordpress-aio

# With verbose output
vagrant provision wordpress-aio --debug
```

## Testing Recommendations

### Priority Order

1. **Vagrant** (Most stable, full systemd support)
   - From Windows PowerShell
   - Complete VM isolation
   - Automatic Ansible provisioning

2. **Hetzner Staging** (Most realistic)
   - Real server environment
   - Tests Terraform + Ansible integration
   - Costs ~€5.83/month

3. **Docker** (Fastest, but limitations)
   - From WSL2 (if networking works)
   - No systemd support by default
   - Good for quick syntax checks

### When to Use Each

| Method | Use For | Pros | Cons |
|--------|---------|------|------|
| **Vagrant** | Full testing | Complete, isolated | Requires Windows |
| **Docker** | Quick checks | Fast | Limited systemd |
| **Hetzner** | Pre-production | Real environment | Costs money |

## Debian Version Selection

### Debian 13 (Trixie) - December 2025

**Status**: Stable (released)
**Available**: Yes, on Hetzner Cloud
**Recommended**: Yes, for new deployments

```hcl
# terraform/modules/hetzner-server/variables.tf
variable "image" {
  default = "debian-13"
}
```

### Debian 12 (Bookworm) - LTS

**Status**: LTS Stable
**Support Until**: 2026-2028
**Recommended**: Yes, for maximum stability

```hcl
variable "image" {
  default = "debian-12"
}
```

### Update Docker Image

```bash
# Use Debian 13
docker run -d --name wordpress-test --privileged -p 8080:80 debian:13 /sbin/init

# Or Debian 12
docker run -d --name wordpress-test --privileged -p 8080:80 debian:12 /sbin/init
```

### Update Vagrantfile

```ruby
# Use Debian 13
config.vm.box = "debian/trixie64"

# Or Debian 12
config.vm.box = "debian/bookworm64"
```

## Common Errors

### Error: Role not found

```
ERROR! the role 'prometheus.prometheus.prometheus' was not found
```

**Fix**: Install Galaxy requirements

```bash
ansible-galaxy install -r ansible/requirements.yml
```

### Error: Python interpreter not found

```
FAILED! => {"changed": false, "msg": "/usr/bin/python3: not found"}
```

**Fix**: Install Python in container

```bash
docker exec wordpress-test apt-get update
docker exec wordpress-test apt-get install -y python3
```

### Error: Connection timeout

```
fatal: [host]: UNREACHABLE! => {"msg": "Failed to connect to the host via ssh"}
```

**Checks**:

1. SSH service running?
2. Correct IP address?
3. Firewall blocking?
4. SSH key correct?

```bash
# Test connection
ssh -vvv user@host

# Check from Ansible
ansible all -m ping
```

## Getting Help

### Debug Mode

```bash
# Ansible verbose
ansible-playbook playbook.yml -vvv

# Terraform debug
TF_LOG=DEBUG terraform apply

# Docker logs
docker logs wordpress-test

# Vagrant debug
vagrant up --debug
```

### Check Logs

```bash
# Ansible logs
tail -f /var/log/ansible.log

# System logs in container
docker exec wordpress-test journalctl -f

# Vagrant VM logs
vagrant ssh wordpress-aio
sudo journalctl -f
```

### Verify Services

```bash
# In Docker container
docker exec wordpress-test systemctl status nginx
docker exec wordpress-test systemctl status php8.4-fpm
docker exec wordpress-test systemctl status mysql
docker exec wordpress-test systemctl status valkey

# In Vagrant
vagrant ssh wordpress-aio
sudo systemctl status nginx php8.4-fpm mysql valkey
```

## Next Steps After Fixing

1. **Test locally**: Vagrant or Docker
2. **Verify all roles**: Run complete playbook
3. **Check services**: Ensure WordPress accessible
4. **Deploy staging**: Test on real Hetzner VPS
5. **Production**: Deploy with confidence

---

**Last Updated**: January 9, 2026
