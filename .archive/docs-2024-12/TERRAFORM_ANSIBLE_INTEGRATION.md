# Terraform ↔ Ansible Integration Guide

## Overview

This infrastructure uses **Terraform** to provision Hetzner Cloud resources and **Ansible** to configure and deploy applications. The integration is designed to be seamless and automated.

## Architecture

```
┌─────────────┐      ┌──────────────┐      ┌─────────────────┐
│  Terraform  │─────>│ Hetzner Cloud│─────>│ Server Created  │
│ (Provision) │      │  (API calls) │      │ + SSH Key Added │
└─────────────┘      └──────────────┘      └────────┬────────┘
                                                     │
                                                     ▼
┌─────────────┐      ┌──────────────┐      ┌─────────────────┐
│   Ansible   │─────>│ SSH Connect  │─────>│  Configured     │
│  (Configure)│      │  (Automated) │      │  Application    │
└─────────────┘      └──────────────┘      └─────────────────┘
```

## Workflow

### 1. Terraform Provisions Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

**What Terraform Creates:**
- Hetzner Cloud server (CX22, Debian 12)
- SSH key
- Firewall rules (SSH, HTTP, HTTPS)
- Optional: Volume, Floating IP
- Cloudflare DNS + WAF (if enabled)

**Terraform Outputs:**
- Server IP address (IPv4/IPv6)
- Server ID
- SSH connection command
- Ansible inventory path

### 2. Ansible Configures Server

```bash
cd ../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml
```

**What Ansible Deploys:**
- Security hardening (DevSec baseline)
- Firewall (UFW)
- Fail2ban
- AppArmor
- SSH 2FA
- MariaDB
- Valkey (Redis alternative)
- Nginx + PHP 8.2
- WordPress + 8 essential plugins
- Node Exporter (metrics)
- Optional: Prometheus, Grafana, OpenBao

## Integration Methods

### Method 1: Hetzner Dynamic Inventory (Recommended)

Ansible automatically discovers servers via Hetzner API.

**File**: `ansible/inventory/hetzner.yml`
```yaml
plugin: hetzner.hcloud.hcloud
token: "{{ lookup('env', 'HCLOUD_TOKEN') }}"

compose:
  ansible_host: ipv4_address
  ansible_user: miguel
  ansible_ssh_private_key_file: ~/.ssh/id_ed25519_sk
```

**Usage**:
```bash
export HCLOUD_TOKEN="your-token-here"
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml
```

**Advantages**:
- No manual inventory updates
- Automatically syncs with Hetzner state
- Supports multiple servers
- Uses Hetzner labels for grouping

### Method 2: Static Inventory from Terraform

Terraform generates a static inventory file.

**Template**: `terraform/templates/inventory.tpl`
```yaml
all:
  children:
    hetzner:
      hosts:
        production-server:
          ansible_host: <terraform_output_ip>
          ansible_user: miguel
```

**Terraform Output**:
```bash
terraform output -raw ansible_inventory > ../ansible/inventory/terraform-inventory.yml
```

**Usage**:
```bash
ansible-playbook -i inventory/terraform-inventory.yml playbooks/site.yml
```

**Advantages**:
- Works without Hetzner API access
- Snapshot of infrastructure state
- Can be committed to git

### Method 3: Manual Inventory

For testing or special cases.

**File**: `ansible/inventory/production.yml`
```yaml
wordpress_servers:
  hosts:
    wordpress-prod:
      ansible_host: 95.217.XXX.XXX
      ansible_user: miguel
      ansible_ssh_private_key_file: ~/.ssh/id_ed25519_sk
```

## Required Variables

### Terraform Variables

**File**: `terraform/terraform.tfvars`
```hcl
# Hetzner Cloud
hcloud_token = "your-hetzner-token"
ssh_public_key = "ssh-ed25519 AAAA..."
server_name = "wordpress-prod"

# Cloudflare (optional)
cloudflare_api_token = "your-cloudflare-token"
domain = "example.com"
enable_cloudflare = true
```

### Ansible Variables

**File**: `ansible/inventory/group_vars/all/vault.yml` (encrypted)
```yaml
wordpress_db_password: "secure-password"
nginx_wordpress_admin_password: "secure-password"
nginx_wordpress_auth_key: "generated-key"
# ... other WordPress salts
```

**Create Vault**:
```bash
ansible-vault create ansible/inventory/group_vars/all/vault.yml
```

## Step-by-Step Deployment

### Initial Setup

1. **Configure Terraform**:
```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your values
```

2. **Create Ansible Vault**:
```bash
cd ../ansible
ansible-vault create inventory/group_vars/all/vault.yml
# Add sensitive variables
```

3. **Install Ansible Dependencies**:
```bash
ansible-galaxy install -r requirements.yml
```

### Deploy Infrastructure

4. **Provision with Terraform**:
```bash
cd ../terraform
terraform init
terraform plan
terraform apply

# Save outputs
terraform output -json > ../ansible/terraform-outputs.json
```

5. **Wait for Server to Boot** (30-60 seconds)

6. **Deploy with Ansible**:
```bash
cd ../ansible

# Using Hetzner dynamic inventory (recommended)
export HCLOUD_TOKEN="your-token"
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --ask-vault-pass

# OR using Terraform-generated inventory
ansible-playbook -i inventory/terraform-inventory.yml playbooks/site.yml --ask-vault-pass
```

