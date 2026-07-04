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

# Get zone information by domain name (simpler than zone_id)
data "cloudflare_zone" "main" {
  name = var.domain_name
}

# Module structure:
# - dns.tf               : DNS records (root, www, optional extra subdomains)
# - zone-settings.tf     : SSL/TLS, security, performance settings
# - waf-rulesets.tf      : WAF custom rulesets (v5) for WordPress protection
# - rulesets.tf          : Cache rules, security headers, www->apex redirect (rulesets v5)
# - page-rules.tf.deprecated : Legacy page rules (no longer applied)
# - optional-features.tf : Custom error pages, Cloudflare Access (rate_limit removed)
# - outputs.tf           : Module outputs
# - variables.tf         : Input variables
