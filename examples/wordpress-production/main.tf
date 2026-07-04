# WordPress + LMS Production Environment
# Complete setup with Hetzner server + Cloudflare protection

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }
}

# ========================================
# Providers
# ========================================

provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# ========================================
# Hetzner Server
# ========================================

module "wordpress_server" {
  source = "../../terraform/modules/hetzner-server"

  # Server configuration
  server_name = "wordpress-prod"
  server_type = var.server_type
  location    = var.location
  image       = "debian-13"
  environment = "production"

  # SSH access
  ssh_public_key  = var.ssh_public_key
  admin_username  = "admin"
  ssh_allowed_ips = var.admin_ips # Restrict SSH to admin IPs only

  # Firewall: HTTP/HTTPS open to the world (Cloudflare proxies traffic).
  # Tighten further via UFW on the host to Cloudflare IP ranges (Ansible).
  create_firewall = true
  allow_http      = true
  allow_https     = true

  # Additional volume for WordPress uploads and backups
  volume_size      = var.volume_size
  volume_automount = true
  volume_format    = "ext4"

  # Labels
  labels = {
    environment = "production"
    application = "wordpress"
    project     = var.project_name
    managed_by  = "terraform"
  }

  # Lifecycle
  prevent_destroy = true # Prevent accidental deletion in production
}

# ========================================
# Cloudflare Configuration
# ========================================

module "cloudflare" {
  source = "../../terraform/modules/cloudflare-config"

  # Domain and server
  domain_name = var.domain_name
  server_ipv4 = module.wordpress_server.server_ipv4
  server_ipv6 = module.wordpress_server.server_ipv6

  # Environment
  environment = "prod"

  # Security features (all enabled for production)
  enable_course_protection = var.enable_course_protection
  security_level           = var.cloudflare_security_level
  ssl_mode                 = var.cloudflare_ssl_mode # Upgrade to "strict" after origin SSL cert
  min_tls_version          = "1.2"                   # TLS 1.2 minimum

  # Caching configuration
  browser_cache_ttl = 14400  # 4 hours
  edge_cache_ttl    = 604800 # 7 days for static assets

  # Tags
  tags = {
    environment = "production"
    application = "wordpress"
    managed_by  = "terraform"
  }

  # Depends on server being created first
  depends_on = [module.wordpress_server]
}

# ========================================
# Local Values
# ========================================

locals {
  # Cloudflare IPv4 ranges (for UFW configuration via Ansible)
  cloudflare_ipv4_ranges = [
    "173.245.48.0/20",
    "103.21.244.0/22",
    "103.22.200.0/22",
    "103.31.4.0/22",
    "141.101.64.0/18",
    "108.162.192.0/18",
    "190.93.240.0/20",
    "188.114.96.0/20",
    "197.234.240.0/22",
    "198.41.128.0/17",
    "162.158.0.0/15",
    "104.16.0.0/13",
    "104.24.0.0/14",
    "172.64.0.0/13",
    "131.0.72.0/22"
  ]

  # Ansible inventory configuration
  ansible_inventory = {
    wordpress_prod = {
      ansible_host                 = module.wordpress_server.server_ipv4
      ansible_user                 = "admin"
      ansible_ssh_private_key_file = var.ssh_private_key_path

      # Variables for Ansible roles
      cloudflare_enabled     = true
      cloudflare_ip_ranges   = local.cloudflare_ipv4_ranges
      wordpress_domain       = var.domain_name
      wordpress_volume_mount = "/mnt/wordpress-data"
    }
  }
}

# ========================================
# Ansible Inventory File (Optional)
# ========================================

# Generate Ansible inventory automatically
resource "local_file" "ansible_inventory" {
  count    = var.generate_ansible_inventory ? 1 : 0
  filename = "${path.module}/inventory.yml"

  content = yamlencode({
    all = {
      children = {
        wordpress = {
          hosts = local.ansible_inventory
        }
      }
    }
  })

  file_permission = "0644"
}

# ========================================
# Outputs
# ========================================

# Server information
output "server_id" {
  description = "Hetzner server ID"
  value       = module.wordpress_server.server_id
}

output "server_name" {
  description = "Server name"
  value       = module.wordpress_server.server_name
}

output "ipv4_address" {
  description = "Server IPv4 address"
  value       = module.wordpress_server.server_ipv4
}

output "ipv6_address" {
  description = "Server IPv6 address"
  value       = module.wordpress_server.server_ipv6
}

# Cloudflare information
output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = module.cloudflare.zone_id
}

output "nameservers" {
  description = "Cloudflare nameservers (configure at your registrar)"
  value       = module.cloudflare.name_servers
}

output "zone_status" {
  description = "Cloudflare zone status"
  value       = module.cloudflare.zone_status
}

output "cloudflare_summary" {
  description = "Cloudflare configuration summary"
  value       = module.cloudflare.configuration_summary
}

# Connection information
output "ssh_command" {
  description = "SSH command to connect to server"
  value       = "ssh admin@${module.wordpress_server.server_ipv4}"
}

output "wordpress_url" {
  description = "WordPress site URL (after DNS propagation)"
  value       = "https://${var.domain_name}"
}

output "wordpress_admin_url" {
  description = "WordPress admin URL"
  value       = "https://${var.domain_name}/wp-admin"
}

# Ansible information
output "ansible_inventory_path" {
  description = "Path to generated Ansible inventory file"
  value       = var.generate_ansible_inventory ? abspath("${path.module}/inventory.yml") : "Not generated (set generate_ansible_inventory = true)"
}

output "cloudflare_ip_ranges" {
  description = "Cloudflare IP ranges for UFW configuration"
  value       = local.cloudflare_ipv4_ranges
}

# Setup instructions
output "setup_instructions" {
  description = "Next steps to complete setup"
  value       = <<-EOT
    ================================================================================
    WordPress Production Environment - Setup Instructions
    ================================================================================

    Infrastructure created successfully. Next steps:

    1. Configure nameservers at your registrar:
       ${join("\n       ", module.cloudflare.name_servers)}
       Wait 24-48 hours for DNS propagation.

    2. Connect to the server via SSH:
       ssh admin@${module.wordpress_server.server_ipv4}

    3. Run the Ansible hardening playbook:
       cd ../../ansible
       ansible-playbook -i ${var.generate_ansible_inventory ? abspath("${path.module}/inventory.yml") : "inventory/hetzner.yml"} playbooks/site.yml

    4. Install an SSL certificate on the origin (Let's Encrypt or
       Cloudflare Origin CA), then switch ssl_mode to "strict" and re-apply.

    5. Install WordPress + your LMS plugin and verify caching/WAF behaviour
       from the Cloudflare dashboard.

    ================================================================================
  EOT
}
