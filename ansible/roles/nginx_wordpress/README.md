# nginx_wordpress

Deploys a hardened nginx + PHP-FPM + WordPress stack on Debian:

- **nginx from the official nginx.org repo** with a modular config layout
  (`conf.d/` globals + reusable `snippets/`), version-pinned.
- **FastCGI page cache** with WordPress-aware bypass rules (logged-in users,
  admin, WooCommerce/LearnDash paths) plus Valkey/Redis object cache wiring.
- **Security hardening**: rate-limited login/API endpoints, security headers,
  sensitive-file blocking, Cloudflare real-IP restoration, optional
  Let's Encrypt via DNS-01.
- **Dual-site capable**: every site gets its own PHP-FPM pool, cache zone and
  logs, keyed by `nginx_wordpress_site_name` — run the role once per site.
- **Pluggable mu-plugins**: consuming projects ship their own must-use
  plugins as files; the role deploys whatever is listed.
- **Optional media proxy**: stream a remote object-storage bucket through the
  origin so a CDN edge can sit in front of large media files.
- **WordPress provisioning via WP-CLI**: core install, themes, wordpress.org
  plugins, commercial ZIP plugins, page content, performance/SEO options and
  file-permission hardening.

## Requirements

- Debian 12/13 target.
- MariaDB/MySQL already installed (e.g. via a `mysql`/`mariadb` role) with a
  database and user for WordPress.
- Optional: Valkey/Redis for the object cache, Grafana/Prometheus if the
  monitoring reverse proxies are enabled.

## Main variables

See `defaults/main.yml` for the full list.

| Variable | Default | Purpose |
|---|---|---|
| `nginx_wordpress_site_name` | `wordpress` | Per-site key for PHP-FPM pool, cache zone, logs |
| `nginx_wordpress_server_name` | `example.com` | Primary vhost name |
| `nginx_wordpress_server_aliases` | `[www.example.com]` | Extra server names |
| `nginx_wordpress_web_root` | `/var/www/wordpress` | Document root |
| `nginx_wordpress_db_name` / `_db_user` / `_db_password` | — | Database connection (password must be provided) |
| `nginx_wordpress_auth_key` … `_nonce_salt` | `""` | WordPress salts (generate and provide) |
| `nginx_wordpress_enable_fastcgi_cache` | `true` | FastCGI page caching |
| `nginx_wordpress_enable_rate_limiting` | `true` | Login/API rate limits |
| `nginx_wordpress_cloudflare_enabled` | `true` | Real client IP from CDN headers |
| `nginx_wordpress_letsencrypt_enabled` | `false` | DNS-01 certificates via Cloudflare |
| `nginx_wordpress_plugins_mandatory` / `_operations` / `_design` / `_forms` / `_accessibility` | see defaults | wordpress.org plugin groups |
| `nginx_wordpress_plugins_zip` | `[]` | Commercial plugin ZIPs (`{name, file}`) from `files/plugins/` |
| `nginx_wordpress_mu_plugins_shared` | `[force-gd.php]` | Must-use plugins for all sites |
| `nginx_wordpress_mu_plugins` | `[]` | Per-site must-use plugins (paths under the playbook's `files/`) |
| `nginx_wordpress_protected_dir` | `""` | Directory outside the docroot served via an authenticated endpoint |
| `nginx_wordpress_protected_uploads_regex` | `""` | Deny direct access to matching uploads |
| `nginx_wordpress_media_proxy_path` / `_upstream` / `_host_header` | `""` | Proxy a remote object-storage bucket through this origin |
| `nginx_wordpress_content_pages` | `[]` | Page content (`{slug}`) deployed from `files/pages/<slug>.html` |
| `nginx_wordpress_monitoring_proxy_enabled` | `true` | Grafana/Prometheus reverse proxies |
| `nginx_wordpress_monitoring_domain` | falls back to `server_name` | Domain for `grafana.` / `prometheus.` vhosts |

## Example playbook

```yaml
- hosts: web_servers
  become: true
  roles:
    - role: nginx_wordpress
      vars:
        nginx_wordpress_site_name: blog
        nginx_wordpress_server_name: example.com
        nginx_wordpress_server_aliases:
          - www.example.com
        nginx_wordpress_web_root: /var/www/blog
        nginx_wordpress_db_name: blog
        nginx_wordpress_db_user: blog
        nginx_wordpress_db_password: "{{ vault_wordpress_db_password }}"
        nginx_wordpress_mu_plugins:
          - blog/maintenance-banner.php   # from the playbook's files/ dir
        nginx_wordpress_media_proxy_path: "/media/"
        nginx_wordpress_media_proxy_upstream: "https://s3.example-objectstorage.com/my-bucket/"
        nginx_wordpress_media_proxy_host_header: "s3.example-objectstorage.com"
```

## Testing

```bash
cd ansible/roles/nginx_wordpress
molecule test
```

## License

MIT
