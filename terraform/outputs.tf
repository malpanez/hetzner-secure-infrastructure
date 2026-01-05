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
  description = "Server specifications"
  value = {
    cpu   = "${local.selected_specs.cpu} vCPUs"
    ram   = "${local.selected_specs.ram} GB"
    disk  = "${local.selected_specs.disk} GB NVMe"
    price = "€${local.selected_specs.price}/month"
  }
}

output "cost_comparison" {
  description = "ARM vs x86 cost comparison (only shown when ARM architecture selected)"
  value = var.architecture == "arm" ? {
    arm_selected = "€${local.selected_specs.price}/month"
    vs_cx_cheaper = {
      x86_cost    = "€${local.cost_comparison.cx_equivalent}/month"
      difference  = "ARM pays +€${local.cost_comparison.cx_monthly_diff}/month (${local.cost_comparison.cx_percent_diff}% more)"
      annual_diff = "+€${local.cost_comparison.cx_yearly_diff}/year"
      note        = "CX series: Cheapest x86 (Intel/AMD, limited availability)"
    }
    vs_cpx_performance = {
      x86_cost    = "€${local.cost_comparison.cpx_equivalent}/month"
      difference  = "ARM saves €${local.cost_comparison.cpx_monthly_diff}/month (${local.cost_comparison.cpx_percent_diff}% cheaper)"
      annual_diff = "Saves €${local.cost_comparison.cpx_yearly_diff}/year"
      note        = "CPX series: Performance x86 (AMD EPYC dedicated)"
    }
  } : null
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
  description = "SSH config drop-in file location"
  value       = "~/.ssh/config.d/${module.production_server.server_name}.conf"
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
