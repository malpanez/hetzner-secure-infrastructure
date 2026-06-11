# Example: Basic Secure Server Deployment
# This example shows how to deploy a single hardened server

terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45, < 2.0"
    }
  }
}

# Configure provider
provider "hcloud" {
  token = var.hcloud_token
}

# Use the hetzner-server module
module "web_server" {
  source = "../../terraform/modules/hetzner-server"

  # Basic configuration
  server_name    = "example-web-01"
  server_type    = "cax11" # Smallest ARM server type
  image          = "debian-13"
  location       = "nbg1" # Nuremberg
  environment    = "production"
  admin_username = "admin"

  # SSH configuration
  ssh_public_key = var.ssh_public_key
  ssh_port       = 22
  ssh_allowed_ips = [
    "203.0.113.0/24", # Replace with your management IP/network
  ]

  # Firewall
  create_firewall = true
  allow_http      = true
  allow_https     = true

  # Optional features
  enable_floating_ip = false
  volume_size        = 0 # No additional volume

  # Labels for organization
  labels = {
    project = "example"
    tier    = "web"
  }

  # Lifecycle
  prevent_destroy = false # Allow destruction for example
}

# Outputs
output "server_ip" {
  description = "Public IPv4 address of the server"
  value       = module.web_server.server_ipv4
}

output "ssh_command" {
  description = "SSH command to connect to the server"
  value       = "ssh admin@${module.web_server.server_ipv4}"
}

output "server_id" {
  description = "Hetzner Cloud server ID"
  value       = module.web_server.server_id
}
