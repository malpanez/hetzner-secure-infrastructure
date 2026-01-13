terraform {
  required_version = ">= 1.6.0"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45, < 2.0"
    }
  }
}

# Locals for DRY (Don't Repeat Yourself)
locals {
  common_labels = merge(
    var.labels,
    {
      managed_by  = "terraform"
      environment = var.environment
      module      = "hetzner-server"
    }
  )

  firewall_name = var.firewall_name != "" ? var.firewall_name : "${var.server_name}-firewall"
  volume_name   = var.volume_name != "" ? var.volume_name : "${var.server_name}-volume"
}

# SSH Key Resource
resource "hcloud_ssh_key" "default" {
  name       = "${var.server_name}-key"
  public_key = var.ssh_public_key
  labels     = local.common_labels
}

# Server Resource
resource "hcloud_server" "server" {
  name        = var.server_name
  server_type = var.server_type
  image       = var.image_id != null ? var.image_id : var.image
  location    = var.location

  ssh_keys = [hcloud_ssh_key.default.id]

  labels = local.common_labels

  user_data = templatefile("${path.module}/templates/cloud-init.yml", {
    hostname      = var.server_name
    domain        = var.domain
    username      = var.admin_username
    ssh_pub_key   = var.ssh_public_key
    management_ip = var.ssh_allowed_ips[0] # First IP in the list is management IP
  })

  firewall_ids = var.firewall_ids

  # Prevent accidental deletion
  lifecycle {
    prevent_destroy = false       # Set to true in production to prevent accidental deletion
    ignore_changes  = [user_data] # Prevent recreation if cloud-init changes
  }
}

# Firewall Resource
resource "hcloud_firewall" "server_firewall" {
  count = var.create_firewall ? 1 : 0

  name   = local.firewall_name
  labels = local.common_labels

  # SSH (limited to specific IPs)
  rule {
    direction   = "in"
    protocol    = "tcp"
    port        = var.ssh_port
    source_ips  = var.ssh_allowed_ips
    description = "SSH access for remote server management"
  }

  # HTTP (public web traffic)
  dynamic "rule" {
    for_each = var.allow_http ? [1] : []
    content {
      direction = "in"
      protocol  = "tcp"
      port      = "80"
      source_ips = [
        "0.0.0.0/0",
        "::/0"
      ]
      description = "HTTP access for web traffic"
    }
  }

  # HTTPS (secure web traffic)
  dynamic "rule" {
    for_each = var.allow_https ? [1] : []
    content {
      direction = "in"
      protocol  = "tcp"
      port      = "443"
      source_ips = [
        "0.0.0.0/0",
        "::/0"
      ]
      description = "HTTPS access for secure web traffic"
    }
  }

  # Custom ports
  dynamic "rule" {
    for_each = var.additional_ports
    content {
      direction  = "in"
      protocol   = rule.value.protocol
      port       = rule.value.port
      source_ips = rule.value.source_ips
    }
  }

  # ICMP (network diagnostics)
  rule {
    direction = "in"
    protocol  = "icmp"
    source_ips = [
      "0.0.0.0/0",
      "::/0"
    ]
    description = "ICMP for ping and network diagnostics"
  }
}

# Attach firewall to server
resource "hcloud_firewall_attachment" "server_firewall" {
  count = var.create_firewall ? 1 : 0

  firewall_id = hcloud_firewall.server_firewall[0].id
  server_ids  = [hcloud_server.server.id]
}

# Volume (optional)
resource "hcloud_volume" "server_volume" {
  count = var.volume_size > 0 ? 1 : 0

  name     = local.volume_name
  size     = var.volume_size
  location = var.location
  format   = var.volume_format
  labels   = local.common_labels

  lifecycle {
    prevent_destroy = false # Set to true in production to prevent accidental deletion
  }
}

# Attach volume to server
resource "hcloud_volume_attachment" "server_volume" {
  count = var.volume_size > 0 ? 1 : 0

  volume_id = hcloud_volume.server_volume[0].id
  server_id = hcloud_server.server.id
  automount = var.volume_automount
}

# Floating IP (optional)
resource "hcloud_floating_ip" "server_ip" {
  count = var.enable_floating_ip ? 1 : 0

  type          = "ipv4"
  home_location = var.location
  description   = "${var.server_name} floating IP"
  labels        = local.common_labels
}

# Assign floating IP to server
resource "hcloud_floating_ip_assignment" "server_ip" {
  count = var.enable_floating_ip ? 1 : 0

  floating_ip_id = hcloud_floating_ip.server_ip[0].id
  server_id      = hcloud_server.server.id
}

# Reverse DNS
resource "hcloud_rdns" "server_rdns" {
  count = var.reverse_dns_enabled ? 1 : 0

  server_id  = hcloud_server.server.id
  ip_address = hcloud_server.server.ipv4_address
  dns_ptr    = var.reverse_dns_ptr != "" ? var.reverse_dns_ptr : "${var.server_name}.${var.domain}"
}
