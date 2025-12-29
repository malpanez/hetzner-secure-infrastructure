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
