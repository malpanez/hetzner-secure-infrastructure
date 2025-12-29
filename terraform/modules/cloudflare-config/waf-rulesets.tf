# ========================================
# WAF Rules - WordPress Protection (Custom Rulesets)
# ========================================

# WordPress Security Ruleset
# Migrated from deprecated cloudflare_filter + cloudflare_firewall_rule
resource "cloudflare_ruleset" "wordpress_security" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "WordPress Security Rules"
  description = "Custom WAF rules for WordPress protection"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  # Rule 1: Block XML-RPC attacks (common WordPress vulnerability)
  rules {
    action      = "block"
    expression  = "(http.request.uri.path eq \"/xmlrpc.php\")"
    description = "Block XML-RPC attacks on WordPress"
    enabled     = true
  }

  # Rule 2: Challenge wp-login.php (brute force protection)
  rules {
    action      = "challenge"
    expression  = "(http.request.uri.path contains \"/wp-login.php\") or (http.request.uri.path contains \"/wp-admin/\" and http.request.method eq \"POST\")"
    description = "Rate limit WordPress login attempts with CAPTCHA"
    enabled     = true
  }

  # Rule 3: Block wp-config.php access
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"wp-config.php\")"
    description = "Block access to WordPress config file"
    enabled     = true
  }

  # Rule 4: Block common attack patterns (path traversal, XSS)
  rules {
    action      = "block"
    expression  = "(http.request.uri.path contains \"..\") or (http.request.uri.path contains \"etc/passwd\") or (http.request.uri.path contains \"eval(\") or (http.request.uri.query contains \"<script\")"
    description = "Block path traversal and XSS attempts"
    enabled     = true
  }
}

# Course Protection Ruleset (optional, for LMS content)
resource "cloudflare_ruleset" "course_protection" {
  count       = var.enable_course_protection ? 1 : 0
  zone_id     = data.cloudflare_zone.main.id
  name        = "Course Content Protection"
  description = "Require authentication for course access"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action      = "challenge"
    expression  = "(http.request.uri.path contains \"/courses/\") and not (http.cookie contains \"wordpress_logged_in\")"
    description = "Require login for course access"
    enabled     = true
  }
}
