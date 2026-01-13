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
  description = "Cloudflare nameservers for this zone"
  value       = data.cloudflare_zone.main.name_servers
}

output "zone_status" {
  description = "Zone status"
  value       = data.cloudflare_zone.main.status
}

# ========================================
# DNS Records
# ========================================

output "root_record_id" {
  description = "Root domain DNS record ID"
  value       = cloudflare_record.root.id
}

output "www_record_id" {
  description = "WWW subdomain DNS record ID"
  value       = cloudflare_record.www.id
}

output "grafana_record_id" {
  description = "Grafana subdomain DNS record ID"
  value       = cloudflare_record.grafana.id
}

output "prometheus_record_id" {
  description = "Prometheus subdomain DNS record ID"
  value       = cloudflare_record.prometheus.id
}

# ========================================
# Rulesets
# ========================================

output "rulesets_count" {
  description = "Number of rulesets configured"
  value = length([
    cloudflare_ruleset.security_headers.id,
    cloudflare_ruleset.cache_rules.id,
    cloudflare_ruleset.redirect_www_to_apex.id,
    cloudflare_ruleset.wordpress_security.id,
  ])
}

output "security_headers_ruleset_id" {
  description = "Security headers ruleset ID"
  value       = cloudflare_ruleset.security_headers.id
}

output "cache_ruleset_id" {
  description = "Cache rules ruleset ID"
  value       = cloudflare_ruleset.cache_rules.id
}

output "wordpress_security_ruleset_id" {
  description = "WordPress security ruleset ID"
  value       = cloudflare_ruleset.wordpress_security.id
}

# ========================================
# Zone Settings
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

output "always_use_https" {
  description = "Always use HTTPS enabled"
  value       = cloudflare_zone_settings_override.security.settings[0].always_use_https
}

# ========================================
# Summary
# ========================================

output "configuration_summary" {
  description = "Summary of Cloudflare configuration"
  value = {
    zone_name         = data.cloudflare_zone.main.name
    zone_status       = data.cloudflare_zone.main.status
    ssl_mode          = cloudflare_zone_settings_override.security.settings[0].ssl
    security_level    = cloudflare_zone_settings_override.security.settings[0].security_level
    dns_records_count = 4
    rulesets_count    = 4
    ipv6_enabled      = var.server_ipv6 != null
  }
}
