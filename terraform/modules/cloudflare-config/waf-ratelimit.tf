# ========================================
# WAF Rate Limiting - wp-login brute-force protection (http_ratelimit phase)
# ========================================
#
# Blocks IPs that flood /wp-login.php at the Cloudflare edge, BEFORE the requests reach
# the origin. Cloudflare proxies HTTP to the origin by default and does NOT stop
# credential-stuffing on a real endpoint unless a rule says so — this rule does.
#
# WHY RATE-LIMIT rather than the blanket wp-login challenge in waf-rulesets.tf: a challenge
# on /wp-login.php hits EVERY legitimate login (WordPress/LMS users authenticate there), and
# ad-blockers can break the challenge widget and lock users out — which is exactly why that
# challenge rule ships disabled. A rate-limit only fires on a FLOOD: a normal login is 2-3
# requests to /wp-login.php, so it never trips; a bot doing tens of req/s does. This is a
# `block` action (not a challenge), so there is no ad-blocker lockout.
#
# FREE-PLAN NOTE: Cloudflare Free allows exactly 1 rate-limiting rule, with a fixed 10s
# counting window, IP-only characteristic, expression fields limited to Path + Verified Bot,
# and a 10s max mitigation timeout. It also enforces its own low effective threshold: it
# blocks after ~5 rapid requests regardless of requests_per_period (verified live). That is
# acceptable — normal spaced logins never trip; only fast bursts (bots, or frantic
# re-clicking) get a brief 10s edge block. requests_per_period IS honored on paid plans,
# where you can raise it. Because Free allows 1 ruleset per phase and the WordPress security
# ruleset already uses http_request_firewall_custom, this rule uses the otherwise-free
# http_ratelimit phase. cf.colo.id is the required internal sharding characteristic.
#
# Provider: cloudflare/cloudflare v4 (~> 4.0). requests_to_origin is required for ratelimit
# blocks in this provider version, so it is set explicitly.

resource "cloudflare_ruleset" "wp_login_rate_limit" {
  count       = var.enable_wp_login_rate_limit ? 1 : 0
  zone_id     = data.cloudflare_zone.main.id
  name        = "wp-login-rate-limit"
  description = "Rate-limit /wp-login.php to mitigate login brute-force at the edge"
  kind        = "zone"
  phase       = "http_ratelimit"

  rules {
    ref         = "rl_wp_login_flood"
    action      = "block"
    description = "Block an IP flooding /wp-login.php (login brute-force)"
    expression  = "(http.request.uri.path contains \"/wp-login.php\")"
    enabled     = true

    ratelimit {
      characteristics     = ["cf.colo.id", "ip.src"]
      period              = 10
      requests_per_period = var.wp_login_rate_limit_requests_per_period
      mitigation_timeout  = 10
      requests_to_origin  = false
    }
  }
}
