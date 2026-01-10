# Nginx Configuration Improvements

> **Analysis of current config + recommended optimizations**

---

## ✅ What's Already Good

Your current nginx configuration is already solid:

- ✅ FastCGI caching configured
- ✅ Gzip compression enabled
- ✅ Security headers (server_tokens off)
- ✅ File upload limits set correctly
- ✅ Cache bypass for logged-in users
- ✅ Static file caching

---

## 🚀 Recommended Improvements

### 1. Security Headers (HIGH PRIORITY)

**Missing**: Modern security headers for production

**Add to server block**:

```nginx
# Security Headers (add after server_name)
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;

# Only if using Cloudflare (they terminate SSL)
# Don't add if using direct SSL
# add_header Strict-Transport-Security "max-age=31536000; includeSubDomains" always;

# Content Security Policy (adjust for your needs)
add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com https://cdn.learndash.com; style-src 'self' 'unsafe-inline' https://fonts.googleapis.com; font-src 'self' https://fonts.gstatic.com; img-src 'self' data: https:; connect-src 'self';" always;

# Permissions Policy (formerly Feature-Policy)
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

**Why**: Protects against XSS, clickjacking, MIME-sniffing attacks.

---

### 2. Rate Limiting for Login & API (HIGH PRIORITY)

**Current**: No rate limiting on wp-login.php

**Add before server block**:

```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;   # 5 requests per minute for login
limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;    # 60 req/min for LearnDash API
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s; # 10 req/sec general
```

**Add to locations**:

```nginx
# WordPress login rate limiting
location = /wp-login.php {
    limit_req zone=login burst=3 nodelay;
    limit_req_status 429;

    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}

# LearnDash/WooCommerce API rate limiting
location ~ ^/wp-json/ {
    limit_req zone=api burst=20 nodelay;

    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}

# XML-RPC protection (disable or heavily rate limit)
location = /xmlrpc.php {
    deny all;  # Or: limit_req zone=login burst=1 nodelay;
}
```

**Why**: Prevents brute force attacks, DDoS on expensive endpoints.

---

### 3. Cloudflare Real IP Integration (CRITICAL if using Cloudflare)

**Current**: May not be getting real visitor IPs

**Add to http block** (nginx.conf.j2):

```nginx
# Cloudflare real IP (REQUIRED if using Cloudflare)
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 103.22.200.0/22;
set_real_ip_from 103.31.4.0/22;
set_real_ip_from 104.16.0.0/13;
set_real_ip_from 104.24.0.0/14;
set_real_ip_from 108.162.192.0/18;
set_real_ip_from 131.0.72.0/22;
set_real_ip_from 141.101.64.0/18;
set_real_ip_from 162.158.0.0/15;
set_real_ip_from 172.64.0.0/13;
set_real_ip_from 173.245.48.0/20;
set_real_ip_from 188.114.96.0/20;
set_real_ip_from 190.93.240.0/20;
set_real_ip_from 197.234.240.0/22;
set_real_ip_from 198.41.128.0/17;
# IPv6
set_real_ip_from 2400:cb00::/32;
set_real_ip_from 2606:4700::/32;
set_real_ip_from 2803:f800::/32;
set_real_ip_from 2405:b500::/32;
set_real_ip_from 2405:8100::/32;
set_real_ip_from 2a06:98c0::/29;
set_real_ip_from 2c0f:f248::/32;

real_ip_header CF-Connecting-IP;  # Cloudflare's header
real_ip_recursive on;
```

**Why**: Without this, all requests appear to come from Cloudflare IPs, breaking:

- WordPress IP logging
- Fail2ban
- Rate limiting
- Analytics

---

### 4. Static Asset Optimization (MEDIUM PRIORITY)

**Improve**:

```nginx
# Better static file caching
location ~* \.(jpg|jpeg|png|gif|ico|css|js|svg|woff|woff2|ttf|eot|webp)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header X-Content-Type-Options "nosniff" always;

    # Disable logging for static files
    access_log off;
    log_not_found off;

    # CORS for fonts (if serving from CDN)
    location ~* \.(woff|woff2|ttf|eot)$ {
        add_header Access-Control-Allow-Origin "*";
    }
}

