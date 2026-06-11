# Basic Server Example

This example demonstrates how to deploy a single hardened Debian server using the `hetzner-server` module.

## What This Example Creates

- 1x Debian 13 server (cax11 - smallest ARM instance)
- Cloud firewall with SSH, HTTP, HTTPS access
- SSH key authentication
- Basic security hardening via cloud-init

## Prerequisites

- [OpenTofu](https://opentofu.org/) >= 1.6.0
- Hetzner Cloud account
- SSH key pair

## Usage

### 1. Set Environment Variables

```bash
# Hetzner Cloud API token
export TF_VAR_hcloud_token="your-hetzner-api-token"

# SSH public key
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

### 2. Initialize Terraform

```bash
cd examples/basic-server
tofu init
```

### 3. Review the Plan

```bash
tofu plan
```

### 4. Deploy

```bash
tofu apply
```

### 5. Connect to Server

```bash
# Get connection info
tofu output ssh_command

# SSH into server
ssh admin@<server-ip>
```

### 6. Destroy (when done)

```bash
tofu destroy
```

## Customization

### Change Server Size

```hcl
# In main.tf
module "web_server" {
  # ...
  server_type = "cax21"  # Larger ARM server
}
```

### Restrict SSH Access

```hcl
# In main.tf
module "web_server" {
  # ...
  ssh_allowed_ips = [
    "203.0.113.0/24",  # Your office network
  ]
}
```

### Add Volume

```hcl
# In main.tf
module "web_server" {
  # ...
  volume_size = 10  # 10 GB additional volume
}
```

## Cost

Estimated monthly cost (as of 2026, ARM, with IPv4):

- cax11 server: ~€4.66/month
- **Total: ~€4.66/month**

## Next Steps

After deploying:

1. Run Ansible hardening playbook
2. Configure 2FA authentication
3. Set up monitoring
4. Configure backups

## Cleanup

```bash
tofu destroy
```

## Security Notes

- The example restricts SSH to a placeholder network (`203.0.113.0/24`) — replace it with your own management IP/network before applying
- The module rejects `0.0.0.0/0` for SSH by design
- Enable `prevent_destroy = true` for production servers
- Review and harden firewall rules
