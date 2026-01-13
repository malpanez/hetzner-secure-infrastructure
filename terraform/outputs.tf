output "server_id" {
  description = "Server ID"
  value       = module.production_server.server_id
}

output "server_name" {
  description = "Server name"
  value       = module.production_server.server_name
}

output "server_type" {
  description = "Selected server type"
  value       = local.final_server_type
}

output "architecture" {
  description = "CPU architecture (x86 or arm)"
  value       = var.architecture
}

output "server_size" {
  description = "Server size tier"
  value       = var.server_size
}

output "server_specs" {
  description = "Server specifications (prices include IPv4)"
  value = {
    cpu   = "${local.selected_specs.cpu} vCPUs"
    ram   = "${local.selected_specs.ram} GB"
    disk  = "${local.selected_specs.disk} GB"
    price = "€${local.selected_specs.price}/month"
  }
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

output "ssh_config_file" {
  description = "SSH config drop-in file location (auto-managed by Terraform)"
  value       = "~/.ssh/config.d/30-terraform-managed.conf"
}

output "connection_info" {
  description = "Complete connection information"
  value = {
    host     = module.production_server.server_ipv4
    user     = var.admin_username
    ssh_key  = "~/.ssh/github_ed25519"
    location = var.location
  }
  sensitive = false
}
