# ========================================
# Page Rules - Caching Strategy
# ========================================

# Cache static assets aggressively
resource "cloudflare_page_rule" "cache_static" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/wp-content/uploads/*"
  priority = 1

  actions {
    cache_level       = "cache_everything"
    edge_cache_ttl    = 2592000 # 30 days
    browser_cache_ttl = 604800  # 7 days
  }
}

# Don't cache WordPress admin
resource "cloudflare_page_rule" "bypass_admin" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/wp-admin/*"
  priority = 2

  actions {
    cache_level      = "bypass"
    disable_security = false
  }
}

# Don't cache login page
resource "cloudflare_page_rule" "bypass_login" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/wp-login.php"
  priority = 3

  actions {
    cache_level    = "bypass"
    security_level = "high" # Higher security for login page
  }
}

# Cache CSS and JS
resource "cloudflare_page_rule" "cache_assets" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/*.css"
  priority = 4

  actions {
    cache_level       = "cache_everything"
    edge_cache_ttl    = 604800 # 7 days
    browser_cache_ttl = 86400  # 1 day
  }
}

resource "cloudflare_page_rule" "cache_js" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/*.js"
  priority = 5

  actions {
    cache_level       = "cache_everything"
    edge_cache_ttl    = 604800 # 7 days
    browser_cache_ttl = 86400  # 1 day
  }
}
