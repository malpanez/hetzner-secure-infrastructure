# ============================================================================
# Local Values - Server Type Mapping and Selection Logic
# ============================================================================

locals {
  # Server type mapping by architecture and size
  # This allows automatic selection based on architecture + size
  # or manual override via server_type variable
  #
  # Note: CX series (cx11, cx21, etc.) is DEPRECATED by Hetzner
  # Use CPX (x86) or CAX (ARM) series only
  server_type_map = {
    x86 = {
      small  = "cpx11" # 2 vCPU, 2GB RAM, 40GB NVMe, €4.50/mo
      medium = "cpx21" # 3 vCPU, 4GB RAM, 80GB NVMe, €8.50/mo
      large  = "cpx31" # 4 vCPU, 8GB RAM, 160GB NVMe, €13.90/mo
      xlarge = "cpx41" # 8 vCPU, 16GB RAM, 240GB NVMe, €26.90/mo
    }
    arm = {
      small  = "cax11" # 2 vCPU, 4GB RAM, 40GB NVMe, €4.15/mo (DOUBLE RAM vs CPX11!)
      medium = "cax21" # 4 vCPU, 8GB RAM, 80GB NVMe, €8.30/mo (40% cheaper than CPX31!)
      large  = "cax31" # 8 vCPU, 16GB RAM, 160GB NVMe, €16.60/mo
      xlarge = "cax41" # 16 vCPU, 32GB RAM, 320GB NVMe, €33.20/mo
    }
  }

  # Automatically select server type based on architecture + size
  # Unless user explicitly provided server_type override
  auto_server_type = local.server_type_map[var.architecture][var.server_size]
  final_server_type = var.server_type != "" ? var.server_type : local.auto_server_type

  # Location compatibility check
  # ARM servers only available in: fsn1, hel1, ash
  # x86 servers available in all locations
  arm_locations = ["fsn1", "hel1", "ash"]
  is_arm_compatible_location = contains(local.arm_locations, var.location)

  # Validation: Warn if ARM selected but location doesn't support it
  location_arch_compatible = (
    var.architecture == "x86" ? true : local.is_arm_compatible_location
  )

  # Server specs lookup (for documentation/outputs)
  server_specs = {
    # x86 (AMD EPYC)
    cpx11 = { cpu = 2, ram = 2, disk = 40, price = 4.50 }
    cpx21 = { cpu = 3, ram = 4, disk = 80, price = 8.50 }
    cpx31 = { cpu = 4, ram = 8, disk = 160, price = 13.90 }
    cpx41 = { cpu = 8, ram = 16, disk = 240, price = 26.90 }

    # ARM (Ampere Altra)
    cax11 = { cpu = 2, ram = 4, disk = 40, price = 4.15 }
    cax21 = { cpu = 4, ram = 8, disk = 80, price = 8.30 }
    cax31 = { cpu = 8, ram = 16, disk = 160, price = 16.60 }
    cax41 = { cpu = 16, ram = 32, disk = 320, price = 33.20 }
  }

  selected_specs = local.server_specs[local.final_server_type]

  # Cost savings comparison (ARM vs equivalent x86)
  cost_comparison = var.architecture == "arm" ? {
    arm_monthly    = local.selected_specs.price
    x86_equivalent = var.server_size == "small" ? 4.50 : var.server_size == "medium" ? 13.90 : var.server_size == "large" ? 26.90 : 53.80
    monthly_saving = var.server_size == "small" ? 0.35 : var.server_size == "medium" ? 5.60 : var.server_size == "large" ? 10.30 : 20.60
    yearly_saving  = var.server_size == "small" ? 4.20 : var.server_size == "medium" ? 67.20 : var.server_size == "large" ? 123.60 : 247.20
  } : null
}

# Validation: Error if ARM selected with incompatible location
resource "null_resource" "validate_arch_location" {
  count = local.location_arch_compatible ? 0 : 1

  provisioner "local-exec" {
    command = <<-EOT
      echo "ERROR: ARM architecture requires location to be one of: fsn1, hel1, ash"
      echo "Current location: ${var.location}"
      echo "Current architecture: ${var.architecture}"
      echo ""
      echo "Solutions:"
      echo "  1. Change architecture to 'x86'"
      echo "  2. Change location to 'fsn1' (Falkenstein - recommended)"
      exit 1
    EOT
  }
}
