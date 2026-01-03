# Nginx Modular Configuration Plan

## Current Problem

The `nginx-wordpress-optimized.conf.j2` file is **460 lines** of monolithic configuration. This makes it:
- Hard to understand which part does what
- Difficult to enable/disable specific features
- Harder to maintain and update
- Complex to test individual features

## Proposed Modular Structure

Instead of one massive file, split into focused, reusable configuration files:

```
/etc/nginx/
├── nginx.conf (main configuration - keep clean)
├── conf.d/
│   ├── fastcgi-cache.conf          # FastCGI cache configuration
│   ├── rate-limits.conf            # Rate limiting zones
│   ├── cloudflare-real-ip.conf     # Cloudflare IP ranges
│   └── security-headers.conf        # Security headers (optional include)
├── snippets/
│   ├── wordpress-cache-bypass.conf  # Cache bypass logic (reusable)
│   ├── wordpress-security.conf      # WordPress security rules
│   ├── ssl-params.conf              # SSL/TLS configuration
│   ├── gzip-params.conf             # Gzip compression settings
│   └── static-assets.conf           # Static file caching rules
└── sites-available/
    └── wordpress.conf               # Main WordPress site (includes snippets)
```

## File Breakdown

### 1. `/etc/nginx/conf.d/` - Global Configuration

These files are **automatically included** in the `http {}` block:

#### `fastcgi-cache.conf`
```nginx
# FastCGI cache path and global settings
fastcgi_cache_path /var/cache/nginx/wordpress levels=1:2 keys_zone=wordpress:100m...
fastcgi_cache_key "$scheme$request_method$host$request_uri";
```

**Why separate**: Cache settings apply globally, configured once

#### `rate-limits.conf`
```nginx
# Rate limiting zones
limit_req_zone $binary_remote_addr zone=login:10m rate=5r/m;
limit_req_zone $binary_remote_addr zone=api:10m rate=60r/m;
```

**Why separate**: Rate limit zones must be in `http {}` block

#### `cloudflare-real-ip.conf`
```nginx
# Cloudflare IP ranges for real IP detection
set_real_ip_from 103.21.244.0/22;
...
real_ip_header CF-Connecting-IP;
```

**Why separate**: Can be disabled if not using Cloudflare

#### `security-headers.conf` (optional)
```nginx
# Security headers (included in server blocks that need them)
add_header X-Frame-Options "SAMEORIGIN" always;
add_header X-Content-Type-Options "nosniff" always;
...
```

**Why separate**: Optional, can be included per-site

---

### 2. `/etc/nginx/snippets/` - Reusable Snippets

These files are **manually included** where needed:

#### `wordpress-cache-bypass.conf`
```nginx
# WordPress-specific cache bypass logic
set $no_cache 0;

if ($request_method = POST) {
    set $no_cache 1;
}

if ($request_uri ~* "/wp-admin/|/wp-login\.php") {
    set $no_cache 1;
}
...
```

**Why separate**: Reusable across multiple WordPress sites

#### `wordpress-security.conf`
```nginx
# WordPress security rules
location ~ /\. {
    deny all;
}

location = /wp-config.php {
    deny all;
}

location = /xmlrpc.php {
    deny all;
}
```

**Why separate**: Standard WordPress security, reusable

#### `ssl-params.conf`
```nginx
# SSL/TLS configuration
ssl_protocols TLSv1.2 TLSv1.3;
ssl_ciphers 'ECDHE-ECDSA-AES128-GCM-SHA256:...';
ssl_prefer_server_ciphers off;
ssl_session_cache shared:SSL:10m;
```

**Why separate**: Reusable across all SSL sites (WordPress, Grafana, Prometheus)

#### `gzip-params.conf`
```nginx
# Gzip compression settings
gzip on;
gzip_vary on;
gzip_comp_level 6;
gzip_types text/plain text/css ...;
```

**Why separate**: Reusable across all sites

#### `static-assets.conf`
```nginx
# Static asset caching rules
location ~* \.(jpg|jpeg|png|gif|ico|svg|webp)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}

location ~* \.(css|js)$ {
    expires 1y;
    add_header Cache-Control "public, immutable";
}
```