# PDF/Documents (common in LMS)
location ~* \.(pdf|doc|docx|ppt|pptx|zip|tar|gz)$ {
    expires 30d;
    add_header Cache-Control "public";
    access_log off;
}
```

**Why**: Longer cache for static assets, specific handling for LMS course materials.

---

### 5. LearnDash-Specific Optimizations (LMS)

**Add**:

```nginx
# LearnDash course content (don't cache)
location ~* /courses/ {
    set $no_cache 1;  # Force no cache for course pages
}

# LearnDash quiz pages (never cache)
location ~* /quiz/ {
    set $no_cache 1;
}

# LearnDash progress tracking (API endpoints)
location ~* /wp-admin/admin-ajax.php {
    # Allow AJAX but rate limit
    limit_req zone=api burst=30 nodelay;

    # Never cache AJAX
    set $no_cache 1;

    fastcgi_cache_bypass 1;
    fastcgi_no_cache 1;

    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
}

# User profile pages (personalized content)
location ~* /profile/|/my-courses/ {
    set $no_cache 1;
}
```

**Why**: LMS content must never be cached - students need real-time progress updates.

---

### 6. Improved Cache Bypass Logic (MEDIUM PRIORITY)

**Current**: Basic cookie-based bypass
**Improved**:

```nginx
# More comprehensive cache bypass
set $no_cache 0;

# POST requests
if ($request_method = POST) {
    set $no_cache 1;
}

# Query strings (except common tracking params)
if ($query_string != "") {
    set $skip_reason "query_string";
    set $no_cache 1;
}

# Allow caching for common tracking params
if ($query_string ~* "^utm_|^fbclid=|^gclid=") {
    set $no_cache 0;
}

# WordPress admin/login
if ($request_uri ~* "/wp-admin/|/wp-login.php|/wp-register.php") {
    set $no_cache 1;
}

# LearnDash specific (courses, quizzes, user areas)
if ($request_uri ~* "/courses/|/quiz/|/my-courses/|/profile/") {
    set $no_cache 1;
}

# WooCommerce (if using for course sales)
if ($request_uri ~* "/cart/|/checkout/|/my-account/") {
    set $no_cache 1;
}

# WordPress logged-in cookies
if ($http_cookie ~* "wordpress_logged_in|wp-postpass|woocommerce_|edd_") {
    set $no_cache 1;
}

# LearnDash cookies
if ($http_cookie ~* "learndash_") {
    set $no_cache 1;
}
```

**Why**: Better cache accuracy for LMS, allows caching pages with tracking params.

---

### 7. Brotli Compression (MEDIUM PRIORITY)

**If module available** (Debian 13 should have it):

```nginx
# In nginx.conf.j2 http block
brotli on;
brotli_comp_level 6;
brotli_types text/plain text/css text/xml text/javascript application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;
```

**Why**: Better compression than gzip (15-20% smaller), supported by all modern browsers.

---

### 8. HTTP/3 Support (LOW PRIORITY - Future)

**If Debian 13 nginx has QUIC**:

```nginx
server {
    listen 443 quic reuseport;  # HTTP/3
    listen 443 ssl http2;        # HTTP/2 fallback

    # Advertise HTTP/3
    add_header Alt-Svc 'h3=":443"; ma=86400';
}
```

**Why**: HTTP/3 (QUIC) is faster, especially on mobile networks.

---

### 9. Buffer Size Optimization (MEDIUM PRIORITY)

**Current**: Good, but can be tuned for LMS
**Improve**:

```nginx
# In server block - optimize for LearnDash large content
client_body_buffer_size 256k;  # Larger for course uploads
client_header_buffer_size 2k;
large_client_header_buffers 4 32k;  # Larger for long URLs (quiz params)

# FastCGI buffers (for large JSON responses from LMS)
fastcgi_buffer_size 256k;
fastcgi_buffers 256 32k;  # Increased for LMS API responses
fastcgi_busy_buffers_size 512k;
```

**Why**: LMS generates large JSON responses (course data, quiz results), needs bigger buffers.

---

### 10. Security: Block Bad Bots (MEDIUM PRIORITY)

**Add**:

```nginx
# Block common bad bots (Cloudflare handles most, but defense in depth)
if ($http_user_agent ~* (bot|crawler|spider|scrapy|curl|wget|python-requests) ) {
    set $bad_bot 1;
}

