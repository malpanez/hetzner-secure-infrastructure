# ========================================
# Optional Features
# ========================================

# NOTE: Rate limiting for wp-login.php is handled by WAF ruleset in waf-rulesets.tf
# The deprecated cloudflare_rate_limit resource has been removed.
# See waf-rulesets.tf: cloudflare_ruleset.wordpress_security (rule 2) for login protection.

# ========================================
# Custom Error Pages (Optional)
# ========================================

# Customize 1020 (Access Denied) page
resource "cloudflare_custom_pages" "error_1020" {
  count   = var.enable_custom_error_pages ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  type    = "ip_block"
  url     = var.custom_error_page_url
  state   = "customized"
}

# ========================================
# Cloudflare Zero Trust Access (Optional - Requires paid plan)
# ========================================

# Protect /wp-admin with Cloudflare Zero Trust Access (if enabled)
resource "cloudflare_zero_trust_access_application" "wp_admin" {
  count                     = var.enable_cloudflare_access ? 1 : 0
  zone_id                   = data.cloudflare_zone.main.id
  name                      = "WordPress Admin"
  domain                    = "${var.domain_name}/wp-admin"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
}

# ========================================
# Zero Trust Access for monitoring subdomains (Grafana + Prometheus)
# ========================================
# Prometheus has NO built-in auth and Grafana is internal-only; Cloudflare Access
# puts an identity gate (One-time PIN to the listed emails) in front of both.
# Created only when monitoring_access_emails is non-empty.
locals {
  monitoring_access_apps = length(var.monitoring_access_emails) > 0 ? {
    grafana    = "Grafana (Monitoring)"
    prometheus = "Prometheus (Monitoring)"
  } : {}
}

resource "cloudflare_zero_trust_access_application" "monitoring" {
  for_each                  = local.monitoring_access_apps
  zone_id                   = data.cloudflare_zone.main.id
  name                      = each.value
  domain                    = "${each.key}.${var.domain_name}"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
}

resource "cloudflare_zero_trust_access_policy" "monitoring" {
  for_each       = local.monitoring_access_apps
  application_id = cloudflare_zero_trust_access_application.monitoring[each.key].id
  zone_id        = data.cloudflare_zone.main.id
  name           = "Monitoring allowed admins"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.monitoring_access_emails
  }
}
