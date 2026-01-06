# Complete Caching Stack Documentation

**Optimized for WordPress + LearnDash Premium Course Platform**

## 📊 Overview

This infrastructure implements a **5-layer caching stack** designed for maximum performance while maintaining security and dynamic content functionality.

```
┌─────────────────────────────────────────────────────────┐
│                    USER REQUEST                          │
└─────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────┐
│ LAYER 1: Cloudflare CDN + Edge Cache                   │
│ - Global CDN with 300+ PoPs                             │
│ - Static assets: 7-30 days cache                        │
│ - HTML pages: 2-4 hours cache                           │
│ - DDoS protection + WAF                                  │
└─────────────────────────────────────────────────────────┘
                           ↓ (Cache MISS)
┌─────────────────────────────────────────────────────────┐
│ LAYER 2: Nginx FastCGI Cache                            │
│ - Full-page caching of PHP output                       │
│ - Bypass for logged-in users                            │
│ - 1 hour TTL for public pages                           │
│ - Micro-caching (1s) for dynamic pages                  │
└─────────────────────────────────────────────────────────┘
                           ↓ (Cache MISS)
┌─────────────────────────────────────────────────────────┐
│ LAYER 3: Valkey Object Cache                            │
│ - WordPress transients                                   │
│ - Database query results                                │
│ - LearnDash course data                                 │
│ - WooCommerce sessions                                  │
└─────────────────────────────────────────────────────────┘
                           ↓ (Cache MISS)
┌─────────────────────────────────────────────────────────┐
│ LAYER 4: MySQL Query Cache + OpCache                    │
│ - MySQL query results caching                           │
│ - PHP OpCache for compiled bytecode                     │
└─────────────────────────────────────────────────────────┘
                           ↓ (Cache MISS)
┌─────────────────────────────────────────────────────────┐
│ LAYER 5: Filesystem (SSD)                               │
│ - Fast NVMe SSD storage                                 │
│ - Final data retrieval                                  │
└─────────────────────────────────────────────────────────┘
```

---

## 🎯 Performance Targets

| Metric | Without Cache | With Full Stack | Improvement |
|--------|---------------|-----------------|-------------|
| **TTFB** (Public pages) | 800-1200ms | 50-150ms | 85% faster |
| **TTFB** (Student dashboard) | 1500-2500ms | 200-400ms | 80% faster |
| **Page load** (Landing) | 2-3s | 0.5-0.8s | 75% faster |
| **Concurrent users** | 20-30 | 100-200 | 5x capacity |
| **Database queries/page** | 50-100 | 5-15 | 80% reduction |

---

## 🔧 Layer 1: Cloudflare CDN

### Configuration

**Plan**: FREE initially, PRO ($20/mes) recommended for production

**DNS Records**:

```yaml
Type: A
Name: @
Content: <WORDPRESS_SERVER_IP>
Proxy: ENABLED (Orange cloud ✅)

Type: A
Name: www
Content: <WORDPRESS_SERVER_IP>
Proxy: ENABLED (Orange cloud ✅)
```

**SSL/TLS Settings**:

```yaml
Mode: Full (strict)
Always Use HTTPS: ON
HSTS: Enabled
  - Max Age: 6 months
  - Include subdomains: ON
  - Preload: ON
Minimum TLS: 1.2
TLS 1.3: ON
Automatic HTTPS Rewrites: ON
```

**Speed Optimizations**:

```yaml
Auto Minify:
  ✅ JavaScript
  ✅ CSS
  ✅ HTML

Brotli: ON
Early Hints: ON
Rocket Loader: OFF (conflicts with LearnDash)
```

**Caching Configuration**:

```yaml
Caching Level: Standard
Browser Cache TTL: 4 hours
Always Online: ON
Development Mode: OFF
```

**Page Rules** (PRO plan):

```yaml
# Rule 1: Bypass admin
Pattern: *tudominio.com/wp-admin*
Settings:
  - Cache Level: Bypass
  - Security Level: High

# Rule 2: Bypass checkout
Pattern: *tudominio.com/checkout*
Settings:
  - Cache Level: Bypass
  - Security Level: High

# Rule 3: Bypass student dashboard (logged in)
Pattern: *tudominio.com/courses/*
Settings:
  - Cache Level: Bypass (for logged-in users)
  - Respect Existing Headers: ON

# Rule 4: Cache static assets aggressively
Pattern: *tudominio.com/*.{jpg,jpeg,png,gif,ico,css,js,svg,woff,woff2}
Settings:
  - Cache Level: Cache Everything
  - Edge Cache TTL: 30 days
  - Browser Cache TTL: 7 days

# Rule 5: Cache landing page
Pattern: tudominio.com/
Settings:
  - Cache Level: Cache Everything
  - Edge Cache TTL: 2 hours
  - Browser Cache TTL: 4 hours
```

