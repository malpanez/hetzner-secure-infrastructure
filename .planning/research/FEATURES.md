# Features & Performance Research

**Domain:** WordPress dual-site performance optimization
**Researched:** 2026-03-28

---

## CRITICAL: FastCGI Cache Must Be Separated Per Vhost

**Risk:** With a single `fastcgi_cache_path` and zone name `wordpress`, the `nginx-helper` plugin "purge all" from site A **deletes site B's cache entirely**. This will cause random full-cache misses on the other site on every post save.

**Fix required before second site goes live:**

- Separate `fastcgi_cache_path` per vhost: `/var/cache/nginx/site-main` and `/var/cache/nginx/site-academy`
- Separate zone names: `wp_main` and `wp_academy`
- Update `conf.d/fastcgi-cache.conf.j2` to use `{{ nginx_wordpress_site_name }}` in the zone name
- Update `wordpress.conf.j2` to reference the per-site zone: `fastcgi_cache {{ nginx_wordpress_site_name }};`

This means the "shared FastCGI cache zone" assumption from the initial plan is **WRONG** — the zones must be separate to prevent cross-site cache purging.

---

## CRITICAL: Valkey Dual-Site Isolation

**Risk:** Both sites will default to `WP_REDIS_DATABASE = 0` with prefix `wp_`. Key collisions will cause random serving of wrong-site cached content.

**Fix:**

- Site main: DB 0, prefix `wp_main_`
- Site academy: DB 1, prefix `wp_academy_`
- Increase `valkey_maxmemory` from 256MB to 512MB (two active sites on 8GB RAM — plenty of headroom)

Set in `wp-config.php` per site:

```php
define('WP_REDIS_DATABASE', 0);  // or 1 for academy
define('WP_REDIS_PREFIX', 'wp_main_');  // or 'wp_academy_'
```

---

## HIGH: LearnDash FastCGI Bypass Gaps

Current config misses these patterns (must be added to bypass rules):

- `/ld-focus-mode/` — LearnDash 4.x Focus Mode (authenticated UX)
- `/learndash-checkout/` — LD native checkout (if not using WooCommerce)
- Verify `/wp-json/` REST API bypass is present in the academy vhost

Without these, LearnDash authenticated pages may be served cached to unauthenticated users.

---

## HIGH: WooCommerce FastCGI Bypass

The template has WooCommerce bypass rules **disabled** by default (`nginx_wordpress_woocommerce_enabled: false`).

For the academy site, enable this variable. The cookie patterns (`woocommerce_` prefix regex) already handle the randomised `wp_woocommerce_session_*` cookie name correctly.

Paths that must bypass cache for academy:

- `/cart/`, `/checkout/`, `/my-account/`, `/shop/` (if used)
- Any page with `woocommerce_items_in_cart` cookie set

---

## Elementor Removal

**Deactivating Elementor is NOT sufficient.** Residual CSS/JS files remain in the database and file system. Required steps:

1. Deactivate and uninstall Elementor and all Elementor add-ons
2. Run `wp post meta delete` cleanup for Elementor post meta (`_elementor_data`, `_elementor_css`)
3. Delete `/wp-content/uploads/elementor/` directory
4. Rebuild all pages in Kadence Blocks from scratch

This is the single largest LCP improvement — Elementor adds ~400KB of blocking JS/CSS. After removal + Kadence, target LCP <2s on mobile is achievable.

---

## Performance: Kadence Free vs Pro

**Kadence Free is sufficient for performance.** Kadence Pro adds:

- Global color palette presets
- Additional block types (Lottie, Countdown, etc.)
- Header/footer builder advanced options

**None of these affect LCP or Core Web Vitals.** The performance difference is zero.

**Biggest quick win after Elementor removal:** Self-host Google Fonts. Kadence defaults to loading from `fonts.googleapis.com`, adding 200-600ms on mobile cold load. Set in Kadence settings: Appearance → Customizer → General → Typography → "Local" font loading.

---

## PHP-FPM Pool Sizing for Two Sites on 8GB RAM

Recommended distribution:

- Site main (lower traffic, marketing): 10 max_children, `pm = dynamic`, 2-4 spare
- Site academy (LMS, authenticated users): 20 max_children, `pm = dynamic`, 4-8 spare
- Total: 30 workers × ~65MB each = ~1.95GB PHP-FPM overhead
- Remaining for OS + MariaDB + Valkey + OpenBao: ~6GB — comfortable

For the long term when academy traffic grows: switch academy to `pm = ondemand` to reclaim idle RAM.

---

## Roadmap Implications

**Must-do before launch (Phase 1):**

- [ ] Separate FastCGI cache paths + zone names per vhost
- [ ] Set per-site Valkey DB + prefix in wp-config.php template
- [ ] Increase `valkey_maxmemory` to 512MB
- [ ] Add `/ld-focus-mode/` to bypass rules in `wordpress.conf.j2`
- [ ] Enable `nginx_wordpress_woocommerce_enabled: true` for academy vhost
- [ ] Self-host fonts in Kadence settings post-deploy

**Post-baseline (Phase 2, after LCP confirmed <2s):**

- [ ] Separate PHP-FPM pool sizes per site (main: smaller, academy: larger)
- [ ] Hero image WebP + `fetchpriority="high"` on LCP image via Kadence block settings
- [ ] Cloudflare Cache Rules for `/courses/*` bypass (prevent logged-in content leak)

---

## Open Questions

1. Will LearnDash Focus Mode be used? (Determines if `/ld-focus-mode/` bypass is urgent)
2. `nginx-helper` configured for "purge by URL" or "purge all"? (If "purge all" + shared cache path = cross-site wipe)
