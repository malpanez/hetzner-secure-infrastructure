output "server_id" {
  description = "Server ID"
  value       = module.production_server.server_id
}

output "server_name" {
  description = "Server name"
  value       = module.production_server.server_name
}

output "server_ipv4" {
  description = "Server IPv4 address"
  value       = module.production_server.server_ipv4
}

output "server_ipv6" {
  description = "Server IPv6 address"
  value       = module.production_server.server_ipv6
}

output "floating_ip" {
  description = "Floating IP (if enabled)"
  value       = module.production_server.floating_ip
}

output "ssh_command" {
  description = "SSH command to connect"
  value       = "ssh ${var.admin_username}@${module.production_server.server_ipv4}"
}

output "ansible_inventory_file" {
  description = "Path to generated Ansible inventory"
  value       = "${path.module}/../../../ansible/inventory/terraform-inventory.yml"
}

output "connection_info" {
  description = "Complete connection information"
  value = {
    host     = module.production_server.server_ipv4
    user     = var.admin_username
    ssh_key  = "~/.ssh/id_ed25519_sk"
    location = var.location
  }
  sensitive = false
}