**Firewall Rules**:

```yaml
# Block bad bots
Expression: (cf.bot_management.score lt 30)
Action: Block

# Rate limiting - Login
Expression: (http.request.uri.path contains "/wp-login.php")
Action: Challenge
Requests: 5 per 5 minutes

# Rate limiting - Checkout
Expression: (http.request.uri.path contains "/checkout")
Action: Block
Requests: 20 per minute
```

---

## 🔧 Layer 2: Nginx FastCGI Cache

### Configuration

Deployed automatically by `nginx-wordpress` role.

**Cache Location**: `/var/run/nginx-cache`

**Configuration** (`/etc/nginx/conf.d/fastcgi-cache.conf`):

```nginx
# FastCGI Cache Zone
fastcgi_cache_path /var/run/nginx-cache
    levels=1:2
    keys_zone=WORDPRESS:100m
    inactive=60m
    max_size=1g;

fastcgi_cache_key "$scheme$request_method$host$request_uri";
fastcgi_cache_use_stale error timeout invalid_header http_500 http_503;
fastcgi_cache_background_update on;
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
```

**Bypass Conditions**:

```nginx
# Don't cache if:
set $skip_cache 0;

# Logged in users
if ($http_cookie ~* "wordpress_logged_in") {
    set $skip_cache 1;
}

# WooCommerce cart/checkout
if ($request_uri ~* "/checkout|/cart|/my-account") {
    set $skip_cache 1;
}

# LearnDash student area
if ($request_uri ~* "/courses/|/lessons/") {
    set $skip_cache 1;
}

# WordPress admin
if ($request_uri ~* "/wp-admin|/xmlrpc.php|wp-.*.php") {
    set $skip_cache 1;
}

# POST requests
if ($request_method = POST) {
    set $skip_cache 1;
}

# Query strings
if ($query_string != "") {
    set $skip_cache 1;
}
```

**TTL Settings**:

```nginx
# Public pages (landing, about, blog)
fastcgi_cache_valid 200 1h;

# 404s
fastcgi_cache_valid 404 10m;

# Redirects
fastcgi_cache_valid 301 302 10m;
```

**Purge Configuration**:

Cache is automatically purged when:

- Publishing/updating a post
- Publishing/updating a page
- Changing theme
- Activating/deactivating plugins

Uses: `nginx-helper` WordPress plugin

---

## 🔧 Layer 3: Valkey Object Cache

### Configuration

Deployed by `valkey` role.

**Version**: Valkey 8.0 (100% Redis-compatible, open source fork)
**Connection**: Unix socket (`/var/run/valkey/valkey.sock`)
**Memory Limit**: 256 MB
**Eviction Policy**: `allkeys-lru` (evict least recently used)

**Why Valkey instead of Redis?**

- Open source (BSD license) - Redis changed to RSALv2/SSPLv1 in March 2024
- Linux Foundation project (AWS, Google Cloud backing)
- 100% Redis protocol compatible
- Actively developed fork with performance improvements

**WordPress Integration**:

