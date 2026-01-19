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
    null = {
      source  = "hashicorp/null"
      version = "~> 3.0"
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

# Hetzner server (production/staging/development)
module "production_server" {
  source = "./modules/hetzner-server"

  server_name    = local.final_server_name # Auto-generated: <env>-<country>-<type>-<number>
  server_type    = local.final_server_type # Uses architecture + size mapping
  image          = var.image
  location       = var.location
  admin_username = var.admin_username
  environment    = var.environment

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

# SSH config drop-in for ~/.ssh/config.d/
# Generates 30-terraform-managed.conf with specific host entries
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/templates/ssh_config.tpl", {
    hostname     = module.production_server.server_name
    host_address = module.production_server.server_ipv4
    user         = var.admin_username
    ssh_key      = "~/.ssh/github_ed25519" # Consistent with 20-hetzner config
  })
  filename        = pathexpand("~/.ssh/config.d/30-terraform-managed.conf")
  file_permission = "0600"
}

# Cloudflare DNS and Security Configuration
module "cloudflare" {
  count  = var.enable_cloudflare ? 1 : 0
  source = "./modules/cloudflare-config"

  domain_name = var.domain
  server_ipv4 = module.production_server.server_ipv4
  server_ipv6 = module.production_server.server_ipv6

  # Security features (all available on Free plan)
  # NOTE: Login rate limiting is handled by WAF ruleset (always enabled)
  enable_course_protection  = false # Set true to require login for /courses/*
  enable_custom_error_pages = false # Optional
  enable_cloudflare_access  = false # Requires paid plan
  custom_error_page_url     = ""

  # CSP allow-lists (admin/editor vs public)
  csp_connect_src_admin_extra  = var.csp_connect_src_admin_extra
  csp_frame_src_admin_extra    = var.csp_frame_src_admin_extra
  csp_connect_src_public_extra = var.csp_connect_src_public_extra
  csp_frame_src_public_extra   = var.csp_frame_src_public_extra
}
