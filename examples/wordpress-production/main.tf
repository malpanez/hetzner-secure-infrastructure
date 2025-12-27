# WordPress + Tutor LMS Production Environment
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
  }

  # Optional: Use OpenBao for state management
  # backend "http" {
  #   address        = "https://openbao.example.com/v1/secret/data/terraform/wordpress-prod"
  #   lock_address   = "https://openbao.example.com/v1/secret/data/terraform/wordpress-prod-lock"
  #   unlock_address = "https://openbao.example.com/v1/secret/data/terraform/wordpress-prod-lock"
  # }
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
  server_type = "cx21" # 2 vCPU, 4 GB RAM, 40 GB SSD - Good for WordPress
  location    = "nbg1" # Nuremberg, Germany
  image       = "debian-13" # Latest Debian version

  # SSH access
  ssh_public_key = var.ssh_public_key
  ssh_user       = "admin"

  # Firewall rules
  ssh_allowed_ips = var.admin_ips # Restrict SSH to admin IPs only

  # Allow HTTP/HTTPS from Cloudflare only
  # Note: These will be further restricted in UFW to Cloudflare IP ranges
  firewall_rules = [
    {
      description = "Allow HTTP from anywhere (Cloudflare proxy)"
      protocol    = "tcp"
      port        = "80"
      source_ips  = ["0.0.0.0/0", "::/0"]
    },
    {
      description = "Allow HTTPS from anywhere (Cloudflare proxy)"
      protocol    = "tcp"
      port        = "443"
      source_ips  = ["0.0.0.0/0", "::/0"]
    },
  ]

  # Additional volume for WordPress uploads and backups
  volume_size      = 20  # 20 GB for media files
  volume_automount = true
  volume_format    = "ext4"

  # Backups
  enable_backups = true # Automated Hetzner backups

  # Labels
  labels = {
    environment = "production"
    application = "wordpress"
    course      = "trading-course"
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
  server_ipv4 = module.wordpress_server.ipv4_address
  server_ipv6 = module.wordpress_server.ipv6_address

  # Environment
  environment = "prod"

  # Security features (all enabled for production)
  enable_rate_limiting     = true
  enable_course_protection = true
  security_level           = "high" # High security for production
  ssl_mode                 = "full" # Full encryption (upgrade to "strict" after SSL cert)
  min_tls_version          = "1.2"  # TLS 1.2 minimum

  # Rate limiting configuration (stricter for production)
  login_rate_limit_threshold = 3  # 3 login attempts
  login_rate_limit_period    = 60 # per minute

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
      ansible_host = module.wordpress_server.ipv4_address
      ansible_user = "admin"
      ansible_ssh_private_key_file = var.ssh_private_key_path

      # Variables for Ansible roles
      cloudflare_enabled = true
      cloudflare_ip_ranges = local.cloudflare_ipv4_ranges
      wordpress_domain = var.domain_name
      wordpress_volume_mount = "/mnt/wordpress-data"
      tutor_lms_enabled = true
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
  value       = module.wordpress_server.ipv4_address
}

output "ipv6_address" {
  description = "Server IPv6 address"
  value       = module.wordpress_server.ipv6_address
}

# Cloudflare information
output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = module.cloudflare.zone_id
}

output "nameservers" {
  description = "Cloudflare nameservers (configure at GoDaddy)"
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
  value       = "ssh admin@${module.wordpress_server.ipv4_address}"
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
  value = <<-EOT
    ================================================================================
    WordPress Production Environment - Setup Instructions
    ================================================================================

    ✅ Infrastructure Created Successfully!

    📋 NEXT STEPS:

    1. Configure Nameservers at GoDaddy
       --------------------------------
       Log into GoDaddy and update nameservers to:
       ${join("\n       ", module.cloudflare.name_servers)}

       ⏱️  Wait 24-48 hours for DNS propagation

    2. Connect to Server via SSH
       --------------------------
       ${module.wordpress_server.ssh_command}

    3. Run Ansible Hardening Playbook
       --------------------------------
       cd ../../ansible
       ansible-playbook -i ${var.generate_ansible_inventory ? abspath("${path.module}/inventory.yml") : "inventory/hetzner.yml"} playbooks/site.yml

    4. Install WordPress
       ------------------
       # Install WordPress via Ansible role (if available) or manually:
       ansible-playbook -i inventory.yml playbooks/wordpress.yml

    5. Configure UFW for Cloudflare Only
       -----------------------------------
       # This restricts HTTP/HTTPS to Cloudflare IPs only
       ansible-playbook -i inventory.yml playbooks/cloudflare-firewall.yml

    6. Install SSL Certificate
       ------------------------
       # Use Let's Encrypt Certbot
       ssh admin@${module.wordpress_server.ipv4_address}
       sudo apt install certbot python3-certbot-nginx
       sudo certbot --nginx -d ${var.domain_name} -d www.${var.domain_name}

    7. Update Cloudflare SSL Mode to "Strict"
       ----------------------------------------
       # After SSL certificate is installed, update:
       # In main.tf, change: ssl_mode = "strict"
       # Then run: tofu apply

    8. Install Tutor LMS
       ------------------
       - Log into WordPress: https://${var.domain_name}/wp-admin
       - Go to Plugins → Add New
       - Search "Tutor LMS"
       - Install and activate

    9. Configure Backups
       ------------------
       ansible-playbook -i inventory.yml playbooks/setup-backups.yml

    10. Monitor and Test
        ----------------
        - Cloudflare Dashboard: https://dash.cloudflare.com/
        - Test rate limiting: Try 5+ login attempts
        - Verify caching: Check response headers
        - Monitor firewall events

    ================================================================================
    📊 RESOURCE SUMMARY
    ================================================================================

    Server:
      - Type: cx21 (2 vCPU, 4 GB RAM)
      - Location: Nuremberg, Germany
      - IPv4: ${module.wordpress_server.ipv4_address}
      - IPv6: ${module.wordpress_server.ipv6_address}
      - Volume: 20 GB for WordPress data
      - Backups: Enabled

    Cloudflare:
      - Zone: ${var.domain_name}
      - Status: ${module.cloudflare.zone_status}
      - SSL Mode: ${module.cloudflare.ssl_mode}
      - Security Level: High
      - Firewall Rules: ${module.cloudflare.configuration_summary.firewall_rules}
      - Page Rules: ${module.cloudflare.configuration_summary.page_rules}

    ================================================================================
    💰 MONTHLY COST ESTIMATE
    ================================================================================

    - Hetzner cx21 server:     ~€5.83/month
    - Hetzner 20 GB volume:    ~€2.40/month
    - Hetzner backups:         ~€1.17/month
    - Cloudflare Free tier:    €0.00
    ------------------------------------------------
    TOTAL:                     ~€9.40/month

    ================================================================================
    🔒 SECURITY NOTES
    ================================================================================

    - SSH is restricted to admin IPs only
    - HTTP/HTTPS will be restricted to Cloudflare IPs via UFW
    - WordPress XML-RPC is blocked at Cloudflare
    - Login attempts are rate limited (3/minute)
    - Course content protected (requires login)
    - Automatic HTTPS enabled
    - TLS 1.2+ enforced

    ================================================================================
  EOT
}