**Why separate**: Reusable across multiple sites

---

### 3. `/etc/nginx/sites-available/wordpress.conf` - Main Site

**Simplified, readable main configuration**:

```nginx
# WordPress Site Configuration
# Uses modular includes for clarity

server {
    listen 80;
    listen [::]:80;
    server_name {{ nginx_wordpress_server_name }};

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name {{ nginx_wordpress_server_name }};

    root {{ nginx_wordpress_web_root }};
    index index.php index.html;

    # SSL Configuration (reusable)
    ssl_certificate {{ nginx_wordpress_ssl_cert_path }};
    ssl_certificate_key {{ nginx_wordpress_ssl_key_path }};
    include snippets/ssl-params.conf;

    # Security Headers (optional)
    include conf.d/security-headers.conf;

    # Gzip Compression (reusable)
    include snippets/gzip-params.conf;

    # WordPress Cache Bypass Logic
    include snippets/wordpress-cache-bypass.conf;

    # Logging
    access_log /var/log/nginx/wordpress-access.log;
    error_log /var/log/nginx/wordpress-error.log;

    # Performance Settings
    client_max_body_size {{ nginx_wordpress_php_upload_max_filesize }};
    keepalive_timeout 65;
    keepalive_requests 100;

    # Main WordPress Location
    location / {
        try_files $uri $uri/ /index.php?$args;
    }

    # PHP Processing with FastCGI Cache
    location ~ \.php$ {
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-fpm.sock;

        # FastCGI Cache
        fastcgi_cache wordpress;
        fastcgi_cache_valid 200 60m;
        fastcgi_cache_bypass $no_cache;
        fastcgi_no_cache $no_cache;

        # Buffers for LMS
        fastcgi_buffer_size 256k;
        fastcgi_buffers 256 32k;
        fastcgi_read_timeout 300;
    }

    # Rate-Limited Endpoints
    location = /wp-login.php {
        limit_req zone=login burst=3 nodelay;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-fpm.sock;
        fastcgi_cache_bypass 1;
        fastcgi_no_cache 1;
    }

    location = /wp-admin/admin-ajax.php {
        limit_req zone=api burst=30 nodelay;
        include snippets/fastcgi-php.conf;
        fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-fpm.sock;
        fastcgi_cache_bypass 1;
        fastcgi_no_cache 1;
    }

    # Static Assets (reusable)
    include snippets/static-assets.conf;

    # WordPress Security (reusable)
    include snippets/wordpress-security.conf;

    # Standard Files
    location = /favicon.ico {
        log_not_found off;
        access_log off;
        expires 1y;
    }

    location = /robots.txt {
        log_not_found off;
        access_log off;
    }
}
```

**Total lines**: ~80 (down from 460!)
**Readability**: High (clear what each include does)
**Maintainability**: Easy to update individual features

---

## Benefits of Modular Approach

### 1. **Reusability**
- `ssl-params.conf` used by WordPress, Grafana, Prometheus
- `gzip-params.conf` used by all sites
- `wordpress-security.conf` used by multiple WordPress sites (staging, production)

### 2. **Clarity**
- Main site config is **80 lines** vs **460 lines**
- Each include file has single responsibility
- Easy to understand what each part does

### 3. **Maintainability**
- Update SSL ciphers → change one file (`ssl-params.conf`)
- Update Cloudflare IPs → change one file (`cloudflare-real-ip.conf`)
- Add security header → change one file (`security-headers.conf`)

### 4. **Flexibility**
- Disable Cloudflare? Comment out `include conf.d/cloudflare-real-ip.conf`
- Different security headers per site? Don't include `security-headers.conf`
- Multiple WordPress sites? Reuse all snippets

### 5. **Testing**
- Test FastCGI cache → check `fastcgi-cache.conf`
- Test rate limiting → check `rate-limits.conf`
- Test security rules → check `wordpress-security.conf`

---

## Ansible Implementation

### Template Structure

