# Cloudflare Configuration Module - Variables

# ========================================
# Required Variables
# ========================================

variable "domain_name" {
  description = "Domain name to configure (e.g., example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", var.domain_name))
    error_message = "Domain name must be a valid domain (e.g., example.com)"
  }
}

variable "server_ipv4" {
  description = "IPv4 address of the origin server (Hetzner)"
  type        = string

  validation {
    condition     = can(regex("^(?:[0-9]{1,3}\\.){3}[0-9]{1,3}$", var.server_ipv4))
    error_message = "Must be a valid IPv4 address"
  }
}

# ========================================
# Optional Variables
# ========================================

variable "server_ipv6" {
  description = "IPv6 address of the origin server (optional)"
  type        = string
  default     = null

  validation {
    condition     = var.server_ipv6 == null || can(regex("^([0-9a-fA-F]{0,4}:){7}[0-9a-fA-F]{0,4}$", var.server_ipv6))
    error_message = "Must be a valid IPv6 address"
  }
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# ========================================
# Feature Toggles
# ========================================

variable "enable_rate_limiting" {
  description = "Enable rate limiting for login pages (free tier: 1 rule)"
  type        = bool
  default     = true
}

variable "enable_course_protection" {
  description = "Enable protection for Tutor LMS course content"
  type        = bool
  default     = true
}

variable "enable_custom_error_pages" {
  description = "Enable custom error pages"
  type        = bool
  default     = false
}

variable "enable_cloudflare_access" {
  description = "Enable Cloudflare Access for wp-admin (requires paid plan)"
  type        = bool
  default     = false
}

# ========================================
# Security Settings
# ========================================

variable "security_level" {
  description = "Cloudflare security level (off, essentially_off, low, medium, high, under_attack)"
  type        = string
  default     = "medium"

  validation {
    condition     = contains(["off", "essentially_off", "low", "medium", "high", "under_attack"], var.security_level)
    error_message = "Security level must be one of: off, essentially_off, low, medium, high, under_attack"
  }
}

variable "ssl_mode" {
  description = "SSL/TLS encryption mode (off, flexible, full, strict)"
  type        = string
  default     = "full" # Use "strict" if you have valid SSL cert on origin

  validation {
    condition     = contains(["off", "flexible", "full", "strict"], var.ssl_mode)
    error_message = "SSL mode must be one of: off, flexible, full, strict"
  }
}

variable "min_tls_version" {
  description = "Minimum TLS version (1.0, 1.1, 1.2, 1.3)"
  type        = string
  default     = "1.2"

  validation {
    condition     = contains(["1.0", "1.1", "1.2", "1.3"], var.min_tls_version)
    error_message = "Minimum TLS version must be one of: 1.0, 1.1, 1.2, 1.3"
  }
}

# ========================================
# Caching Settings
# ========================================

variable "browser_cache_ttl" {
  description = "Browser cache TTL in seconds (0 = respect existing headers)"
  type        = number
  default     = 14400 # 4 hours

  validation {
    condition     = var.browser_cache_ttl >= 0 && var.browser_cache_ttl <= 31536000
    error_message = "Browser cache TTL must be between 0 and 31536000 (1 year)"
  }
}

variable "edge_cache_ttl" {
  description = "Edge cache TTL for static assets (seconds)"
  type        = number
  default     = 2592000 # 30 days

  validation {
    condition     = var.edge_cache_ttl >= 0 && var.edge_cache_ttl <= 31536000
    error_message = "Edge cache TTL must be between 0 and 31536000 (1 year)"
  }
}

# ========================================
# Rate Limiting Configuration
# ========================================

variable "login_rate_limit_threshold" {
  description = "Number of requests before rate limiting kicks in"
  type        = number
  default     = 5

  validation {
    condition     = var.login_rate_limit_threshold >= 1 && var.login_rate_limit_threshold <= 100
    error_message = "Rate limit threshold must be between 1 and 100"
  }
}

variable "login_rate_limit_period" {
  description = "Period in seconds for rate limiting"
  type        = number
  default     = 60 # 1 minute

  validation {
    condition     = contains([10, 60, 120, 300, 600, 900, 3600], var.login_rate_limit_period)
    error_message = "Rate limit period must be one of: 10, 60, 120, 300, 600, 900, 3600"
  }
}

# ========================================
# Custom Error Pages
# ========================================

variable "custom_error_page_url" {
  description = "URL for custom error page (must be hosted on same domain)"
  type        = string
  default     = ""
}

# ========================================
# Tags/Labels
# ========================================

variable "tags" {
  description = "Tags to apply to resources"
  type        = map(string)
  default = {
    managed_by = "terraform"
    module     = "cloudflare-config"
  }
}
