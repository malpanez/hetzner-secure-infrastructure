# Architecture Research

**Domain:** Ansible multi-instance role + Nginx/PHP-FPM dual WordPress
**Researched:** 2026-03-28

---

## include_role x2 — No `allow_duplicates` Needed

`include_role` with `vars:` is fully dynamic: each call gets its own variable scope. The deduplication that requires `allow_duplicates: true` in `meta/main.yml` only applies to the static `roles:` keyword. `include_role` bypasses that entirely.

Handlers are still deduplicated by name across both invocations — one `restart php-fpm` handler fires once at the end, covering both pools. This is correct and desired behavior.

**Conclusion: include_role x2 approach is architecturally sound. No meta changes needed.**

---

## CRITICAL: nginx-helper Purge Is Filesystem-Based, Not Domain-Isolated

From `nginx-helper` source (`class-fastcgi-purger.php`): `purge_all()` calls `unlink_recursive(RT_WP_NGINX_HELPER_CACHE_PATH, false)` — a **full recursive delete** of the configured path with no domain filtering.

This means:

- Shared `/var/cache/nginx/wordpress` → "Purge All" on academy wipes main site cache, and vice versa
- The nginx cache zone itself (`keys_zone`) can be shared safely — `$host` in the cache key prevents cache hits colliding
- But the **filesystem directory** MUST be separate per site

**Required change to the role (affects initial plan):**

The `fastcgi_cache_path` directive in `conf.d/fastcgi-cache.conf.j2` **cannot** be a global config file anymore. It must be per-vhost or per-site. Options:

**Option A (Recommended):** Move `fastcgi_cache_path` into the vhost config (`wordpress.conf.j2`) instead of `conf.d/`. Use `{{ nginx_wordpress_site_name }}` in both the path and zone name:

```nginx
fastcgi_cache_path /var/cache/nginx/{{ nginx_wordpress_site_name }}

    levels=1:2 keys_zone={{ nginx_wordpress_site_name }}:100m inactive=60m max_size=1g;
```

Then in the same vhost: `fastcgi_cache {{ nginx_wordpress_site_name }};`

**Option B:** Keep `conf.d/fastcgi-cache.conf.j2` but make it a loop-generated file per instance (more complex).

Option A is simpler — move the `fastcgi_cache_path` line into `wordpress.conf.j2` (it's valid in the `http` context which is what a vhost-level include resolves into).

**Updated minimum file changes (revised from initial plan):**

1. `defaults/main.yml` — add `nginx_wordpress_site_name`
2. `tasks/configure.yml` — parameterize 4-5 paths (vhost conf, pool conf, cache dir, log names)
3. `templates/php-fpm-wordpress.conf.j2` — pool name + socket
4. `templates/sites-available/wordpress.conf.j2` — socket path + `fastcgi_cache_path` + zone name + log names
5. `templates/conf.d/fastcgi-cache.conf.j2` — either remove (move content to vhost) or leave empty on 2nd invocation

---

## PHP-FPM Sizing for 8GB RAM (Two Sites)

Budget:

- OS: ~300MB
- MariaDB (1GB buffer pool): ~1.2GB

- Nginx + Valkey + OpenBao + monitoring: ~350MB
- Available for PHP-FPM: ~6.1GB
- At ~100MB/process: 61 max workers

**Recommended pool split:**

- `main` pool: `pm.max_children = 20` (marketing site, lower concurrent users)
- `academy` pool: `pm.max_children = 30` (LMS, authenticated sessions, heavier requests)
- Total: 50 workers × 100MB = 5GB headroom

Both pools: `pm = dynamic`, adjust spare servers conservatively. Switch `academy` to `pm = ondemand` later if traffic is low and RAM pressure grows.

---

## MariaDB Isolation Pattern

Standard pattern, already in plan — confirmed correct:

```sql
GRANT ALL ON wordpress_main.* TO 'wp_main'@'localhost';
GRANT ALL ON wordpress_academy.* TO 'wp_academy'@'localhost';
```

A compromised plugin on one site cannot read or write the other site's database. This is the most important isolation measure at the application layer.

---

## AppArmor Multi-Webroot Pattern

AppArmor glob behavior:

- `*` — matches any characters except `/`
- `**` — matches any characters including `/`

`/var/www/*/` covers both `/var/www/twomindstrading.com/` and `/var/www/academy.twomindstrading.com/` correctly.

**Current state:** No nginx/PHP-FPM AppArmor profiles exist in this repo. This is a future hardening concern — not a blocker for the role refactor. The existing OS-level AppArmor profiles are not affected by this change.

---

## Fail2ban Multi-Vhost Pattern

Fail2ban WordPress jails must monitor both Nginx log files. Pattern:

```ini
[nginx-wordpress-main]
logpath = /var/log/nginx/main-access.log


[nginx-wordpress-academy]
logpath = /var/log/nginx/academy-access.log
```

If both jails share the same `findtime`/`maxretry`/`bantime` filter, a single jail with a wildcard logpath works:

```ini
logpath = /var/log/nginx/*-access.log
```

Test with `fail2ban-client status` after changes.

---

## Summary: Minimum File Changes (Updated)

The initial plan listed 4 files. The FastCGI cache discovery adds one more:

| File | Change |
|------|--------|
| `defaults/main.yml` | Add `nginx_wordpress_site_name: "wordpress"` |
| `tasks/configure.yml` | Parameterize vhost conf, pool conf, cache dir, log names |
| `templates/php-fpm-wordpress.conf.j2` | Pool name + socket path |
| `templates/sites-available/wordpress.conf.j2` | Socket path + `fastcgi_cache_path` + zone name + log names |
| `templates/conf.d/fastcgi-cache.conf.j2` | Remove global `fastcgi_cache_path` (moved to vhost) |
