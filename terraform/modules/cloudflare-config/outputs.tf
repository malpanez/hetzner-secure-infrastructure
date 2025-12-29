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
  value       = cloudflare_record.root.id
}

output "root_record_hostname" {
  description = "Root domain hostname"
  value       = cloudflare_record.root.hostname
}

output "www_record_id" {
  description = "WWW subdomain DNS record ID"
  value       = cloudflare_record.www.id
}

output "www_record_hostname" {
  description = "WWW subdomain hostname"
  value       = cloudflare_record.www.hostname
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
  value       = cloudflare_zone_settings_override.security.settings[0].ssl
}

output "min_tls_version" {
  description = "Minimum TLS version"
  value       = cloudflare_zone_settings_override.security.settings[0].min_tls_version
}

output "security_level" {
  description = "Security level"
  value       = cloudflare_zone_settings_override.security.settings[0].security_level
}

output "firewall_rules_count" {
  description = "Number of active firewall rules"
  value       = length([
    cloudflare_firewall_rule.block_xmlrpc.id,
    cloudflare_firewall_rule.rate_limit_login.id,
    cloudflare_firewall_rule.block_wp_config.id,
    cloudflare_firewall_rule.block_attacks.id,
  ]) + (var.enable_course_protection ? 1 : 0)
}

# ========================================
# Performance Settings
# ========================================

output "http2_enabled" {
  description = "Whether HTTP/2 is enabled"
  value       = cloudflare_zone_settings_override.security.settings[0].http2
}

output "http3_enabled" {
  description = "Whether HTTP/3 (QUIC) is enabled"
  value       = cloudflare_zone_settings_override.security.settings[0].http3
}

output "brotli_enabled" {
  description = "Whether Brotli compression is enabled"
  value       = cloudflare_zone_settings_override.security.settings[0].brotli
}

output "browser_cache_ttl" {
  description = "Browser cache TTL (seconds)"
  value       = cloudflare_zone_settings_override.security.settings[0].browser_cache_ttl
}

# ========================================
# Page Rules
# ========================================

output "page_rules_count" {
  description = "Number of page rules configured"
  value       = length([
    cloudflare_page_rule.cache_static.id,
    cloudflare_page_rule.bypass_admin.id,
    cloudflare_page_rule.bypass_login.id,
    cloudflare_page_rule.cache_assets.id,
    cloudflare_page_rule.cache_js.id,
  ])
}

# ========================================
# Rate Limiting
# ========================================

output "rate_limiting_enabled" {
  description = "Whether rate limiting is enabled"
  value       = var.enable_rate_limiting
}

output "rate_limit_threshold" {
  description = "Rate limit threshold (requests per period)"
  value       = var.enable_rate_limiting ? var.login_rate_limit_threshold : null
}

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
    zone_name           = data.cloudflare_zone.main.name
    zone_status         = data.cloudflare_zone.main.status
    ssl_mode            = cloudflare_zone_settings_override.security.settings[0].ssl
    security_level      = cloudflare_zone_settings_override.security.settings[0].security_level
    firewall_rules      = length([
      cloudflare_firewall_rule.block_xmlrpc.id,
      cloudflare_firewall_rule.rate_limit_login.id,
      cloudflare_firewall_rule.block_wp_config.id,
      cloudflare_firewall_rule.block_attacks.id,
    ]) + (var.enable_course_protection ? 1 : 0)
    page_rules          = 5
    rate_limiting       = var.enable_rate_limiting
    ipv6_enabled        = var.server_ipv6 != null
    http2_enabled       = true
    http3_enabled       = true
  }
}

# ========================================
# Connection Instructions
# ========================================

output "nameserver_instructions" {
  description = "Instructions for configuring nameservers at your registrar"
  value = <<-EOT
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
