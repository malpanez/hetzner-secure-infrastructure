# Nginx WordPress Role

Ansible role to deploy and configure Nginx optimized for WordPress + Tutor LMS with best practices for performance, security, and scalability.

## Features

### Performance
- ✅ FastCGI caching with smart cache bypass
- ✅ Gzip + Brotli compression
- ✅ Open file cache
- ✅ HTTP/2 and HTTP/3 support
- ✅ Static asset caching (30 days)
- ✅ PHP OPcache optimization
- ✅ Optimized buffer sizes

### Security
- ✅ TLS 1.2+ only with modern cipher suites
- ✅ HSTS with preload
- ✅ Security headers (X-Frame-Options, CSP, etc.)
- ✅ XML-RPC blocking (prevents DDoS)
- ✅ Rate limiting for wp-login.php
- ✅ Sensitive file/directory blocking
- ✅ Real IP detection from Cloudflare
- ✅ PHP function restrictions

### WordPress-Specific
- ✅ Permalink support
- ✅ wp-admin protection
- ✅ wp-cron.php disabled (use system cron)
- ✅ REST API enabled with optional rate limiting
- ✅ Multisite support (optional)

### Tutor LMS Integration
- ✅ Course content protection (requires login)
- ✅ Video streaming optimization
- ✅ Extended timeouts for large uploads
- ✅ Quiz endpoint caching bypass

## Requirements

- Debian 12+ or Debian 13 (recommended)
- Ansible 2.10+
- Root or sudo access

## Role Variables

See [defaults/main.yml](defaults/main.yml) for all variables. Key variables:

```yaml
# Domain configuration
wordpress_domain: "example.com"
wordpress_root: "/var/www/example.com"

# PHP settings
php_version: "8.3"  # PHP 8.3 recommended
php_memory_limit: "256M"
php_upload_max_filesize: "100M"

# Caching
nginx_fastcgi_cache_enabled: true
nginx_fastcgi_cache_size: "256m"

# Security
nginx_ssl_enabled: true
nginx_hsts_enabled: true
nginx_rate_limit_enabled: true

# Cloudflare
cloudflare_enabled: true

# Tutor LMS
tutor_lms_enabled: true
tutor_course_protection_enabled: true
```

## Dependencies

None. This role installs all required packages.

## Example Playbook

### Basic Usage

```yaml
- hosts: wordpress_servers
  become: yes
  vars:
    wordpress_domain: "tradingcourse.com"
    nginx_ssl_enabled: false  # Enable after getting SSL cert
  roles:
    - nginx-wordpress
```

### Production Configuration

```yaml
- hosts: wordpress_prod
  become: yes
  vars:
    # Domain
    wordpress_domain: "tradingcourse.com"
    wordpress_root: "/var/www/tradingcourse.com"

    # PHP
    php_version: "8.3"
    php_memory_limit: "512M"  # Increase for large sites
    php_upload_max_filesize: "200M"  # For course videos

    # Performance
    nginx_fastcgi_cache_enabled: true
    nginx_fastcgi_cache_size: "512m"  # Larger cache
    nginx_worker_processes: "auto"
    nginx_worker_connections: 4096

    # Security
    nginx_ssl_enabled: true
    nginx_ssl_certificate: "/etc/letsencrypt/live/tradingcourse.com/fullchain.pem"
    nginx_ssl_certificate_key: "/etc/letsencrypt/live/tradingcourse.com/privkey.pem"
    nginx_hsts_enabled: true
    nginx_security_headers_enabled: true

    # Rate limiting (strict for production)
    nginx_rate_limit_enabled: true
    nginx_rate_limit_rate: "3r/m"  # 3 login attempts per minute

    # Cloudflare
    cloudflare_enabled: true

    # Tutor LMS
    tutor_lms_enabled: true
    tutor_course_protection_enabled: true
    tutor_fastcgi_read_timeout: 600  # 10 min for large video uploads

  roles:
    - nginx-wordpress

  post_tasks:
    - name: Get SSL certificate
      command: >
        certbot --nginx
        -d {{ wordpress_domain }}
        -d www.{{ wordpress_domain }}
        --non-interactive
        --agree-tos
        -m admin@{{ wordpress_domain }}
      args:
        creates: "/etc/letsencrypt/live/{{ wordpress_domain }}/fullchain.pem"
```

## Post-Installation

### 1. Obtain SSL Certificate

```bash
sudo certbot --nginx -d example.com -d www.example.com
```

### 2. Install WordPress

```bash
# Download WordPress
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xzf latest.tar.gz
sudo cp -r wordpress/* /var/www/example.com/
sudo chown -R www-data:www-data /var/www/example.com

# Create database
sudo mysql
CREATE DATABASE wordpress CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER 'wordpress'@'localhost' IDENTIFIED BY 'strong_password_here';
GRANT ALL ON wordpress.* TO 'wordpress'@'localhost';
FLUSH PRIVILEGES;
EXIT;

# Complete WordPress installation
# Visit: https://example.com/wp-admin/install.php
```

### 3. Install Recommended Plugins

```bash
# Via WP-CLI (if installed)
wp plugin install wordfence --activate
wp plugin install wp-rocket --activate
wp plugin install learndash  # or tutor
```

