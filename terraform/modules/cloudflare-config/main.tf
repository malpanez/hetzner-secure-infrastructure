# Cloudflare Configuration Module
# Manages DNS, SSL/TLS, WAF, and security settings for WordPress + LMS

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Get zone information
data "cloudflare_zone" "main" {
  zone_id = var.zone_id
}

# Module structure:
# - dns.tf               : DNS records (A, AAAA, CNAME)
# - zone-settings.tf     : SSL/TLS, security, performance settings
# - waf-rulesets.tf      : WAF custom rulesets for WordPress protection
# - page-rules.tf        : Caching strategy for WordPress
# - optional-features.tf : Rate limiting, custom error pages, Cloudflare Access
# - outputs.tf           : Module outputs
# - variables.tf         : Input variables
