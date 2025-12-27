output "server_id" {
  description = "ID of the server"
  value       = hcloud_server.server.id
}

output "server_name" {
  description = "Name of the server"
  value       = hcloud_server.server.name
}

output "server_ipv4" {
  description = "IPv4 address of the server"
  value       = hcloud_server.server.ipv4_address
}

output "server_ipv6" {
  description = "IPv6 address of the server"
  value       = hcloud_server.server.ipv6_address
}

output "server_status" {
  description = "Status of the server"
  value       = hcloud_server.server.status
}

output "floating_ip" {
  description = "Floating IP address (if enabled)"
  value       = var.enable_floating_ip ? hcloud_floating_ip.server_ip[0].ip_address : null
}

output "volume_id" {
  description = "ID of the attached volume (if created)"
  value       = var.volume_size > 0 ? hcloud_volume.server_volume[0].id : null
}

output "firewall_id" {
  description = "ID of the firewall (if created)"
  value       = var.create_firewall ? hcloud_firewall.server_firewall[0].id : null
}

output "ssh_key_id" {
  description = "ID of the SSH key"
  value       = hcloud_ssh_key.default.id
}

output "ansible_inventory" {
  description = "Ansible inventory format"
  value = {
    hosts = {
      "${hcloud_server.server.name}" = {
        ansible_host = var.enable_floating_ip ? hcloud_floating_ip.server_ip[0].ip_address : hcloud_server.server.ipv4_address
        ansible_user = var.admin_username
        ansible_ssh_private_key_file = "~/.ssh/id_ed25519_sk"
        server_id    = hcloud_server.server.id
        server_type  = hcloud_server.server.server_type
        location     = hcloud_server.server.location
        environment  = var.environment
      }
    }
  }
}
