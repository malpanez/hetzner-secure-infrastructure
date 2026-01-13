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
