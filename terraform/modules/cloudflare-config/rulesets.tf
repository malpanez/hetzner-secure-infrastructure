# ========================================
# Cloudflare v5 Rulesets (Modern API)
# FREE PLAN: 1 ruleset per phase allowed
# ========================================
#
# NOTE: This replaces deprecated Page Rules (limited to 3 on Free plan)
# Free plan allows 1 ruleset per phase, but multiple rules within each
# ========================================

# --------------------------------------------------------
# Security Headers (HTTP Response Headers Transform)
# --------------------------------------------------------
resource "cloudflare_ruleset" "security_headers" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "security-headers"
  description = "Security headers for all requests"
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules {
    description = "Add security headers"
    expression  = "true"
    action      = "rewrite"
    enabled     = true

    action_parameters {
      # NOTE: Headers MUST be in alphabetical order by name (Cloudflare sorts them)
      # CSP: frame-ancestors 'self' allows WordPress Customizer (iframe from same origin)
      # worker-src 'self' blob: allows Web Workers used by modern WP plugins
      headers {
        name      = "Content-Security-Policy"
        operation = "set"
        value     = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:; style-src 'self' 'unsafe-inline'; img-src 'self' data: https:; font-src 'self' data:; connect-src 'self' wss:; frame-src 'self' blob:; frame-ancestors 'self'; worker-src 'self' blob:; base-uri 'self'; form-action 'self'; upgrade-insecure-requests"
      }
      headers {
        name      = "Permissions-Policy"
        operation = "set"
        value     = "geolocation=(), microphone=(), camera=(), payment=(), usb=(), magnetometer=(), gyroscope=()"
      }
      headers {
        name      = "Referrer-Policy"
        operation = "set"
        value     = "strict-origin-when-cross-origin"
      }
      headers {
        name      = "Strict-Transport-Security"
        operation = "set"
        value     = "max-age=31536000; includeSubDomains; preload"
      }
      headers {
        name      = "X-Content-Type-Options"
        operation = "set"
        value     = "nosniff"
      }
      # X-Frame-Options: SAMEORIGIN allows same-origin iframes (Customizer)
      # Note: frame-ancestors in CSP supersedes this, but browsers use both
      headers {
        name      = "X-Frame-Options"
        operation = "set"
        value     = "SAMEORIGIN"
      }
      headers {
        name      = "X-XSS-Protection"
        operation = "set"
        value     = "1; mode=block"
      }
    }
  }
}

# --------------------------------------------------------
# Cache Rules - Consolidated (FREE PLAN: 1 ruleset per phase)
# --------------------------------------------------------
resource "cloudflare_ruleset" "cache_rules" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "wordpress-cache-rules"
  description = "All cache rules for WordPress"
  kind        = "zone"
  phase       = "http_request_cache_settings"

  # Rule 1: Bypass cache for WordPress admin
  rules {
    description = "No cache for wp-admin"
    expression  = "(starts_with(http.request.uri.path, \"/wp-admin/\"))"
    action      = "set_cache_settings"
    enabled     = true
    action_parameters {
      cache = false
      browser_ttl {
        mode = "bypass"
      }
    }
  }

  # Rule 2: Bypass cache for wp-login
  rules {
    description = "No cache for wp-login.php"
    expression  = "(http.request.uri.path eq \"/wp-login.php\")"
    action      = "set_cache_settings"
    enabled     = true
    action_parameters {
      cache = false
      browser_ttl {
        mode = "bypass"
      }
    }
  }

  # Rule 3: Aggressive cache for wp-content (uploads, themes, plugins)
  rules {
    description = "Cache wp-content for 30 days"
    expression  = "(starts_with(http.request.uri.path, \"/wp-content/\"))"
    action      = "set_cache_settings"
    enabled     = true
    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = 2592000 # 30 days
      }
      browser_ttl {
        mode    = "override_origin"
        default = 604800 # 7 days
      }
      cache_key {
        ignore_query_strings_order = false
      }
    }
  }

  # Rule 4: Cache static assets (CSS, JS, images, fonts)
  rules {
    description = "Cache CSS/JS/images/fonts for 7 days"
    expression  = "(ends_with(http.request.uri.path, \".css\") or ends_with(http.request.uri.path, \".js\") or ends_with(http.request.uri.path, \".jpg\") or ends_with(http.request.uri.path, \".jpeg\") or ends_with(http.request.uri.path, \".png\") or ends_with(http.request.uri.path, \".gif\") or ends_with(http.request.uri.path, \".webp\") or ends_with(http.request.uri.path, \".woff\") or ends_with(http.request.uri.path, \".woff2\") or ends_with(http.request.uri.path, \".ttf\"))"
    action      = "set_cache_settings"
    enabled     = true
    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = 604800 # 7 days
      }
      browser_ttl {
        mode    = "override_origin"
        default = 86400 # 1 day
      }
      cache_key {
        ignore_query_strings_order = false
      }
    }
  }

  # Rule 5: Default HTML caching (short)
  rules {
    description = "Cache HTML pages for 1 hour"
    expression  = "(ends_with(http.request.uri.path, \".html\") or http.request.uri.path eq \"/\")"
    action      = "set_cache_settings"
    enabled     = true
    action_parameters {
      cache = true
      edge_ttl {
        mode    = "override_origin"
        default = 3600 # 1 hour
      }
      browser_ttl {
        mode    = "override_origin"
        default = 3600 # 1 hour
      }
      cache_key {
        ignore_query_strings_order = false
      }
    }
  }
}

# --------------------------------------------------------
# Redirect Rules - www to apex (301)
# --------------------------------------------------------
resource "cloudflare_ruleset" "redirect_www_to_apex" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "redirect-www-to-apex"
  description = "301 redirect www to apex domain"
  kind        = "zone"
  phase       = "http_request_dynamic_redirect"

  rules {
    description = "Redirect www subdomain to apex domain"
    expression  = "(http.host eq \"www.${var.domain_name}\")"
    action      = "redirect"
    enabled     = true
    action_parameters {
      from_value {
        status_code = 301
        target_url {
          expression = "concat(\"https://${var.domain_name}\", http.request.uri.path)"
        }
        preserve_query_string = true
      }
    }
  }
}