### 4. Configure System Cron (Disable wp-cron.php)

```bash
# Edit wp-config.php
echo "define('DISABLE_WP_CRON', true);" | sudo tee -a /var/www/example.com/wp-config.php

# Add to system crontab
echo "*/15 * * * * www-data cd /var/www/example.com && /usr/bin/php /var/www/example.com/wp-cron.php > /dev/null 2>&1" | sudo tee -a /etc/crontab
```

### 5. Test Configuration

```bash
# Test Nginx config
sudo nginx -t

# Reload Nginx
sudo systemctl reload nginx

# Check PHP-FPM status
sudo systemctl status php8.3-fpm

# View logs
sudo tail -f /var/log/nginx/tradingcourse.com_access.log
sudo tail -f /var/log/nginx/tradingcourse.com_error.log
```

## Performance Tuning

### Cache Purging

Manually purge FastCGI cache:

```bash
# Purge entire cache
sudo rm -rf /var/cache/nginx/fastcgi/*
sudo systemctl reload nginx

# Purge specific URL
curl -X PURGE https://example.com/page-name/
```

### Monitoring

Check cache hit rate:

```bash
# Access logs show cache status
grep "X-FastCGI-Cache" /var/log/nginx/example.com_access.log | grep "HIT" | wc -l
grep "X-FastCGI-Cache" /var/log/nginx/example.com_access.log | grep "MISS" | wc -l
```

PHP-FPM status:

```bash
# Enable status page in site config, then:
curl http://localhost/php-fpm-status
```

## Troubleshooting

### Issue: 502 Bad Gateway

**Cause**: PHP-FPM not running or socket issue

**Solution**:
```bash
sudo systemctl status php8.3-fpm
sudo systemctl restart php8.3-fpm
sudo tail -f /var/log/php8.3-fpm.log
```

### Issue: Slow uploads

**Cause**: Small PHP limits

**Solution**: Increase in variables:
```yaml
php_upload_max_filesize: "500M"
php_post_max_size: "500M"
php_max_execution_time: "600"
```

### Issue: Cache not working

**Cause**: Cookie bypass rules

**Solution**: Check if logged in. Log out to see cached version.

### Issue: 413 Request Entity Too Large

**Cause**: Nginx client_max_body_size too small

**Solution**:
```yaml
nginx_client_max_body_size: "200M"
```

## Security Hardening

### Restrict wp-admin by IP

Edit `templates/wordpress.conf.j2`:

```nginx
location ~* ^/wp-admin/(?!admin-ajax\.php) {
    allow 203.0.113.50;  # Your IP
    deny all;
    # ...rest of config
}
```

### Enable Content Security Policy

```yaml
nginx_csp_enabled: true
nginx_csp_policy: "default-src 'self'; script-src 'self' 'unsafe-inline';"
```

**Warning**: May break WordPress admin. Test thoroughly.

### Hide server info

Already configured:
```nginx
server_tokens off;  # Hides Nginx version
expose_php = Off    # Hides PHP version
```

## Cloudflare Integration

This role automatically configures:

1. **Real IP detection** from Cloudflare headers
2. **IP allowlist** for Cloudflare IP ranges

### Restrict HTTP/HTTPS to Cloudflare Only

Use UFW:

```bash
# Allow Cloudflare IPv4 ranges
for ip in 173.245.48.0/20 103.21.244.0/22 103.22.200.0/22; do
  sudo ufw allow from $ip to any port 80,443 proto tcp
done

# Block all other HTTP/HTTPS
sudo ufw deny 80/tcp
sudo ufw deny 443/tcp
```

## Monitoring Integration

### Prometheus Node Exporter

Check Nginx metrics:

```bash
curl http://localhost:9100/metrics | grep nginx
```

### Grafana Dashboard

Import dashboard ID: 12708 (Nginx + PHP-FPM)

## Backup Recommendations

### What to Backup

1. WordPress files: `/var/www/example.com/`
2. Database: MySQL dumps
3. Nginx config: `/etc/nginx/sites-available/`
4. PHP config: `/etc/php/8.3/fpm/`

### Automated Backup Script

```bash
#!/bin/bash
BACKUP_DIR="/backup"
DATE=$(date +%Y%m%d)

# Backup WordPress files
tar -czf $BACKUP_DIR/wordpress-$DATE.tar.gz /var/www/example.com

# Backup database
mysqldump -u wordpress -p wordpress > $BACKUP_DIR/db-$DATE.sql

# Keep only last 7 days
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete
find $BACKUP_DIR -name "*.sql" -mtime +7 -delete
```

## Tags

Run specific parts:

```bash
# Only Nginx configuration
ansible-playbook playbook.yml --tags nginx

# Only PHP configuration
ansible-playbook playbook.yml --tags php

# Only SSL setup
ansible-playbook playbook.yml --tags ssl

# Skip cache setup
ansible-playbook playbook.yml --skip-tags cache
```

## License

Part of the Hetzner Secure Infrastructure project.

## Author

Generated as part of the TOP 0.01% infrastructure transformation.

## Support

For issues, see [TROUBLESHOOTING.md](../../docs/TROUBLESHOOTING.md)
