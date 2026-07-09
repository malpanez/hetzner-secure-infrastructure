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
# Minimal CSP base lists — extend per site via the csp_*_extra variables,
# e.g. csp_frame_src_public_extra = ["https://www.youtube.com"]
locals {
  csp_connect_src_admin_base = [
    "'self'",
    "wss:",
  ]

  csp_connect_src_public_base = [
    "'self'",
    "wss:",
  ]

  csp_frame_src_admin_base = [
    "'self'",
    "blob:",
  ]

  csp_frame_src_public_base = [
    "'self'",
    "blob:",
  ]

  csp_connect_src_admin  = concat(local.csp_connect_src_admin_base, var.csp_connect_src_admin_extra)
  csp_connect_src_public = concat(local.csp_connect_src_public_base, var.csp_connect_src_public_extra)
  csp_frame_src_admin    = concat(local.csp_frame_src_admin_base, var.csp_frame_src_admin_extra)
  csp_frame_src_public   = concat(local.csp_frame_src_public_base, var.csp_frame_src_public_extra)
}

resource "cloudflare_ruleset" "security_headers" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "security-headers"
  description = "Security headers for all requests"
  kind        = "zone"
  phase       = "http_response_headers_transform"

  rules {
    description = "Add security headers (WP admin/editor)"
    expression  = "(starts_with(http.request.uri.path, \"/wp-admin/\") or http.request.uri.path eq \"/wp-login.php\")"
    action      = "rewrite"
    enabled     = true

    action_parameters {
      # NOTE: Headers MUST be in alphabetical order by name (Cloudflare sorts them)
      # CSP tuned for WordPress admin/editor (Astra + Elementor + Gutenberg + LearnDash)
      headers {
        name      = "Content-Security-Policy"
        operation = "set"
        value     = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' blob: https:; style-src 'self' 'unsafe-inline' https: https://fonts.googleapis.com; img-src 'self' data: https: blob:; font-src 'self' data: https://fonts.gstatic.com; connect-src ${join(" ", local.csp_connect_src_admin)}; frame-src ${join(" ", local.csp_frame_src_admin)}; frame-ancestors 'self'; worker-src 'self' blob:; base-uri 'self'; form-action 'self'; upgrade-insecure-requests"
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

  rules {
    description = "Add security headers (public)"
    expression  = "not (starts_with(http.request.uri.path, \"/wp-admin/\") or http.request.uri.path eq \"/wp-login.php\")"
    action      = "rewrite"
    enabled     = true

    action_parameters {
      # NOTE: Headers MUST be in alphabetical order by name (Cloudflare sorts them)
      headers {
        name      = "Content-Security-Policy"
        operation = "set"
        value     = "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval' blob:; style-src 'self' 'unsafe-inline' https: https://fonts.googleapis.com; img-src 'self' data: https:; font-src 'self' data: https://fonts.gstatic.com; connect-src ${join(" ", local.csp_connect_src_public)}; frame-src ${join(" ", local.csp_frame_src_public)}; frame-ancestors 'self'; worker-src 'self' blob:; base-uri 'self'; form-action 'self'; upgrade-insecure-requests"
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

  # Consumer-defined cache path prefixes. Each prefix gets an aggressive 30-day
  # edge-cache rule. Useful for reverse-proxied assets served outside
  # /wp-content/ (e.g. a /media/ proxy in front of object storage). Files must
  # be within the Cloudflare plan's max cacheable object size. Range requests
  # are served from the cached object, so media seek/streaming works at the edge.
  dynamic "rules" {
    for_each = var.extra_cache_path_prefixes
    content {
      description = "Cache ${rules.value} for 30 days"
      expression  = "(starts_with(http.request.uri.path, \"${rules.value}\"))"
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
          default = 86400 # 1 day
        }
        cache_key {
          ignore_query_strings_order = false
        }
      }
    }
  }

  # FINAL rule: bypass cache for monitoring/probe User-Agents. This MUST be the
  # LAST rule in the ruleset. In the http_request_cache_settings phase, cache
  # settings are a NON-TERMINATING action, so when several rules match a request
  # the LAST matching rule wins per setting. A probe of "/" also matches the
  # cache-everything HTML rule above (cache = true); placing this bypass last is
  # what makes cache = false win, so the probe reaches the origin and lands in the
  # access log (e.g. a blackbox uptime probe → fixes a "traffic dropped to zero"
  # false positive on a CF-cached homepage). Real-user traffic is unaffected:
  # only the listed User-Agent substrings match. No rule is emitted when empty.
  # Do NOT move this above the cache rules — that would let them override it.
  dynamic "rules" {
    for_each = length(var.cache_bypass_user_agents) > 0 ? [1] : []
    content {
      description = "No cache for monitoring/probe user agents"
      expression  = join(" or ", [for ua in var.cache_bypass_user_agents : "(http.user_agent contains \"${ua}\")"])
      action      = "set_cache_settings"
      enabled     = true
      action_parameters {
        cache = false
        browser_ttl {
          mode = "bypass"
        }
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

# --------------------------------------------------------
# Configuration Rules - per-path setting overrides
# --------------------------------------------------------
# Desktop/native clients (media players, download managers) are not browsers:
# with Browser Integrity Check on, they get blocked with Cloudflare error 1010
# (403). When media_path_bic_off is set (e.g., "/media/"), disable BIC and
# lower the security level for that path only.
resource "cloudflare_ruleset" "config_rules" {
  count = var.media_path_bic_off != "" ? 1 : 0

  zone_id     = data.cloudflare_zone.main.id
  name        = "config-rules"
  description = "Per-path configuration overrides"
  kind        = "zone"
  phase       = "http_config_settings"

  rules {
    description = "Allow non-browser clients on ${var.media_path_bic_off} (no BIC, no challenges)"
    expression  = "(starts_with(http.request.uri.path, \"${var.media_path_bic_off}\"))"
    action      = "set_config"
    enabled     = true
    action_parameters {
      bic            = false
      security_level = "essentially_off"
    }
  }
}