```
ansible/roles/nginx_wordpress/templates/
├── conf.d/
│   ├── fastcgi-cache.conf.j2
│   ├── rate-limits.conf.j2
│   ├── cloudflare-real-ip.conf.j2
│   └── security-headers.conf.j2
├── snippets/
│   ├── wordpress-cache-bypass.conf.j2
│   ├── wordpress-security.conf.j2
│   ├── ssl-params.conf.j2
│   ├── gzip-params.conf.j2
│   └── static-assets.conf.j2
└── sites-available/
    └── wordpress.conf.j2
```

### Task Updates

```yaml
# Deploy global configuration files
- name: Nginx WordPress | Configure | Deploy FastCGI cache config
  ansible.builtin.template:
    src: conf.d/fastcgi-cache.conf.j2
    dest: /etc/nginx/conf.d/fastcgi-cache.conf
    owner: root
    group: root
    mode: '0644'

- name: Nginx WordPress | Configure | Deploy rate limiting config
  ansible.builtin.template:
    src: conf.d/rate-limits.conf.j2
    dest: /etc/nginx/conf.d/rate-limits.conf

# Deploy reusable snippets
- name: Nginx WordPress | Configure | Deploy WordPress cache bypass snippet
  ansible.builtin.template:
    src: snippets/wordpress-cache-bypass.conf.j2
    dest: /etc/nginx/snippets/wordpress-cache-bypass.conf

# Deploy main site configuration
- name: Nginx WordPress | Configure | Deploy WordPress site config
  ansible.builtin.template:
    src: sites-available/wordpress.conf.j2
    dest: /etc/nginx/sites-available/wordpress.conf
  notify: reload nginx
```

### Variables for Feature Toggle

```yaml
# defaults/main.yml
nginx_wordpress_enable_cloudflare_real_ip: true
nginx_wordpress_enable_rate_limiting: true
nginx_wordpress_enable_fastcgi_cache: true
nginx_wordpress_enable_security_headers: true
```

---

## Migration Strategy

### Phase 1: Create Modular Files
1. Create directory structure in `ansible/roles/nginx_wordpress/templates/`
2. Split `nginx-wordpress-optimized.conf.j2` into modular files
3. Add Jinja2 conditionals for feature toggles

### Phase 2: Update Tasks
1. Update `configure.yml` to deploy modular files
2. Add validation tasks
3. Test on staging server

### Phase 3: Documentation
1. Update deployment guide
2. Add comments to each modular file
3. Create troubleshooting guide

---

## Example: Grafana/Prometheus Reuse

**Current**: Each has separate SSL/gzip configuration (duplicated)

**Modular**: Both reuse common snippets

```nginx
# /etc/nginx/sites-available/grafana.conf
server {
    listen 443 ssl http2;
    server_name grafana.example.com;

    # Reuse SSL configuration
    include snippets/ssl-params.conf;

    # Reuse gzip configuration
    include snippets/gzip-params.conf;

    # Grafana-specific proxy settings
    location / {
        proxy_pass http://localhost:3000;
    }
}
```

**Benefit**: One SSL update applies to WordPress, Grafana, Prometheus

---

## Complexity Trade-off

**Advantages**:
- **Simpler** individual files (single responsibility)
- **Easier** to understand each component
- **Faster** to locate and fix issues
- **Reusable** across multiple sites

**Disadvantages**:
- **More files** to manage (10 files vs 1 file)
- **Include** statements add indirection
- **Learning curve** for understanding file structure

**Verdict**: Complexity is **reduced** overall because:
- Each file is simple and focused
- No need to read 460 lines to find one setting
- Changes are isolated (no risk of breaking unrelated features)

---

## Next Steps

1. **Create modular template files** in correct directory structure
2. **Update Ansible tasks** to deploy modular files
3. **Test on staging server** (x86 or ARM)
4. **Validate** configuration with `nginx -t`
5. **Benchmark** to ensure no performance regression
6. **Document** the modular structure for future reference

---

**Status**: Ready to implement
**Estimated Time**: 2-3 hours for creation + testing
**Risk**: Low (can keep monolithic config as backup)