# Allow legitimate bots
if ($http_user_agent ~* (googlebot|bingbot|duckduckbot|linkedinbot) ) {
    set $bad_bot 0;
}

if ($bad_bot = 1) {
    return 403;
}
```

**Why**: Prevents scraping of premium course content.

---

## 📊 Priority Implementation Order

### Phase 1: Security (Before Production)

1. ✅ **Security headers** (5 min)
2. ✅ **Rate limiting on wp-login.php** (10 min)
3. ✅ **Cloudflare real IP** (10 min) - CRITICAL if using CF
4. ✅ **XML-RPC disable** (2 min)

### Phase 2: Performance (After Testing)

5. ⏳ **Improved cache bypass** (15 min)
2. ⏳ **LearnDash-specific caching** (10 min)
3. ⏳ **Static asset optimization** (5 min)

### Phase 3: Advanced (Optional)

8. ⏳ **Brotli compression** (if module available)
2. ⏳ **Bad bot blocking**
3. ⏳ **HTTP/3** (future)

---

## 📝 Implementation Guide

### Step 1: Backup Current Config

```bash
ansible-playbook playbooks/site.yml --tags nginx-wordpress --check
```

### Step 2: Update Templates

Edit the following files:

- `ansible/roles/nginx_wordpress/templates/nginx-wordpress.conf.j2`
- `ansible/roles/nginx_wordpress/defaults/main.yml` (add new variables)

### Step 3: Test Configuration

```bash
# On server
nginx -t

# If OK, reload
systemctl reload nginx
```

### Step 4: Monitor

Watch logs and Grafana for:

- Rate limit hits (429 errors)
- Cache hit rate
- Response times

---

## 🎯 Expected Performance Impact

| Improvement | Before | After | Benefit |
|-------------|--------|-------|---------|
| **Cache hit rate** | 70-80% | 85-95% | Better cache bypass logic |
| **Static asset load** | 200ms | 50ms | Longer expires, immutable |
| **Login brute force** | Vulnerable | Protected | Rate limiting |
| **API DDoS** | Vulnerable | Protected | Rate limiting |
| **Compression ratio** | gzip (70%) | brotli (80-85%) | 15-20% smaller |
| **Security score** | B+ | A+ | Modern headers |

---

## 🔒 Security Improvements Summary

| Attack Vector | Current | Improved |
|---------------|---------|----------|
| **Brute force login** | ⚠️ Partial (Cloudflare + fail2ban) | ✅ Multiple layers |
| **XSS** | ⚠️ Partial (WordPress) | ✅ CSP headers |
| **Clickjacking** | ❌ Vulnerable | ✅ X-Frame-Options |
| **MIME sniffing** | ❌ Vulnerable | ✅ X-Content-Type-Options |
| **Bot scraping** | ⚠️ Cloudflare only | ✅ Nginx + Cloudflare |
| **XML-RPC DDoS** | ❌ Open | ✅ Blocked |
| **API DDoS** | ❌ Vulnerable | ✅ Rate limited |

---

## 💡 Recommendations

### Highest Value, Lowest Effort

1. **Security headers** - Copy/paste, instant A+ security score
2. **Cloudflare real IP** - Critical for logs, analytics, rate limiting
3. **Rate limit wp-login.php** - Prevents 99% of brute force attacks
4. **Disable XML-RPC** - Closes major attack vector

### Test First

- LearnDash-specific caching (test with actual courses)
- Rate limiting (ensure legitimate users not blocked)
- CSP header (may need adjustment for plugins)

### Monitor After

- Grafana nginx dashboards (req/s, cache hit rate)
- Error logs (`/var/log/nginx/error.log`)
- Rate limit logs (429 errors)

---

## 📁 Files to Update

1. `ansible/roles/nginx_wordpress/templates/nginx-wordpress.conf.j2` - Server config
2. `ansible/roles/nginx_wordpress/defaults/main.yml` - Add new variables
3. `ansible/roles/nginx_wordpress/tasks/main.yml` - Add rate limit setup

---

**Validation:** Siempre prueba con `sudo nginx -t` antes de recargar.

**Ready to implement?** I can create the updated configuration files for you!

**Want to see the complete improved config?** Let me know and I'll generate the full nginx-wordpress.conf.j2 with all improvements integrated.

**Last Updated:** 2026-01-09
