# Cloudflare Configuration Module

This Terraform module configures Cloudflare DNS, SSL/TLS, WAF, and security settings optimized for WordPress + Tutor LMS hosting.

## Features

- **DNS Management**: A/AAAA records with CDN proxy
- **SSL/TLS**: Full encryption, TLS 1.2+ minimum, automatic HTTPS rewrites
- **WAF Protection**: WordPress-specific firewall rules
- **Rate Limiting**: Brute force protection for wp-login.php
- **Caching**: Aggressive caching for static assets
- **Performance**: HTTP/2, HTTP/3, Brotli compression
- **Security**: Multiple layers of protection for WordPress and Tutor LMS

## WordPress Security Features

### 1. **XML-RPC Protection**

Blocks XML-RPC attacks (common WordPress vulnerability)

### 2. **Login Protection**

- Rate limiting on wp-login.php (5 attempts/minute)
- CAPTCHA challenges after threshold

### 3. **Config File Protection**

Blocks direct access to wp-config.php

### 4. **Attack Pattern Blocking**

- Path traversal attempts
- XSS injection attempts
- SQL injection patterns

### 5. **Tutor LMS Course Protection**

Optional protection requiring login for course content access

## Usage

### Basic Example

```hcl
module "cloudflare" {
  source = "../../modules/cloudflare-config"

  # Required
  domain_name = "example.com"
  server_ipv4 = "65.108.1.100"

  # Optional
  server_ipv6              = "2a01:4f8:1234:5678::1"
  environment              = "prod"
  enable_rate_limiting     = true
  enable_course_protection = true
}
```

### Production Example

```hcl
module "cloudflare_prod" {
  source = "../../modules/cloudflare-config"

  # Domain and server
  domain_name = "tradingcourse.com"
  server_ipv4 = module.web_server.ipv4_address
  server_ipv6 = module.web_server.ipv6_address

  # Environment
  environment = "prod"

  # Security features
  enable_rate_limiting     = true
  enable_course_protection = true
  security_level           = "high"
  ssl_mode                 = "full" # Use "strict" with valid SSL cert

  # Rate limiting config
  login_rate_limit_threshold = 3  # 3 attempts
  login_rate_limit_period    = 60 # per minute

  # Caching
  browser_cache_ttl = 14400  # 4 hours
  edge_cache_ttl    = 604800 # 7 days

  tags = {
    project     = "trading-course"
    managed_by  = "terraform"
    environment = "production"
  }
}
```

## Prerequisites

### 1. Cloudflare Account Setup

