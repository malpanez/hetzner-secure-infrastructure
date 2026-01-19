# Cloudflare Configuration Module - Variables

# ========================================
# Required Variables
# ========================================

variable "domain_name" {
  description = "Domain name to configure (e.g., example.com) - Zone will be looked up automatically"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", var.domain_name))
    error_message = "Domain name must be a valid domain (e.g., example.com)"
  }
}

# Note: zone_id is no longer needed - we look up the zone by domain_name

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
    condition     = var.server_ipv6 == null || can(regex("^(([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:))$", var.server_ipv6))
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

# NOTE: Rate limiting is now handled by WAF ruleset (waf-rulesets.tf)
# The deprecated cloudflare_rate_limit resource has been removed.
# Login protection via Cloudflare challenge is disabled by default
# (blocked by Pi-hole/ad blockers). Use Nginx rate limiting + WP 2FA instead.

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
# CSP Allow Lists (WordPress Admin/Editor)
# ========================================

variable "csp_connect_src_admin_extra" {
  description = "Additional connect-src domains for wp-admin/wp-login"
  type        = list(string)
  default     = []
}

variable "csp_frame_src_admin_extra" {
  description = "Additional frame-src domains for wp-admin/wp-login"
  type        = list(string)
  default     = []
}

variable "csp_connect_src_public_extra" {
  description = "Additional connect-src domains for public site"
  type        = list(string)
  default     = []
}

variable "csp_frame_src_public_extra" {
  description = "Additional frame-src domains for public site"
  type        = list(string)
  default     = []
}

# ========================================
# Security Settings
# ========================================

variable "wp_admin_challenge_enabled" {
  description = "Enable Cloudflare challenge for wp-admin/wp-login (set false if using Pi-hole or ad blockers that block challenges.cloudflare.com)"
  type        = bool
  default     = false # Disabled by default - security via Nginx rate limiting + WP 2FA
}

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
# Rate Limiting Configuration (REMOVED)
# ========================================

# NOTE: Rate limiting configuration variables have been removed.
# Login protection is now handled by WAF ruleset in waf-rulesets.tf
# See cloudflare_ruleset.wordpress_security (rule 2) for implementation.

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
