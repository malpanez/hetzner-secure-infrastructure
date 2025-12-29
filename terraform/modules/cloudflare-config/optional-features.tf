# ========================================
# Optional Features
# ========================================

# ========================================
# Rate Limiting (Free tier allows 1 rule)
# ========================================

resource "cloudflare_rate_limit" "login_attempts" {
  count   = var.enable_rate_limiting ? 1 : 0
  zone_id = data.cloudflare_zone.main.id

  threshold = 5  # 5 requests
  period    = 60 # per 60 seconds
  action {
    mode    = "challenge" # CAPTCHA
    timeout = 3600        # 1 hour ban
  }

  match {
    request {
      url_pattern = "${var.domain_name}/wp-login.php*"
    }
  }

  description = "Rate limit WordPress login (5 attempts/min)"
}

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
# Cloudflare Access (Optional - Requires paid plan)
# ========================================

# Protect /wp-admin with Cloudflare Access (if enabled)
resource "cloudflare_access_application" "wp_admin" {
  count                     = var.enable_cloudflare_access ? 1 : 0
  zone_id                   = data.cloudflare_zone.main.id
  name                      = "WordPress Admin"
  domain                    = "${var.domain_name}/wp-admin"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = true
}
