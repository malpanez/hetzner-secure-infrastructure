# ========================================
# Zone Settings - SSL/TLS, Security, Performance
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
