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
  # - CX: Cost-Optimized (Intel/AMD, older gen, limited availability)
  # - CPX: Regular Performance (AMD EPYC, newer gen)
  # - CAX: ARM (Ampere Altra, best price/performance)
  #
  # Prices updated 2024-12-30 from Hetzner Cloud Console
  server_type_map = {
    x86 = {
      # CX series - Cost-Optimized (Intel/AMD mix, limited availability)
      small  = "cx23" # 2 vCPU, 4GB RAM, 40GB, €3.68/mo (CHEAPEST x86!)
      medium = "cx33" # 4 vCPU, 8GB RAM, 80GB, €6.14/mo
      large  = "cx43" # 8 vCPU, 16GB RAM, 160GB, €11.06/mo
      xlarge = "cx53" # 16 vCPU, 32GB RAM, 320GB, €20.90/mo
    }
    x86_perf = {
      # CPX series - Regular Performance (AMD EPYC dedicated)
      small  = "cpx22" # 2 vCPU, 4GB RAM, 80GB NVMe, €7.37/mo
      medium = "cpx32" # 4 vCPU, 8GB RAM, 160GB NVMe, €12.90/mo
      large  = "cpx42" # 8 vCPU, 16GB RAM, 320GB NVMe, €23.97/mo
      xlarge = "cpx52" # 12 vCPU, 24GB RAM, 480GB NVMe, €34.43/mo
    }
    arm = {
      # CAX series - ARM (Ampere Altra)
      small  = "cax11" # 2 vCPU, 4GB RAM, 40GB NVMe, €4.05/mo
      medium = "cax21" # 4 vCPU, 8GB RAM, 80GB NVMe, €7.37/mo
      large  = "cax31" # 8 vCPU, 16GB RAM, 160GB NVMe, €14.75/mo
      xlarge = "cax41" # 16 vCPU, 32GB RAM, 320GB NVMe, €29.51/mo
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
  # Prices updated 2024-12-30 from Hetzner Cloud Console
  server_specs = {
    # x86 Cost-Optimized - CX series (Intel/AMD mix, limited availability)
    cx23 = { cpu = 2, ram = 4, disk = 40, price = 3.68 }
    cx33 = { cpu = 4, ram = 8, disk = 80, price = 6.14 }
    cx43 = { cpu = 8, ram = 16, disk = 160, price = 11.06 }
    cx53 = { cpu = 16, ram = 32, disk = 320, price = 20.90 }

    # x86 Regular Performance - CPX series (AMD EPYC dedicated)
    cpx22 = { cpu = 2, ram = 4, disk = 80, price = 7.37 }
    cpx32 = { cpu = 4, ram = 8, disk = 160, price = 12.90 }
    cpx42 = { cpu = 8, ram = 16, disk = 320, price = 23.97 }
    cpx52 = { cpu = 12, ram = 24, disk = 480, price = 34.43 }
    cpx62 = { cpu = 16, ram = 32, disk = 640, price = 47.34 }

    # ARM - CAX series (Ampere Altra)
    cax11 = { cpu = 2, ram = 4, disk = 40, price = 4.05 }
    cax21 = { cpu = 4, ram = 8, disk = 80, price = 7.37 }
    cax31 = { cpu = 8, ram = 16, disk = 160, price = 14.75 }
    cax41 = { cpu = 16, ram = 32, disk = 320, price = 29.51 }
  }

  selected_specs = local.server_specs[local.final_server_type]

  # Cost savings comparison (shows cheapest alternative)
  # Updated 2024-12-30 with real Hetzner prices
  cost_comparison = var.architecture != "arm" ? null : {
    # Current selection
    arm_monthly = local.selected_specs.price

    # Comparison with CX (cheapest x86)
    cx_equivalent   = var.server_size == "small" ? 3.68 : var.server_size == "medium" ? 6.14 : var.server_size == "large" ? 11.06 : 20.90
    cx_monthly_diff = var.server_size == "small" ? 0.37 : var.server_size == "medium" ? 1.23 : var.server_size == "large" ? 3.69 : 8.61
    cx_yearly_diff  = var.server_size == "small" ? 4.44 : var.server_size == "medium" ? 14.76 : var.server_size == "large" ? 44.28 : 103.32
    cx_percent_diff = var.server_size == "small" ? 10 : var.server_size == "medium" ? 20 : var.server_size == "large" ? 33 : 41

    # Comparison with CPX (performance x86)
    cpx_equivalent   = var.server_size == "small" ? 7.37 : var.server_size == "medium" ? 12.90 : var.server_size == "large" ? 23.97 : 34.43
    cpx_monthly_diff = var.server_size == "small" ? 3.32 : var.server_size == "medium" ? 5.53 : var.server_size == "large" ? 9.22 : 4.92
    cpx_yearly_diff  = var.server_size == "small" ? 39.84 : var.server_size == "medium" ? 66.36 : var.server_size == "large" ? 110.64 : 59.04
    cpx_percent_diff = var.server_size == "small" ? 45 : var.server_size == "medium" ? 43 : var.server_size == "large" ? 38 : 14
  }
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
