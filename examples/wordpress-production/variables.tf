# WordPress Production Environment - Variables

# ========================================
# Required Variables
# ========================================

variable "hcloud_token" {
  description = "Hetzner Cloud API token"
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^[A-Za-z0-9_-]+$", var.hcloud_token))
    error_message = "Hetzner Cloud token must be alphanumeric with dashes and underscores"
  }
}

variable "cloudflare_api_token" {
  description = "Cloudflare API token with DNS and Firewall permissions"
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cloudflare_api_token) > 0
    error_message = "Cloudflare API token cannot be empty"
  }
}

variable "domain_name" {
  description = "Domain name for WordPress site (e.g., example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", var.domain_name))
    error_message = "Domain name must be a valid domain (e.g., example.com)"
  }
}

variable "ssh_public_key" {
  description = "SSH public key for server access"
  type        = string

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|ecdsa)", var.ssh_public_key))
    error_message = "Must be a valid SSH public key starting with ssh-rsa, ssh-ed25519, or ssh-ecdsa"
  }
}

# ========================================
# Optional Variables
# ========================================

variable "admin_ips" {
  description = "List of IP addresses allowed to SSH into the server (your office/home IPs). Must not include 0.0.0.0/0."
  type        = list(string)

  validation {
    condition     = alltrue([for ip in var.admin_ips : can(cidrhost(ip, 0))])
    error_message = "All admin IPs must be valid CIDR blocks (e.g., 203.0.113.0/24)"
  }
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for Ansible (e.g., ~/.ssh/id_ed25519)"
  type        = string
  default     = "~/.ssh/id_ed25519"
}

variable "generate_ansible_inventory" {
  description = "Generate Ansible inventory file automatically"
  type        = bool
  default     = true
}

# ========================================
# Server Configuration
# ========================================

variable "server_type" {
  description = "Hetzner server type (e.g., cx22, cpx21, cax21)"
  type        = string
  default     = "cax21" # 4 vCPU ARM, 8 GB RAM - Good for WordPress

  validation {
    condition     = can(regex("^c[apx]*x[0-9]+$", var.server_type))
    error_message = "Server type must be a valid Hetzner Cloud server type (e.g., cx22, cpx21, cax21)"
  }
}

variable "location" {
  description = "Hetzner datacenter location (nbg1, fsn1, hel1, ash)"
  type        = string
  default     = "nbg1" # Nuremberg, Germany

  validation {
    condition     = contains(["nbg1", "fsn1", "hel1", "ash"], var.location)
    error_message = "Location must be one of: nbg1 (Nuremberg), fsn1 (Falkenstein), hel1 (Helsinki), ash (Ashburn)"
  }
}

variable "volume_size" {
  description = "Size of additional volume for WordPress uploads/backups (GB)"
  type        = number
  default     = 20

  validation {
    condition     = var.volume_size >= 10 && var.volume_size <= 10000
    error_message = "Volume size must be between 10 GB and 10,000 GB"
  }
}

# ========================================
# Cloudflare Security Configuration
# ========================================

variable "cloudflare_security_level" {
  description = "Cloudflare security level (low, medium, high, under_attack)"
  type        = string
  default     = "high" # High security for production

  validation {
    condition     = contains(["low", "medium", "high", "under_attack"], var.cloudflare_security_level)
    error_message = "Security level must be one of: low, medium, high, under_attack"
  }
}

variable "cloudflare_ssl_mode" {
  description = "Cloudflare SSL/TLS mode (flexible, full, strict)"
  type        = string
  default     = "full" # Use "strict" after installing SSL cert on origin

  validation {
    condition     = contains(["flexible", "full", "strict"], var.cloudflare_ssl_mode)
    error_message = "SSL mode must be one of: flexible, full, strict"
  }
}

variable "enable_course_protection" {
  description = "Enable protection for LMS course content (challenge non-logged-in visitors on /courses/)"
  type        = bool
  default     = true
}

# ========================================
# Labels and Tags
# ========================================

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "project_name" {
  description = "Project name for labeling resources"
  type        = string
  default     = "wordpress-lms"
}

variable "tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}
