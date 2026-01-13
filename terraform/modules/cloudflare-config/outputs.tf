# Cloudflare Configuration Module - Outputs

# ========================================
# Zone Information
# ========================================

output "zone_id" {
  description = "Cloudflare Zone ID"
  value       = data.cloudflare_zone.main.id
}

output "zone_name" {
  description = "Zone name"
  value       = data.cloudflare_zone.main.name
}

output "name_servers" {
  description = "Cloudflare nameservers for this zone (configure these in your registrar)"
  value       = data.cloudflare_zone.main.name_servers
}

output "zone_status" {
  description = "Zone status (active when nameservers are configured)"
  value       = data.cloudflare_zone.main.status
}

# Zone verification key - removed as attribute doesn't exist in current provider version
# output "zone_verification_key" {
#   description = "Zone verification key"
#   value       = data.cloudflare_zone.main.verification_key
#   sensitive   = true
# }

# ========================================
# DNS Records
# ========================================

output "root_record_id" {
  description = "Root domain DNS record ID"
  value       = cloudflare_dns_record.root.id
}

output "root_record_hostname" {
  description = "Root domain hostname"
  value       = var.domain_name
}

output "www_record_id" {
  description = "WWW subdomain DNS record ID"
  value       = cloudflare_dns_record.www.id
}

output "www_record_hostname" {
  description = "WWW subdomain hostname"
  value       = "www.${var.domain_name}"
}

output "ipv6_enabled" {
  description = "Whether IPv6 is configured"
  value       = var.server_ipv6 != null
}

# ========================================
# Security Configuration
# ========================================

output "ssl_mode" {
  description = "SSL/TLS encryption mode"
  value       = cloudflare_zone_setting.ssl.value
}

output "min_tls_version" {
  description = "Minimum TLS version"
  value       = cloudflare_zone_setting.min_tls_version.value
}

output "security_level" {
  description = "Security level"
  value       = cloudflare_zone_setting.security_level.value
}

output "firewall_rules_count" {
  description = "Number of active firewall rulesets"
  value       = 1 + (var.enable_course_protection ? 1 : 0)
}

output "wordpress_security_ruleset_id" {
  description = "ID of the WordPress security ruleset"
  value       = cloudflare_ruleset.wordpress_security.id
}

# ========================================
# Performance Settings
# ========================================

output "http2_enabled" {
  description = "Whether HTTP/2 is enabled"
  value       = null
}

output "http3_enabled" {
  description = "Whether HTTP/3 (QUIC) is enabled"
  value       = null
}

output "brotli_enabled" {
  description = "Whether Brotli compression is enabled"
  value       = cloudflare_zone_setting.brotli.value
}

output "browser_cache_ttl" {
  description = "Browser cache TTL (seconds)"
  value       = cloudflare_zone_setting.browser_cache_ttl.value
}

# ========================================
# Rulesets (Replaces Page Rules)
# ========================================

output "rulesets_count" {
  description = "Number of rulesets configured"
  value = length([
    cloudflare_ruleset.security_headers.id,
    cloudflare_ruleset.cache_rules.id,
    cloudflare_ruleset.redirect_www_to_apex.id,
  ])
}

# ========================================
# Rate Limiting (Handled by WAF Ruleset)
# ========================================

# NOTE: Rate limiting is now handled by cloudflare_ruleset in waf-rulesets.tf
# The deprecated cloudflare_rate_limit resource has been removed.
# Login protection is provided by WAF rule 2 (challenge action).

# ========================================
# Feature Status
# ========================================

output "course_protection_enabled" {
  description = "Whether Tutor LMS course protection is enabled"
  value       = var.enable_course_protection
}

output "cloudflare_access_enabled" {
  description = "Whether Cloudflare Access is enabled for wp-admin"
  value       = var.enable_cloudflare_access
}

# ========================================
# Summary Output
# ========================================

output "configuration_summary" {
  description = "Summary of Cloudflare configuration"
  value = {
    zone_name            = data.cloudflare_zone.main.name
    zone_status          = data.cloudflare_zone.main.status
    ssl_mode             = cloudflare_zone_setting.ssl.value
    security_level       = cloudflare_zone_setting.security_level.value
    firewall_rulesets    = 1 + (var.enable_course_protection ? 1 : 0)
    page_rules           = 5
    waf_login_protection = true # Handled by WAF ruleset
    ipv6_enabled         = var.server_ipv6 != null
    http2_enabled        = null
    http3_enabled        = null
  }
}

# ========================================
# Connection Instructions
# ========================================

output "nameserver_instructions" {
  description = "Instructions for configuring nameservers at your registrar"
  value       = <<-EOT
    Configure these nameservers at your domain registrar (GoDaddy):

    ${join("\n    ", data.cloudflare_zone.main.name_servers)}

    After updating nameservers, it may take 24-48 hours for DNS propagation.
    You can check status at: https://dash.cloudflare.com/
  EOT
}

output "verification_url" {
  description = "URL to verify Cloudflare configuration"
  value       = "https://dash.cloudflare.com/${data.cloudflare_zone.main.id}"
}
