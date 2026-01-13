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
}

# Provider configuration
provider "hcloud" {
  token = var.hcloud_token
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}

# Production server
module "production_server" {
  source = "../../modules/hetzner-server"

  server_name    = var.server_name
  server_type    = var.server_type
  image          = var.image
  location       = var.location
  admin_username = var.admin_username
  environment    = "production"

  ssh_public_key  = var.ssh_public_key
  ssh_port        = var.ssh_port
  ssh_allowed_ips = var.ssh_allowed_ips

  # Firewall configuration
  create_firewall  = true
  allow_http       = var.allow_http
  allow_https      = var.allow_https
  additional_ports = var.additional_ports

  # Storage
  volume_size      = var.volume_size
  volume_format    = var.volume_format
  volume_automount = var.volume_automount

  # Network
  enable_floating_ip = var.enable_floating_ip

  # DNS
  reverse_dns_enabled = var.reverse_dns_enabled
  reverse_dns_ptr     = var.reverse_dns_ptr
  domain              = var.domain

  # Protection
  prevent_destroy = var.prevent_destroy

  # Labels
  labels = merge(
    var.labels,
    {
      project     = "hetzner-secure-infra"
      owner       = "miguel"
      cost_center = "infrastructure"
    }
  )
}

# Output Ansible inventory
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/templates/inventory.tpl", {
    servers = {
      production = module.production_server.ansible_inventory
    }
  })
  filename = "${path.module}/../../../ansible/inventory/terraform-inventory.yml"
}

# Output for easy SSH access
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/templates/ssh_config.tpl", {
    hostname     = module.production_server.server_name
    host_address = module.production_server.server_ipv4
    user         = var.admin_username
    ssh_key      = "~/.ssh/id_ed25519_sk"
  })
  filename = "${path.module}/.ssh_config"
}

# Cloudflare DNS and Security Configuration
module "cloudflare" {
  count  = var.enable_cloudflare ? 1 : 0
  source = "../../modules/cloudflare-config"

  domain_name = var.domain
  zone_id     = var.cloudflare_zone_id
  server_ipv4 = module.production_server.server_ipv4
  server_ipv6 = module.production_server.server_ipv6

  # Security features (all available on Free plan)
  # NOTE: Login rate limiting is handled by WAF ruleset (always enabled)
  enable_course_protection  = false # Set true to require login for /courses/*
  enable_custom_error_pages = false # Optional
  enable_cloudflare_access  = false # Requires paid plan
  custom_error_page_url     = ""
}