### Verify Deployment

7. **Check Services**:
```bash
ssh miguel@<server-ip>
sudo systemctl status nginx php8.2-fpm mysql valkey
```

8. **Test WordPress**:
```bash
curl http://<server-ip>
# Should return WordPress installation page
```

9. **Configure Cloudflare** (if enabled):
   - Update nameservers at domain registrar
   - Verify DNS propagation
   - Test HTTPS

## Roles Deployment Matrix

| Role | Applied To | Purpose | Tags |
|------|-----------|---------|------|
| `common` | All servers | Base configuration | `common, base` |
| `security_hardening` | All servers | DevSec + CIS hardening | `security, hardening` |
| `firewall` | All servers | UFW firewall | `security, firewall` |
| `fail2ban` | All servers | Intrusion detection | `security, fail2ban` |
| `apparmor` | All servers | Mandatory access control | `security, apparmor` |
| `ssh_2fa` | All servers | SSH 2FA (optional) | `security, ssh, 2fa` |
| `openbao` | secrets_servers | Secrets management | `openbao, secrets` |
| `prometheus.prometheus` | monitoring_servers | Metrics collection | `monitoring, prometheus` |
| `grafana.grafana` | monitoring_servers | Visualization | `monitoring, grafana` |
| `node_exporter` | monitored_servers | Metrics exporter | `monitoring, node_exporter` |
| `geerlingguy.mysql` | wordpress_servers | MariaDB database | `wordpress, database` |
| `valkey` | wordpress_servers | Redis alternative (cache) | `wordpress, redis, cache` |
| `nginx_wordpress` | wordpress_servers | Nginx + WordPress + plugins | `wordpress, nginx` |

## Selective Deployment

Deploy only specific components:

```bash
# Only WordPress stack
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags wordpress

# Only security hardening
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags security

# Only monitoring
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags monitoring

# Specific server
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --limit wordpress-prod
```

## Testing Integration

### Local Testing (Before Production)

1. **Docker Testing** (fastest):
```bash
docker run -d --name wordpress-test --privileged -p 8080:80 debian:12 /sbin/init
ansible-playbook -i inventory/docker.yml playbooks/site.yml
```

2. **Vagrant Testing** (most realistic):
```bash
vagrant up wordpress-aio
# Ansible runs automatically via Vagrantfile
```

3. **Hetzner Staging**:
```bash
terraform apply -var="environment=staging"
ansible-playbook -i inventory/staging.yml playbooks/site.yml
```

## Troubleshooting

### Connection Issues

```bash
# Test SSH connectivity
ansible all -i inventory/hetzner.yml -m ping

# Check Hetzner API
hcloud server list

# Verify Terraform state
terraform show
```

### Ansible Failures

```bash
# Run with verbose output
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml -vvv

# Check specific host
ansible wordpress-prod -i inventory/hetzner.yml -m setup

# Test role individually
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags nginx_wordpress --limit wordpress-prod
```

### Terraform State Issues

```bash
# Refresh state
terraform refresh

# Check drift
terraform plan

# Import existing resource
terraform import module.production_server.hcloud_server.server <server-id>
```

## Security Considerations

1. **Never commit secrets**:
   - Use Ansible Vault for passwords
   - Store Terraform tokens in environment variables
   - Add `*.tfvars` to `.gitignore` (except `*.example`)

2. **SSH Key Management**:
   - Use hardware keys (YubiKey) when possible
   - Rotate keys regularly
   - Use different keys for different environments

3. **API Token Permissions**:
   - Hetzner: Read + Write on Servers, Read on Floating IPs
   - Cloudflare: Edit DNS, Edit Firewall Rules

4. **Firewall Rules**:
   - Terraform creates base firewall
   - Ansible enables UFW for additional protection
   - Cloudflare WAF protects WordPress endpoints

## Automated Workflows

### CI/CD Integration

```yaml
# .github/workflows/deploy.yml
name: Deploy Infrastructure

on:
  push:
    branches: [main]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init
      - run: terraform plan
      - run: terraform apply -auto-approve

  ansible:
    needs: terraform
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - run: ansible-galaxy install -r ansible/requirements.yml
      - run: ansible-playbook -i ansible/inventory/hetzner.yml ansible/playbooks/site.yml
```

## Maintenance

### Updating Infrastructure

```bash
# Update Terraform resources
cd terraform
terraform plan
terraform apply

# Update Ansible configuration
cd ../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml

# Update only WordPress
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags wordpress
```

### Destroying Infrastructure

```bash
# Destroy everything
cd terraform
terraform destroy

# Selective destruction (not recommended)
terraform destroy -target=module.cloudflare
```

## Best Practices

1. **Always run `terraform plan` before `apply`**
2. **Test Ansible playbooks with `--check` first**
3. **Use tags for selective deployment**
4. **Keep Terraform state in remote backend** (OpenBao or Terraform Cloud)
5. **Encrypt sensitive Ansible variables with Vault**
6. **Use dynamic inventory when possible**
7. **Document custom variables in README files**
8. **Version pin providers and roles**
9. **Test locally before production deployment**
10. **Backup Terraform state and Ansible vault keys**

---

**Last Updated**: December 29, 2025
**Status**: Ready for deployment
