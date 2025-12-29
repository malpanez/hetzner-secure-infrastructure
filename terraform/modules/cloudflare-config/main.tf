# Cloudflare Configuration Module
# Manages DNS, SSL/TLS, WAF, and security settings for WordPress + Tutor LMS

terraform {
  required_version = ">= 1.6.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

# Get zone information
data "cloudflare_zone" "main" {
  name = var.domain_name
}

# ========================================
# DNS Records
# ========================================

# Root domain (A record)
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  value   = var.server_ipv4
  type    = "A"
  proxied = true # Enable Cloudflare CDN + DDoS protection
  ttl     = 1    # Auto (when proxied)
  comment = "Root domain pointing to Hetzner server"
}

# WWW subdomain (CNAME to root)
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "www"
  value   = var.domain_name
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "WWW redirect to root domain"
}

# Optional: IPv6 support
resource "cloudflare_record" "root_ipv6" {
  count   = var.server_ipv6 != null ? 1 : 0
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  value   = var.server_ipv6
  type    = "AAAA"
  proxied = true
  ttl     = 1
  comment = "IPv6 support for root domain"
}

# ========================================
# SSL/TLS Configuration
# ========================================

resource "cloudflare_zone_settings_override" "security" {
  zone_id = data.cloudflare_zone.main.id

  settings {
    # SSL/TLS Settings
    ssl                      = "full"        # Full (strict) if you have valid cert on origin
    min_tls_version          = "1.2"         # Minimum TLS 1.2
    tls_1_3                  = "on"          # Enable TLS 1.3
    automatic_https_rewrites = "on"          # Rewrite HTTP to HTTPS
    always_use_https         = "on"          # Force HTTPS
    opportunistic_encryption = "on"          # Enable opportunistic encryption

    # Security Settings
    security_level           = "medium"      # Medium security level
    challenge_ttl            = 1800          # Challenge TTL 30 minutes
    browser_check            = "on"          # Browser integrity check
    hotlink_protection       = "on"          # Prevent hotlinking
    email_obfuscation        = "on"          # Obfuscate email addresses
    server_side_exclude      = "on"          # Server-side excludes
    privacy_pass             = "on"          # Privacy Pass support

    # Performance Settings
    brotli                   = "on"          # Brotli compression
    minify {
      css  = "on"
      js   = "on"
      html = "on"
    }
    rocket_loader            = "off"         # Off for WordPress compatibility
    mirage                   = "off"         # Off (requires paid plan)
    polish                   = "off"         # Off (requires paid plan)

    # Network Settings
    http2                    = "on"          # Enable HTTP/2
    http3                    = "on"          # Enable HTTP/3 (QUIC)
    zero_rtt                 = "on"          # 0-RTT Connection Resumption
    ipv6                     = "on"          # Enable IPv6
    websockets               = "on"          # Enable WebSockets
    pseudo_ipv4              = "off"         # No pseudo IPv4

    # Caching Settings
    browser_cache_ttl        = 14400         # 4 hours
    cache_level              = "aggressive"  # Aggressive caching

    # Bot Management - Requires Business plan or higher
    # bot_management {
    #   enable_js = true
    # }

    # Security Headers
    security_header {
      enabled            = true
      max_age            = 31536000  # 1 year
      include_subdomains = true
      preload            = true
      nosniff            = true
    }
  }
}

# ========================================
# WAF Rules - WordPress Protection
# ========================================

# Block XML-RPC attacks (common WordPress vulnerability)
resource "cloudflare_filter" "block_xmlrpc" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Block XML-RPC attacks on WordPress"
  expression  = "(http.request.uri.path eq \"/xmlrpc.php\")"
}

resource "cloudflare_firewall_rule" "block_xmlrpc" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Block XML-RPC (WordPress vulnerability)"
  filter_id   = cloudflare_filter.block_xmlrpc.id
  action      = "block"
  priority    = 1
}

# Rate limit wp-login.php (brute force protection)
resource "cloudflare_filter" "rate_limit_login" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Rate limit WordPress login page"
  expression  = "(http.request.uri.path contains \"/wp-login.php\") or (http.request.uri.path contains \"/wp-admin/\" and http.request.method eq \"POST\")"
}

resource "cloudflare_firewall_rule" "rate_limit_login" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Rate limit WordPress login attempts"
  filter_id   = cloudflare_filter.rate_limit_login.id
  action      = "challenge" # CAPTCHA challenge
  priority    = 2
}

# Block wp-config.php access
resource "cloudflare_filter" "block_wp_config" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Block access to WordPress config file"
  expression  = "(http.request.uri.path contains \"wp-config.php\")"
}

resource "cloudflare_firewall_rule" "block_wp_config" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Block wp-config.php access"
  filter_id   = cloudflare_filter.block_wp_config.id
  action      = "block"
  priority    = 3
}

# Block common attack patterns
resource "cloudflare_filter" "block_attacks" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Block common attack patterns"
  expression  = "(http.request.uri.path contains \"..\" or http.request.uri.path contains \"etc/passwd\" or http.request.uri.path contains \"eval(\" or http.request.uri.query contains \"<script\")"
}

resource "cloudflare_firewall_rule" "block_attacks" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Block path traversal and XSS attempts"
  filter_id   = cloudflare_filter.block_attacks.id
  action      = "block"
  priority    = 4
}

# Protect Tutor LMS courses (if course URLs follow pattern)
resource "cloudflare_filter" "protect_courses" {
  count       = var.enable_course_protection ? 1 : 0
  zone_id     = data.cloudflare_zone.main.id
  description = "Protect Tutor LMS course content"
  expression  = "(http.request.uri.path contains \"/courses/\" and not http.cookie contains \"wordpress_logged_in\")"
}

resource "cloudflare_firewall_rule" "protect_courses" {
  count       = var.enable_course_protection ? 1 : 0
  zone_id     = data.cloudflare_zone.main.id
  description = "Require login for course access"
  filter_id   = cloudflare_filter.protect_courses[0].id
  action      = "challenge"
  priority    = 5
}

# ========================================
# Page Rules - Caching Strategy
# ========================================

# Cache static assets aggressively
resource "cloudflare_page_rule" "cache_static" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/wp-content/uploads/*"
  priority = 1

  actions {
    cache_level         = "cache_everything"
    edge_cache_ttl      = 2592000 # 30 days
    browser_cache_ttl   = 604800  # 7 days
  }
}

# Don't cache WordPress admin
resource "cloudflare_page_rule" "bypass_admin" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/wp-admin/*"
  priority = 2

  actions {
    cache_level = "bypass"
    disable_security = false
  }
}

# Don't cache login page
resource "cloudflare_page_rule" "bypass_login" {
  zone_id  = data.cloudflare_zone.main.id
  target   = "${var.domain_name}/wp-login.php"
  priority = 3

  actions {
    cache_level = "bypass"
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

# ========================================
# Rate Limiting (Free tier allows 1 rule)
# ========================================

resource "cloudflare_rate_limit" "login_attempts" {
  count   = var.enable_rate_limiting ? 1 : 0
  zone_id = data.cloudflare_zone.main.id

  threshold = 5        # 5 requests
  period    = 60       # per 60 seconds
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
  count      = var.enable_custom_error_pages ? 1 : 0
  zone_id    = data.cloudflare_zone.main.id
  type       = "ip_block"
  url        = var.custom_error_page_url
  state      = "customized"
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

# ========================================
# Outputs
# ========================================

# Output zone information