Plugin: [Redis Object Cache](https://wordpress.org/plugins/redis-cache/) (fully compatible with Valkey)

Configuration in `wp-config.php`:

```php
define('WP_REDIS_CLIENT', 'phpredis');
define('WP_REDIS_SCHEME', 'unix');
define('WP_REDIS_PATH', '/var/run/valkey/valkey.sock');
define('WP_REDIS_DATABASE', 0);
define('WP_REDIS_PREFIX', 'wp_');
define('WP_REDIS_TIMEOUT', 1);
define('WP_REDIS_READ_TIMEOUT', 1);
define('WP_CACHE', true);
```

**What Valkey Caches**:

1. **WordPress Core**:
   - Transients (temporary data)
   - Options cache
   - Post metadata
   - User metadata
   - Site metadata

2. **LearnDash**:
   - Course progress data
   - Quiz results
   - User course enrollments
   - Lesson completion status
   - Certificate data

3. **WooCommerce**:
   - Cart sessions
   - Product data
   - Category queries
   - Tax calculations

4. **Custom Queries**:
   - Any `wp_cache_*` functions

**Monitoring**:

Valkey Exporter exposes metrics on port `9121` for Prometheus:

- `valkey_connected_clients`
- `valkey_used_memory_bytes`
- `valkey_keyspace_hits_total`
- `valkey_keyspace_misses_total`

**Maintenance**:

Automatic daily backup at 2 AM:

```bash
/usr/local/bin/backup-valkey
```

Backups stored in: `/var/backups/valkey/`
Retention: 7 days

---

## 🔧 Layer 4: MySQL Query Cache + OpCache

### MySQL Configuration

**Query Cache** (if supported by MySQL version):

```sql
query_cache_type = 1
query_cache_size = 128M
query_cache_limit = 2M
```

**InnoDB Buffer Pool**:

```sql
innodb_buffer_pool_size = 1G  # For cx21 with 4GB RAM
innodb_buffer_pool_instances = 4
```

**Connections**:

```sql
max_connections = 200
max_connect_errors = 10000
```

### PHP OpCache

**Configuration** (`/etc/php/8.3/fpm/conf.d/10-opcache.ini`):

```ini
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.fast_shutdown=1
opcache.enable_cli=1
```

**What OpCache Does**:

- Caches compiled PHP bytecode in memory
- Eliminates need to recompile on every request
- ~30-50% performance improvement for PHP execution

---

## 🔧 Layer 5: Filesystem Optimization

### SSD Performance

Hetzner servers use **NVMe SSDs**:

- Sequential read: ~3,000 MB/s
- Sequential write: ~1,500 MB/s
- Random IOPS: ~100,000

### Filesystem

**Ext4** with optimizations:

```bash
# Mount options
/dev/sda1 / ext4 defaults,noatime,nodiratime 0 1
```

**Benefits**:

- `noatime`: Don't update access time on file reads (faster)
- `nodiratime`: Don't update access time on directories

---

## 📊 Cache Hit Rates

### Expected Performance

| Cache Layer | Hit Rate | Response Time |
|-------------|----------|---------------|
| Cloudflare (static) | 95-99% | 10-50ms |
| Cloudflare (HTML) | 70-85% | 50-100ms |
| Nginx FastCGI | 60-80% | 100-200ms |
| Valkey Object Cache | 85-95% | 200-400ms |
| MariaDB Query Cache | 70-90% | 300-500ms |
| Disk (SSD) | 100% | 500-800ms |

### Monitoring Cache Performance

**Cloudflare Analytics**:

- Dashboard → Analytics → Caching
- Shows: Bandwidth saved, requests cached, cache hit ratio

**Nginx Cache Stats**:

```bash
# Add this to nginx config
add_header X-Cache-Status $upstream_cache_status;
```

Possible values:

- `HIT`: Served from cache
- `MISS`: Not in cache
- `BYPASS`: Cache bypassed (logged-in user)
- `EXPIRED`: Cache expired, refreshing

**Valkey Stats**:

```bash
# Via WordPress
wp redis info  # Redis Object Cache plugin is Valkey-compatible

# Via CLI
valkey-cli INFO stats
```

Key metrics:

- `keyspace_hits`: Cache hits
- `keyspace_misses`: Cache misses
- Hit ratio = hits / (hits + misses)

**Grafana Dashboard**:

Prometheus scrapes metrics from:

- Valkey Exporter (port 9121)
- Node Exporter (port 9100)
- MariaDB Exporter (optional)

Pre-built dashboard ID: 7362 (Redis Dashboard for Prometheus - compatible with Valkey)

---

## 🎯 LearnDash-Specific Optimizations

### Critical Considerations

**What NOT to Cache**:

1. ❌ Student dashboard (`/courses/`)
2. ❌ Lesson pages (for enrolled students)
3. ❌ Quiz pages
4. ❌ Progress tracking
5. ❌ Certificate generation

**What TO Cache**:

1. ✅ Course catalog (public)
2. ✅ Lesson previews (non-enrolled)
3. ✅ Landing pages
4. ✅ Marketing pages
5. ✅ Static assets (videos via InfoProtector CDN)

### Cache Exclusions

**Nginx**:

```nginx
# Exclude LearnDash student areas
location ~ ^/courses/ {
    fastcgi_cache_bypass $cookie_wordpress_logged_in;
    fastcgi_no_cache $cookie_wordpress_logged_in;
}
```

**Valkey**:
LearnDash automatically uses persistent object cache for:

- User progress (not cached, always fresh from DB)
- Quiz attempts (not cached)
- Certificates (generated on-demand)

Non-user-specific data IS cached:

- Course structure
- Lesson content (for same user)
- Settings

---

## 🚀 Performance Testing

### Tools

**1. GTmetrix**:

```
URL: https://gtmetrix.com
Test: Your landing page
Target: A grade, <1s load time
```

**2. WebPageTest**:

```
URL: https://www.webpagetest.org
Test: From multiple locations
Target: First Byte <200ms, Fully Loaded <2s
```

**3. Lighthouse (Chrome DevTools)**:

```
F12 → Lighthouse → Run audit
Target: 90+ performance score
```

**4. Load Testing with k6**:

```bash
# Install k6
sudo apt install k6

# Test script
k6 run --vus 50 --duration 30s loadtest.js

# Expected: <500ms p95 response time
```

### Benchmarks

**Before Optimization** (no cache):

```
Requests/sec: 10-20
Avg response: 800ms
P95 response: 1500ms
Max concurrent: 20-30 users
```

**After Full Stack** (all caches):

```
Requests/sec: 200-400
Avg response: 100ms
P95 response: 250ms
Max concurrent: 100-200 users
```

---

## 🔧 Troubleshooting

### Cache Not Working

**1. Check Cloudflare**:

```bash
curl -I https://tudominio.com
# Look for: cf-cache-status: HIT
```

**2. Check Nginx**:

```bash
curl -I https://tudominio.com
# Look for: X-Cache-Status: HIT

# Check cache files
ls -lah /var/run/nginx-cache/
```

**3. Check Valkey**:

```bash
# WordPress CLI
wp redis status  # Redis Object Cache plugin works with Valkey

# Direct connection
valkey-cli
> INFO stats
> DBSIZE
```

**4. Check Logs**:

```bash
# Nginx error log
tail -f /var/log/nginx/error.log

# Valkey log
tail -f /var/log/valkey/valkey-server.log

# PHP-FPM log
tail -f /var/log/php8.3-fpm.log
```

### Purging Caches

**Cloudflare**:

```bash
# Via dashboard
Caching → Purge Everything

# Via API
curl -X POST "https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache" \
  -H "Authorization: Bearer {api_token}" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

**Nginx**:

```bash
# Via WordPress plugin: Nginx Helper → Purge Cache

# Manual
rm -rf /var/run/nginx-cache/*
systemctl reload nginx
```

**Valkey**:

```bash
# Via WordPress
wp redis flush  # Redis Object Cache plugin works with Valkey

# Via CLI
valkey-cli FLUSHDB
```

---

## 💡 Best Practices

### Development vs Production

**Development**:

```yaml
Cloudflare: Development Mode (ON) - Bypass cache
Nginx FastCGI: TTL 10s (fast iteration)
Valkey: Enabled (test functionality)
```

**Production**:

```yaml
Cloudflare: Development Mode (OFF) - Full caching
Nginx FastCGI: TTL 1h (optimal)
Valkey: Enabled with monitoring
```

### When to Purge Cache

**Always purge after**:

1. WordPress updates
2. Plugin updates
3. Theme changes
4. Course content updates
5. Pricing changes

**WordPress plugins auto-purge**:

- Nginx Helper (Nginx cache)
- Redis Object Cache (Valkey - fully compatible)
- Cloudflare plugin (Cloudflare)

---

## 📚 Additional Resources

- [Redis Object Cache Plugin](https://wordpress.org/plugins/redis-cache/)
- [Nginx FastCGI Cache Documentation](https://nginx.org/en/docs/http/ngx_http_fastcgi_module.html#fastcgi_cache)
- [Cloudflare Cache Rules](https://developers.cloudflare.com/cache/)
- [LearnDash Performance Guide](https://www.learndash.com/support/docs/core/settings/performance/)

---

**Last Updated**: 2025-12-26
**Infrastructure Version**: v2.0
**Maintained By**: Infrastructure Team
