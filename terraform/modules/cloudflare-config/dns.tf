# ========================================
# DNS Records
# ========================================

# Root domain (A record)
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  content = var.server_ipv4
  type    = "A"
  proxied = true # Enable Cloudflare CDN + DDoS protection
  ttl     = 1    # Auto (when proxied)
  comment = "Root domain pointing to Hetzner server"
}

# WWW subdomain (CNAME to root)
resource "cloudflare_record" "www" {
  zone_id = data.cloudflare_zone.main.id
  name    = "www"
  content = var.domain_name
  type    = "CNAME"
  proxied = true
  ttl     = 1
  comment = "WWW redirect to root domain"
}

# Optional: IPv6 support
# NOTE: Commented out due to count dependency on server output (causes plan error)
# IPv6 record should be added manually in Cloudflare after server deployment
# resource "cloudflare_record" "root_ipv6" {
#   count   = var.server_ipv6 != null ? 1 : 0
#   zone_id = data.cloudflare_zone.main.id
#   name    = "@"
#   value   = var.server_ipv6
#   type    = "AAAA"
#   proxied = true
#   ttl     = 1
#   comment = "IPv6 support for root domain"
# }

# Monitoring subdomain: Grafana
resource "cloudflare_record" "grafana" {
  zone_id = data.cloudflare_zone.main.id
  name    = "grafana"
  content = var.server_ipv4
  type    = "A"
  proxied = true
  ttl     = 1
  comment = "Grafana monitoring dashboard (Nginx reverse proxy)"
}

# Monitoring subdomain: Prometheus
resource "cloudflare_record" "prometheus" {
  zone_id = data.cloudflare_zone.main.id
  name    = "prometheus"
  content = var.server_ipv4
  type    = "A"
  proxied = true
  ttl     = 1
  comment = "Prometheus metrics endpoint (Nginx reverse proxy)"
}
