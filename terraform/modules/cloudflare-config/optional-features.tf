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
# Cloudflare Zero Trust Access for /wp-admin
# ========================================
# WHY THIS IS NOT A BOOLEAN ANY MORE
# The previous version created ONE application, on the apex only, with no
# policy attached. An Access application with zero policies denies everyone,
# so the flag that looked like "turn on 2FA for admins" actually locked the
# operators out of their own /wp-admin. Emails now drive it: no emails, no
# application.
#
# THREE THINGS THAT BREAK A SITE IF THEY ARE LEFT OUT, all of them measured:
#
#  1. admin-ajax.php and admin-post.php live UNDER /wp-admin/ and are used by
#     logged-OUT visitors: WooCommerce carts, and any front-end form that posts
#     to admin-post.php (a contact form does). Gating them turns the public
#     site into a login prompt for machines. They get Bypass applications; per
#     Cloudflare's docs on overlapping paths, the more specific application
#     wins, so these must exist as their own apps rather than as policies.
#  2. /wp-login.php cannot be gated on a site whose users reset passwords.
#     The reset link is /wp-login.php?action=rp&key=..., Access matches by PATH
#     and has no query-string condition, so gating that path breaks every reset.
#     That is what wp_admin_access_login_hosts is for: opt IN per host.
#  3. An Access application matches ONE host. A WordPress install on a
#     subdomain needs its own entry in wp_admin_access_hosts.
locals {
  wp_admin_access_enabled = length(var.wp_admin_access_emails) > 0

  wp_admin_hosts = length(var.wp_admin_access_hosts) > 0 ? var.wp_admin_access_hosts : [var.domain_name]

  # Applications that ASK for identity.
  wp_admin_gates = local.wp_admin_access_enabled ? merge(
    { for h in local.wp_admin_hosts : "admin|${h}" => {
      host = h
      path = "wp-admin"
      name = "WordPress Admin — ${h}"
    } },
    { for h in var.wp_admin_access_login_hosts : "login|${h}" => {
      host = h
      path = "wp-login.php"
      name = "WordPress Login — ${h}"
    } },
  ) : {}

  # Applications that let machines through untouched.
  wp_admin_bypasses = local.wp_admin_access_enabled ? merge([
    for h in local.wp_admin_hosts : {
      "ajax|${h}" = {
        host = h
        path = "wp-admin/admin-ajax.php"
        name = "WP admin-ajax (bypass) — ${h}"
      }
      "post|${h}" = {
        host = h
        path = "wp-admin/admin-post.php"
        name = "WP admin-post (bypass) — ${h}"
      }
    }
  ]...) : {}
}

resource "cloudflare_zero_trust_access_application" "wp_admin" {
  for_each                  = local.wp_admin_gates
  zone_id                   = data.cloudflare_zone.main.id
  name                      = each.value.name
  domain                    = "${each.value.host}/${each.value.path}"
  type                      = "self_hosted"
  session_duration          = var.wp_admin_access_session_duration
  auto_redirect_to_identity = true
}

resource "cloudflare_zero_trust_access_policy" "wp_admin" {
  for_each       = local.wp_admin_gates
  application_id = cloudflare_zero_trust_access_application.wp_admin[each.key].id
  zone_id        = data.cloudflare_zone.main.id
  name           = "WordPress admins"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.wp_admin_access_emails
    # A way back in when the identity provider cannot be reached. Empty list =
    # absent, so this costs nothing when it is not configured.
    ip = var.wp_admin_access_break_glass_ips
  }
}

resource "cloudflare_zero_trust_access_application" "wp_admin_bypass" {
  for_each         = local.wp_admin_bypasses
  zone_id          = data.cloudflare_zone.main.id
  name             = each.value.name
  domain           = "${each.value.host}/${each.value.path}"
  type             = "self_hosted"
  session_duration = "24h"
}

resource "cloudflare_zero_trust_access_policy" "wp_admin_bypass" {
  for_each       = local.wp_admin_bypasses
  application_id = cloudflare_zero_trust_access_application.wp_admin_bypass[each.key].id
  zone_id        = data.cloudflare_zone.main.id
  name           = "Machines and logged-out visitors"
  precedence     = 1
  decision       = "bypass"

  include {
    everyone = true
  }
}

# ========================================
# Zero Trust Access for monitoring subdomains
# ========================================
# Prometheus has NO built-in auth and Grafana is internal-only; Cloudflare Access
# puts an identity gate (One-time PIN to the listed emails) in front of both.
# Created only when monitoring_access_emails is non-empty.
#
# Alertmanager is opt-in and deliberately so. It has no authentication either,
# but unlike Prometheus it is not read-only: its API SILENCES alerts. Publishing
# it without a gate hands an attacker the ability to mute the alerting and then
# work unobserved. Never create the DNS record before this application exists.
locals {
  monitoring_access_apps = length(var.monitoring_access_emails) > 0 ? merge(
    {
      grafana    = "Grafana (Monitoring)"
      prometheus = "Prometheus (Monitoring)"
    },
    var.monitoring_access_include_alertmanager ? { alertmanager = "Alertmanager (Monitoring)" } : {},
  ) : {}
}

resource "cloudflare_zero_trust_access_application" "monitoring" {
  for_each                  = local.monitoring_access_apps
  zone_id                   = data.cloudflare_zone.main.id
  name                      = each.value
  domain                    = "${each.key}.${var.domain_name}"
  type                      = "self_hosted"
  session_duration          = "24h"
  auto_redirect_to_identity = false
}

resource "cloudflare_zero_trust_access_policy" "monitoring" {
  for_each       = local.monitoring_access_apps
  application_id = cloudflare_zero_trust_access_application.monitoring[each.key].id
  zone_id        = data.cloudflare_zone.main.id
  name           = "Monitoring allowed admins"
  precedence     = 1
  decision       = "allow"

  include {
    email = var.monitoring_access_emails
  }
}
