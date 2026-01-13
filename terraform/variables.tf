variable "hcloud_token" {
  description = "Hetzner Cloud API Token"
  type        = string
  sensitive   = true
}

# ============================================================================
# Server Naming Convention: <env>-<country>-<type>-<number>
# Examples: prod-de-wp-01, stag-de-wp-01, prod-fi-db-01
# ============================================================================

variable "environment" {
  description = "Environment: dev, test, stag, prod"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "test", "stag", "prod"], var.environment)
    error_message = "Environment must be one of: dev, test, stag, prod"
  }
}

variable "server_type_name" {
  description = "Server type for naming: wp (WordPress), web, db, cache, lb, mon"
  type        = string
  default     = "wp"

  validation {
    condition     = contains(["wp", "web", "db", "cache", "lb", "mon"], var.server_type_name)
    error_message = "Server type must be one of: wp, web, db, cache, lb, mon"
  }
}

variable "instance_number" {
  description = "Instance number (01, 02, 03, ...)"
  type        = number
  default     = 1

  validation {
    condition     = var.instance_number >= 1 && var.instance_number <= 99
    error_message = "Instance number must be between 1 and 99"
  }
}

variable "server_name" {
  description = "Override auto-generated server name (leave empty to use naming convention)"
  type        = string
  default     = ""
}

# ============================================================================
# Server Architecture Selection (x86 vs ARM)
# ============================================================================

variable "architecture" {
  description = "CPU architecture: x86 (Intel/AMD), x86_perf (AMD EPYC), or arm (Ampere Altra)"
  type        = string
  default     = "x86"

  validation {
    condition     = contains(["x86", "x86_perf", "arm"], var.architecture)
    error_message = "Architecture must be one of: x86 (cost-optimized), x86_perf (performance), arm (Ampere)"
  }
}

variable "server_size" {
  description = "Server size tier: small, medium, large, xlarge"
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["small", "medium", "large", "xlarge"], var.server_size)
    error_message = "Server size must be one of: small, medium, large, xlarge"
  }
}

variable "server_type" {
  description = "Server type (override architecture+size auto-selection)"
  type        = string
  default     = "" # Empty = use architecture + size mapping
}

variable "image" {
  description = "OS image"
  type        = string
  default     = "debian-13"
}

variable "location" {
  description = "Datacenter location"
  type        = string
  default     = "nbg1" # Nuremberg

  validation {
    condition = contains([
      "fsn1", # Falkenstein (x86 + ARM)
      "nbg1", # Nuremberg (x86 only)
      "hel1", # Helsinki (x86 + ARM)
      "ash",  # Ashburn, US (x86 + ARM)
      "hil"   # Hillsboro, US (x86 only)
    ], var.location)
    error_message = "Location must be one of: fsn1, nbg1, hel1, ash, hil"
  }
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "malpanez"
}

variable "ssh_public_key" {
  description = "SSH public key (Yubikey FIDO2)"
  type        = string
  sensitive   = true
}

variable "ssh_port" {
  description = "SSH port"
  type        = number
  default     = 22
}

variable "ssh_allowed_ips" {
  description = "IPs allowed to SSH (empty = all)"
  type        = list(string)
  default     = ["0.0.0.0/0", "::/0"]

  # For production, restrict to your IP:
  # default = ["YOUR_IP/32"]
}

variable "allow_http" {
  description = "Allow HTTP traffic"
  type        = bool
  default     = false
}

variable "allow_https" {
  description = "Allow HTTPS traffic"
  type        = bool
  default     = false
}

variable "additional_ports" {
  description = "Additional ports to open"
  type = list(object({
    protocol   = string
    port       = string
    source_ips = list(string)
  }))
  default = []

  # Example:
  # default = [
  #   {
  #     protocol   = "tcp"
  #     port       = "8080"
  #     source_ips = ["0.0.0.0/0", "::/0"]
  #   }
  # ]
}

variable "volume_size" {
  description = "Additional volume size in GB (0 = no volume)"
  type        = number
  default     = 0
}

variable "volume_format" {
  description = "Volume filesystem format"
  type        = string
  default     = "ext4"
}

variable "volume_automount" {
  description = "Auto-mount volume"
  type        = bool
  default     = true
}

variable "enable_floating_ip" {
  description = "Enable floating IP"
  type        = bool
  default     = false
}

variable "reverse_dns_enabled" {
  description = "Enable reverse DNS"
  type        = bool
  default     = false
}

variable "reverse_dns_ptr" {
  description = "Reverse DNS PTR record"
  type        = string
  default     = ""
}

variable "domain" {
  description = "Domain for reverse DNS and Cloudflare"
  type        = string
  default     = "twomindstrading.com"
}

variable "prevent_destroy" {
  description = "Prevent accidental destruction"
  type        = bool
  default     = true
}

variable "labels" {
  description = "Additional labels"
  type        = map(string)
  default     = {}
}

# Cloudflare configuration
variable "cloudflare_api_token" {
  description = "Cloudflare API Token"
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
  default     = ""
}

variable "enable_cloudflare" {
  description = "Enable Cloudflare DNS and security configuration"
  type        = bool
  default     = false # Set to true to enable automatic DNS management
}
