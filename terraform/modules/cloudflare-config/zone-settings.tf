# ========================================
# Zone Settings - SSL/TLS, Security, Performance
# ========================================
#
# NOTE: Some settings are read-only and will cause errors if set explicitly.
# Only include settings that can be modified via API.
# ========================================

resource "cloudflare_zone_settings_override" "security" {
  zone_id = data.cloudflare_zone.main.id

  settings {
    # SSL/TLS Settings
    ssl                      = "full" # Full (strict) if you have valid cert on origin
    min_tls_version          = "1.2"  # Minimum TLS 1.2
    tls_1_3                  = "on"   # Enable TLS 1.3
    automatic_https_rewrites = "on"   # Rewrite HTTP to HTTPS
    always_use_https         = "on"   # Force HTTPS
    opportunistic_encryption = "on"   # Enable opportunistic encryption

    # Security Settings
    security_level      = "medium" # Medium security level
    challenge_ttl       = 1800     # Challenge TTL 30 minutes
    browser_check       = "on"     # Browser integrity check
    hotlink_protection  = "on"     # Prevent hotlinking
    email_obfuscation   = "on"     # Obfuscate email addresses
    server_side_exclude = "on"     # Server-side excludes
    privacy_pass        = "on"     # Privacy Pass support

    # Performance Settings
    brotli        = "on"  # Brotli compression
    rocket_loader = "off" # Off for WordPress compatibility
    # NOTE: minify, mirage, and polish are read-only or cause issues, don't set them explicitly

    # Network Settings
    # NOTE: http2, http3, zero_rtt, websockets, pseudo_ipv4, ipv6 are read-only, don't set them explicitly
    # These are managed by Cloudflare and cannot be changed via API

    # Caching Settings
    browser_cache_ttl = 14400        # 4 hours
    cache_level       = "aggressive" # Aggressive caching

    # Security Headers
    security_header {
      enabled            = true
      max_age            = 31536000 # 1 year
      include_subdomains = true
      preload            = true
      nosniff            = true
    }
  }

  # Ignore changes to read-only fields
  lifecycle {
    ignore_changes = [
      settings[0].true_client_ip_header,
      settings[0].sort_query_string_for_cache,
      settings[0].polish,
      settings[0].mirage,
      settings[0].minify,
      settings[0].http2,
      settings[0].http3,
      settings[0].zero_rtt,
      settings[0].websockets,
      settings[0].pseudo_ipv4,
    ]
  }
}
