# ============================================================================
# Local Values - Server Type Mapping and Selection Logic
# ============================================================================

locals {
  # ============================================================================
  # Server Naming Convention: <env>-<country>-<type>-<number>
  # ============================================================================

  # Map Hetzner location codes to country codes
  location_to_country = {
    nbg1 = "de" # Nuremberg, Germany
    fsn1 = "de" # Falkenstein, Germany
    hel1 = "fi" # Helsinki, Finland
    ash  = "us" # Ashburn, USA
    hil  = "us" # Hillsboro, USA
  }

  # Extract country code from location
  country_code = local.location_to_country[var.location]

  # Auto-generate server name if not provided
  auto_generated_name = "${var.environment}-${local.country_code}-${var.server_type_name}-${format("%02d", var.instance_number)}"

  # Use provided name or auto-generated
  final_server_name = var.server_name != "" ? var.server_name : local.auto_generated_name

  # ============================================================================
  # Server Type Selection (Architecture + Size)
  # ============================================================================

  # Server type mapping by architecture and size
  # This allows automatic selection based on architecture + size
  # or manual override via server_type variable
  #
  # Three series available:
  # - CX: Cost-Optimized (Intel/AMD, Gen3, limited availability)
  # - CPX: Dedicated General Purpose (AMD EPYC)
  # - CAX: ARM (Ampere Altra, best price/performance)
  #
  # Prices updated 2026-01-13 from Hetzner Cloud Console (includes IPv4)
  # Source: https://www.hetzner.com/cloud/pricing/ (Germany/NBG1 location)
  server_type_map = {
    x86 = {
      # CX series - Cost-Optimized (Intel/AMD mix, limited availability)
      small  = "cx23" # 2 vCPU, 4GB RAM, 40GB SSD, €4.29/mo
      medium = "cx33" # 4 vCPU, 8GB RAM, 80GB SSD, €6.75/mo
      large  = "cx43" # 8 vCPU, 16GB RAM, 160GB SSD, €11.67/mo
      xlarge = "cx53" # 16 vCPU, 32GB RAM, 320GB SSD, €21.51/mo
    }
    x86_perf = {
      # CPX series - Dedicated General Purpose (AMD EPYC)
      small  = "cpx22" # 2 vCPU, 4GB RAM, 80GB SSD, €7.98/mo
      medium = "cpx32" # 4 vCPU, 8GB RAM, 160GB SSD, €13.52/mo
      large  = "cpx42" # 8 vCPU, 16GB RAM, 320GB SSD, €24.59/mo
      xlarge = "cpx52" # 12 vCPU, 24GB RAM, 480GB SSD, €35.04/mo
    }
    arm = {
      # CAX series - ARM (Ampere Altra) - BEST PRICE/PERFORMANCE
      small  = "cax11" # 2 vCPU, 4GB RAM, 40GB SSD, €4.66/mo
      medium = "cax21" # 4 vCPU, 8GB RAM, 80GB SSD, €7.98/mo
      large  = "cax31" # 8 vCPU, 16GB RAM, 160GB SSD, €15.36/mo
      xlarge = "cax41" # 16 vCPU, 32GB RAM, 320GB SSD, €30.12/mo
    }
  }

  # Automatically select server type based on architecture + size
  # Unless user explicitly provided server_type override
  auto_server_type  = local.server_type_map[var.architecture][var.server_size]
  final_server_type = var.server_type != "" ? var.server_type : local.auto_server_type

  # Location compatibility check
  # ARM servers available in: fsn1, hel1, ash, nbg1
  # x86 servers available in all locations
  arm_locations              = ["fsn1", "hel1", "ash", "nbg1"]
  is_arm_compatible_location = contains(local.arm_locations, var.location)

  # Validation: Warn if ARM selected but location doesn't support it
  location_arch_compatible = (
    var.architecture == "x86" ? true : local.is_arm_compatible_location
  )

  # Server specs lookup (for documentation/outputs)
  # Prices updated 2026-01-13 from Hetzner Cloud Console (includes IPv4)
  # Source: https://www.hetzner.com/cloud/pricing/ (Germany/NBG1 location)
  server_specs = {
    # x86 Cost-Optimized - CX series (Intel/AMD mix, Gen3, limited availability)
    cx23 = { cpu = 2, ram = 4, disk = 40, price = 4.29 }
    cx33 = { cpu = 4, ram = 8, disk = 80, price = 6.75 }
    cx43 = { cpu = 8, ram = 16, disk = 160, price = 11.67 }
    cx53 = { cpu = 16, ram = 32, disk = 320, price = 21.51 }

    # ARM Cost-Optimized - CAX series (Ampere Altra)
    cax11 = { cpu = 2, ram = 4, disk = 40, price = 4.66 }
    cax21 = { cpu = 4, ram = 8, disk = 80, price = 7.98 }
    cax31 = { cpu = 8, ram = 16, disk = 160, price = 15.36 }
    cax41 = { cpu = 16, ram = 32, disk = 320, price = 30.12 }

    # x86 Dedicated General Purpose - CPX series (AMD EPYC)
    cpx22 = { cpu = 2, ram = 4, disk = 80, price = 7.98 }
    cpx32 = { cpu = 4, ram = 8, disk = 160, price = 13.52 }
    cpx42 = { cpu = 8, ram = 16, disk = 320, price = 24.59 }
    cpx52 = { cpu = 12, ram = 24, disk = 480, price = 35.04 }
    cpx62 = { cpu = 16, ram = 32, disk = 640, price = 47.96 }

    # x86 Premium Dedicated - CCX Series (AMD EPYC Dedicated vCPU)
    ccx13 = { cpu = 2, ram = 8, disk = 80, price = 15.36 }
    ccx23 = { cpu = 4, ram = 16, disk = 160, price = 30.12 }
    ccx33 = { cpu = 8, ram = 32, disk = 240, price = 59.64 }
    ccx43 = { cpu = 16, ram = 64, disk = 360, price = 118.68 }
    ccx53 = { cpu = 32, ram = 128, disk = 600, price = 236.76 }
    ccx63 = { cpu = 48, ram = 192, disk = 960, price = 354.84 }
  }

  selected_specs = local.server_specs[local.final_server_type]
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