1. **Create Cloudflare account**: <https://dash.cloudflare.com/sign-up>
2. **Add your domain** to Cloudflare (free tier is sufficient)
3. **Get API token**:
   - Go to: My Profile → API Tokens
   - Click "Create Token"
   - Use template: "Edit zone DNS"
   - Permissions: `Zone.Zone Settings`, `Zone.DNS`, `Zone.Firewall Services`
   - Zone Resources: Include → Specific zone → Your domain
   - Click "Continue to summary" → "Create Token"
   - **Save the token** (you won't see it again!)

### 2. Provider Configuration

Add to your root `main.tf`:

```hcl
terraform {
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
```

Add to your `variables.tf`:

```hcl
variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}
```

Set environment variable:

```bash
export TF_VAR_cloudflare_api_token="your-cloudflare-api-token"
```

### 3. Domain Migration from GoDaddy

See [CLOUDFLARE_SETUP.md](../../../docs/CLOUDFLARE_SETUP.md) for complete migration guide.

**Quick steps:**

1. Add domain to Cloudflare
2. Note the Cloudflare nameservers
3. Log into GoDaddy → Domain Settings
4. Change nameservers to Cloudflare's
5. Wait 24-48 hours for propagation
6. Run `tofu apply` to configure DNS and security

## Firewall Rules

The module configures these firewall rules:

| Priority | Rule | Action | Description |
|----------|------|--------|-------------|
| 1 | Block XML-RPC | Block | Prevent XML-RPC attacks |
| 2 | Rate Limit Login | Challenge | CAPTCHA after 5 attempts/min |
| 3 | Block wp-config.php | Block | Prevent config file access |
| 4 | Block Attack Patterns | Block | Path traversal, XSS, SQLi |
| 5 | Protect Courses | Challenge | Require login for courses |

## Page Rules

The module uses **5 page rules** (Free tier allows 3, these require paid plan or prioritize):

| Priority | URL Pattern | Action | Purpose |
|----------|-------------|--------|---------|
| 1 | `/wp-content/uploads/*` | Cache Everything | Static assets |
| 2 | `/wp-admin/*` | Bypass Cache | Admin area |
| 3 | `/wp-login.php` | Bypass Cache + High Security | Login page |
| 4 | `/*.css` | Cache Everything | Stylesheets |
| 5 | `/*.js` | Cache Everything | JavaScript |

**Note**: Free tier only allows **3 page rules**. Prioritize rules 1, 2, and 3.

## Rate Limiting

**Free tier**: 1 rate limiting rule

Configured to protect wp-login.php:

- **Threshold**: 5 requests
- **Period**: 60 seconds
- **Action**: CAPTCHA challenge
- **Timeout**: 3600 seconds (1 hour)

## SSL/TLS Configuration

The module configures:

- **SSL Mode**: `full` (encrypts traffic between Cloudflare ↔ Origin)
- **Min TLS**: 1.2
- **TLS 1.3**: Enabled
- **Always Use HTTPS**: Enabled
- **Automatic HTTPS Rewrites**: Enabled

**For production**: Use `ssl_mode = "strict"` after installing a valid SSL certificate on your origin server.

## Caching Strategy

### Static Assets (30 days)

- `/wp-content/uploads/*` - Images, videos, PDFs

### CSS/JS (7 days)

- `*.css`, `*.js` - Stylesheets and scripts

### No Caching

- `/wp-admin/*` - WordPress admin
- `/wp-login.php` - Login page
- Dynamic pages - Automatic based on headers

## Security Headers

The module enables:

- **HSTS**: `max-age=31536000` (1 year)
- **includeSubDomains**: Yes
- **preload**: Yes
- **X-Content-Type-Options**: `nosniff`

## Tutor LMS Protection

When `enable_course_protection = true`:

- Blocks unauthenticated access to `/courses/*`
- Requires WordPress login cookie
- Displays CAPTCHA challenge if not logged in

**Important**: Ensure Tutor LMS courses use URLs like `/courses/course-name/`

## Performance Optimizations

- ✅ HTTP/2 enabled
- ✅ HTTP/3 (QUIC) enabled
- ✅ Brotli compression
- ✅ CSS/JS/HTML minification
- ✅ 0-RTT connection resumption
- ✅ IPv6 support
- ✅ WebSockets support

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `domain_name` | Domain to configure | `string` | - | Yes |
| `server_ipv4` | Origin server IPv4 | `string` | - | Yes |
| `server_ipv6` | Origin server IPv6 | `string` | `null` | No |
| `environment` | Environment name | `string` | `"prod"` | No |
| `enable_rate_limiting` | Enable rate limiting | `bool` | `true` | No |
| `enable_course_protection` | Protect course content | `bool` | `true` | No |
| `security_level` | Security level | `string` | `"medium"` | No |
| `ssl_mode` | SSL/TLS mode | `string` | `"full"` | No |
| `min_tls_version` | Minimum TLS version | `string` | `"1.2"` | No |

See [variables.tf](variables.tf) for complete list.

## Outputs

| Name | Description |
|------|-------------|
| `zone_id` | Cloudflare Zone ID |
| `name_servers` | Nameservers to configure at registrar |
| `zone_status` | Zone activation status |
| `root_record_hostname` | Root domain hostname |
| `ssl_mode` | Current SSL mode |
| `configuration_summary` | Complete configuration summary |
| `nameserver_instructions` | Setup instructions |

See [outputs.tf](outputs.tf) for complete list.

## Verification

After applying:

```bash
# Check DNS propagation
dig example.com

# Check nameservers
dig NS example.com

# Verify Cloudflare proxy
curl -I https://example.com | grep -i cf-

# Check SSL
curl -vI https://example.com 2>&1 | grep -i tls

# Test rate limiting
for i in {1..10}; do curl https://example.com/wp-login.php; done
```

## Free Tier Limitations

Cloudflare Free tier includes:

- ✅ Unlimited DDoS protection
- ✅ Shared SSL certificate
- ✅ Global CDN
- ✅ **3 page rules** (this module uses 5, prioritize)
- ✅ **1 rate limiting rule** (configured)
- ✅ Basic WAF
- ❌ No advanced bot management
- ❌ No Cloudflare Access (Zero Trust)
- ❌ No image optimization (Polish, Mirage)

## Paid Features (Optional)

If you upgrade to Pro ($20/month):

- 20 page rules (vs 3)
- Better WAF
- Image optimization (Polish)
- Mobile optimization (Mirage)
- Advanced DDoS protection

## Monitoring

Monitor Cloudflare metrics:

1. **Dashboard**: <https://dash.cloudflare.com/>
2. **Analytics**: Traffic, threats blocked, bandwidth saved
3. **Firewall Events**: See blocked requests
4. **Speed**: Performance metrics

## Troubleshooting

### Issue: DNS not resolving

**Solution**: Wait 24-48 hours for DNS propagation after changing nameservers.

```bash
# Check current nameservers
dig NS example.com

# Expected: Cloudflare nameservers
# Example:
#   abby.ns.cloudflare.com
#   todd.ns.cloudflare.com
```

### Issue: SSL errors (ERR_SSL_VERSION_OR_CIPHER_MISMATCH)

**Solution**: Ensure origin server has valid SSL certificate, or use `ssl_mode = "flexible"` (not recommended).

### Issue: Page rules not working

**Solution**: Free tier only allows 3 rules. Remove rules 4 and 5 (CSS/JS caching) or upgrade.

### Issue: Rate limiting too aggressive

**Solution**: Increase threshold:

```hcl
login_rate_limit_threshold = 10  # 10 attempts instead of 5
```

### Issue: WordPress admin blocked

**Solution**: Check firewall events, whitelist your IP:

```hcl
# Add to main.tf
resource "cloudflare_filter" "allow_admin_ip" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Allow admin IP"
  expression  = "(ip.src eq 203.0.113.50 and http.request.uri.path contains \"/wp-admin\")"
}

resource "cloudflare_firewall_rule" "allow_admin_ip" {
  zone_id     = data.cloudflare_zone.main.id
  description = "Allow admin IP"
  filter_id   = cloudflare_filter.allow_admin_ip.id
  action      = "allow"
  priority    = 0  # Higher priority than other rules
}
```

## Security Best Practices

1. **Use API tokens** (not API keys) - scoped permissions
2. **Enable DNSSEC** at Cloudflare and registrar
3. **Use "strict" SSL mode** with valid origin certificate
4. **Enable HSTS** (configured by default)
5. **Review firewall events** weekly
6. **Keep page rules minimal** (Free tier: 3 max)
7. **Combine with UFW on origin** (see docs/CLOUDFLARE_SETUP.md)

## Integration with Hetzner Server

This module works with the `hetzner-server` module:

```hcl
# 1. Create server
module "web_server" {
  source = "../../modules/hetzner-server"
  # ... server config
}

# 2. Configure Cloudflare
module "cloudflare" {
  source = "../../modules/cloudflare-config"

  domain_name = "example.com"
  server_ipv4 = module.web_server.ipv4_address
  server_ipv6 = module.web_server.ipv6_address
}

# 3. Output connection info
output "nameservers" {
  value = module.cloudflare.nameserver_instructions
}
```

## Cost Estimate

| Service | Plan | Monthly Cost |
|---------|------|--------------|
| Cloudflare | Free | €0.00 |
| Cloudflare | Pro | €20.00 |

**Recommended**: Start with Free tier, upgrade to Pro if needed.

## Next Steps

1. **Apply module**: `tofu apply`
2. **Configure nameservers** at GoDaddy (see output)
3. **Wait for DNS propagation** (24-48 hours)
4. **Configure UFW on origin** to only allow Cloudflare IPs
5. **Install SSL certificate** on origin (Let's Encrypt)
6. **Switch to `ssl_mode = "strict"`** for full encryption
7. **Monitor firewall events** at Cloudflare dashboard

## References

- [Cloudflare Terraform Provider](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs)
- [Cloudflare Free Plan Features](https://www.cloudflare.com/plans/free/)
- [WordPress Security on Cloudflare](https://support.cloudflare.com/hc/en-us/articles/360029279352)
- [Cloudflare IP Ranges](https://www.cloudflare.com/ips/) - For UFW configuration

## License

This module is part of the Hetzner Secure Infrastructure project.

## Author

Generated as part of the TOP 0.01% infrastructure transformation.
