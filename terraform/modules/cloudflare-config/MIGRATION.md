# Cloudflare Terraform Migration TODO

## Deprecated Resources - Action Required by June 15, 2025

The following `cloudflare_filter` and `cloudflare_firewall_rule` resources are deprecated and must be migrated to `cloudflare_ruleset` before the deprecation deadline.

**Deprecation Deadline**: June 15, 2025

### Resources to Migrate

1. **XML-RPC Protection** (lines 126-138)
   - `cloudflare_filter.block_xmlrpc`
   - `cloudflare_firewall_rule.block_xmlrpc`
   - Expression: `(http.request.uri.path eq "/xmlrpc.php")`
   - Action: block

2. **Login Rate Limiting** (lines 141-153)
   - `cloudflare_filter.rate_limit_login`
   - `cloudflare_firewall_rule.rate_limit_login`
   - Expression: `(http.request.uri.path contains "/wp-login.php") or (http.request.uri.path contains "/wp-admin/" and http.request.method eq "POST")`
   - Action: challenge (CAPTCHA)

3. **wp-config.php Protection** (lines 156-168)
   - `cloudflare_filter.block_wp_config`
   - `cloudflare_firewall_rule.block_wp_config`
   - Expression: `(http.request.uri.path contains "wp-config.php")`
   - Action: block

4. **Attack Pattern Blocking** (lines 171-183)
   - `cloudflare_filter.block_attacks`
   - `cloudflare_firewall_rule.block_attacks`
   - Expression: Path traversal, XSS, eval attempts
   - Action: block

5. **Course Protection** (lines 186-200, conditional)
   - `cloudflare_filter.protect_courses`
   - `cloudflare_firewall_rule.protect_courses`
   - Expression: `(http.request.uri.path contains "/courses/" and not http.cookie contains "wordpress_logged_in")`
   - Action: challenge

### Migration Guide

**Official Documentation**:
https://developers.cloudflare.com/waf/reference/migration-guides/firewall-rules-to-custom-rules/#relevant-changes-for-terraform-users

**Migration Steps**:
1. Review the Cloudflare Ruleset documentation
2. Convert each filter + firewall_rule pair to a single `cloudflare_ruleset` resource
3. Test in staging environment
4. Update production configuration
5. Remove deprecated resources

### Example Migration Pattern

**Old (Deprecated)**:
```hcl
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
```

**New (cloudflare_ruleset)**:
```hcl
resource "cloudflare_ruleset" "wordpress_protection" {
  zone_id     = data.cloudflare_zone.main.id
  name        = "WordPress Security Rules"
  description = "Custom rules for WordPress protection"
  kind        = "zone"
  phase       = "http_request_firewall_custom"

  rules {
    action = "block"
    expression = "(http.request.uri.path eq \"/xmlrpc.php\")"
    description = "Block XML-RPC attacks on WordPress"
  }

  # Additional rules here...
}
```

### Current Status

- ✅ Configuration validated successfully
- ⚠️ 12 deprecation warnings (can be ignored until June 2025)
- 🔄 Migration recommended but not urgent

### Notes

- The deprecated resources are still fully functional
- No immediate action required
- Plan migration before June 15, 2025 deadline
- Test thoroughly in staging before applying to production
