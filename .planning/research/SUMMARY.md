# Research Summary: Two Minds Trading Dual-WordPress Rebuild

**Synthesized:** 2026-03-28
**Sources:** STACK.md, ARCHITECTURE.md, FEATURES.md, PITFALLS.md

---

## Critical Findings

Things that change the initial plan:

- **FastCGI cache paths MUST be separate per vhost.** The initial plan assumed a shared `fastcgi_cache_path` is safe. It is not. `nginx-helper`'s "Purge All" does a recursive filesystem delete with no domain filtering — purging on academy wipes the main site cache and vice versa. The `fastcgi_cache_path` directive and zone name must be parameterized with `{{ nginx_wordpress_site_name }}` and moved into the vhost template (not `conf.d/`). This changes 5 files in the role, not 4.

- **Valkey requires per-site DB + prefix or you will get key collisions.** Both sites default to DB 0 with prefix `wp_`. This will cause random wrong-site content to be served from object cache. Set site main to DB 0 / `wp_main_`, academy to DB 1 / `wp_academy_`. Also raise `valkey_maxmemory` to 512MB.

- **WooCommerce HPOS may not be compatible with the LearnDash WooCommerce Integration plugin.** HPOS became the default in WooCommerce 8.2+. The LearnDash bridge had partial support as of late 2024. Check WP Admin → WooCommerce → Settings → Advanced → Features before going live. If the bridge flags a warning, disable HPOS.

- **Elementor must be fully removed, not just deactivated.** Deactivating leaves `_elementor_data` and `_elementor_css` in the database and `/wp-content/uploads/elementor/` on disk. These must be explicitly cleaned up. Elementor adds ~400KB of blocking JS/CSS — removing it is the single largest LCP improvement.

- **`conf.d/fastcgi-cache.conf.j2` must be modified** — the global `fastcgi_cache_path` line must be removed from it (moved into `wordpress.conf.j2`). The file still exists but no longer contains the cache path directive.

---

## Confirmed Decisions

Things the initial plan got right:

- **WooCommerce and LearnDash both on academy only (Pattern A).** This is confirmed as the correct architecture. No cross-site sync, no webhook complexity. The main site has no user accounts, no WooCommerce, CTA buttons are plain links.

- **`include_role` x2 approach is sound.** No `allow_duplicates` needed in `meta/main.yml`. Each `include_role` call gets its own variable scope. Handlers deduplicate by name — one `restart php-fpm` fires once for both pools, which is correct behavior.

- **MariaDB isolation per-site is correct.** Separate databases (`wordpress_main`, `wordpress_academy`) and separate DB users (`wp_main`, `wp_academy`). A compromised plugin on one site cannot touch the other's data.

- **Kadence + LearnDash has no material conflicts.** LearnDash's shortcodes and blocks do not conflict with Kadence Blocks. Set LearnDash course pages to a no-sidebar layout.

- **Kadence Free is sufficient.** No performance difference vs Kadence Pro. Pro adds palette presets and extra block types — none affect Core Web Vitals.

- **Do not install Elementor alongside Kadence Blocks.** Even when inactive, Elementor fires `wp_enqueue_scripts` hooks that conflict with Kadence's asset loading.

- **WP-cron must be replaced with a real cron job.** On a low-traffic Nginx + PHP-FPM setup, WP-cron will not fire reliably. Disable it in `wp-config.php` and add a system cron entry for each site.

- **UpdraftPlus Free + Hetzner Object Storage is the correct backup path.** DB daily / files weekly. Must verify the Hetzner Object Storage S3-compatible endpoint works with UpdraftPlus.

- **Fail2ban must watch both Nginx log files.** Either two separate jails or a wildcard `logpath = /var/log/nginx/*-access.log`.

---

## Plugin Stack

### twomindstrading.com (marketing site — no accounts, no WooCommerce)

| Plugin | Purpose |
|--------|---------|
| Kadence Theme | Theme |
| Kadence Blocks | Block builder |
| Kadence Starter Templates | One-time import only — deactivate after |
| Rank Math (or Yoast SEO) | SEO meta + sitemap — pick one |
| WP 2FA | Admin security |
| Nginx Helper | FastCGI cache purge |
| Redis Object Cache | Valkey integration |
| UpdraftPlus Free | Backups to Hetzner Object Storage |

Do NOT install: WooCommerce, Elementor, WP Rocket, LiteSpeed Cache, Jetpack, contact form plugins (use a mailto link or Tally embed).

### academy.twomindstrading.com (LMS + shop)

| Plugin | Purpose |
|--------|---------|
| Kadence Theme | Theme |
| Kadence Blocks | Block builder |
| LearnDash LMS Pro | Core LMS (already licensed) |
| LearnDash Course Grid | Course catalog |
| WooCommerce 9.x | Payments + checkout |
| LearnDash WooCommerce Integration | Purchase → enrollment bridge |
| WooCommerce Stripe Gateway | Payment processor |
| WP 2FA | Admin security |
| Nginx Helper | FastCGI cache purge |
| Redis Object Cache | Valkey integration |
| UpdraftPlus Free | Backups to Hetzner Object Storage |
| WP Activity Log (or Simple History) | Audit trail — install before any third-party admin access |

---

## Key Gotchas

1. **LearnDash + Redis user meta staleness.** LearnDash writes quiz results and course progress to `wp_usermeta`. Redis Object Cache caches those reads. A user can complete a quiz and immediately see stale "not attempted" status. Test this explicitly with Valkey active. The fix is selective cache group exclusions for `user_meta` and `sfwd-*` key groups in the Redis Object Cache config.

2. **FastCGI cache cross-site wipe via nginx-helper.** Already covered in Critical Findings, but worth repeating: if the cache paths are shared when the second site goes live, every "Purge All" on either site drops both caches. This will happen silently on every post save if nginx-helper is set to purge on publish.

3. **WooCommerce checkout pages must bypass FastCGI cache.** `nginx_wordpress_woocommerce_enabled` is `false` by default in the role. Set it to `true` for the academy vhost. Paths: `/cart/`, `/checkout/`, `/my-account/`. Cookies: `woocommerce_*`, `wordpress_logged_in_*`.

4. **Kadence compiled CSS is stored in post meta and cached by Valkey.** After any global Kadence style update, stale compiled CSS can be served. Run `wp cache flush` or clear from WP Admin → Redis after theme changes. This will surprise you during initial theme setup.

5. **OpenBao unsealed state is lost on every reboot.** The transit instance (8201) must be manually unsealed with 3 of 5 key shares before the primary (8200) can auto-unseal. This is already documented in the project but is directly relevant to the rebuild: the new sites depend on the same OpenBao instance. Any unplanned reboot = WordPress downtime on both sites until OpenBao is unsealed. An external uptime monitor with a 1-minute check interval is the minimum mitigation.

---

## Open Questions

These need explicit verification before or during execution — research could not resolve them:

1. **HPOS compatibility:** Is the current version of the LearnDash WooCommerce Integration plugin fully HPOS-compatible? Check the plugin's GitHub issues at `https://github.com/LearnDash/learndash-woocommerce/issues` before enabling WooCommerce on academy. If not confirmed, disable HPOS at setup time.

2. **Hetzner Object Storage + UpdraftPlus endpoint:** Does UpdraftPlus Free correctly accept a custom S3-compatible endpoint (Hetzner Object Storage)? Verify in a staging backup run, not in production for the first time.

3. **Does the current Nginx vhost template already have the correct WooCommerce bypass cookie patterns?** The research identifies `woocommerce_items_in_cart` and the `wp_woocommerce_session_*` randomised cookie — verify the regex in the existing `wordpress.conf.j2` covers both before enabling the academy vhost.

4. **Will LearnDash Focus Mode be used?** If yes, add `/ld-focus-mode/` to FastCGI bypass rules in the academy vhost before launch. If not, defer.

5. **`setup-openbao-rotation.yml` must be run before the rebuild is complete.** Rotation playbook has never been executed (no token files, no cron entries on the server). This is a pre-existing gap — resolve it in the same maintenance window as the rebuild to avoid compounding deferred tasks.

---

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Architecture (cache isolation, include_role, MariaDB) | HIGH | Cross-confirmed by both ARCHITECTURE.md and FEATURES.md |
| Plugin stack choices | HIGH | Kadence/LearnDash/WooCommerce stack is well-documented |
| WooCommerce HPOS compatibility | MEDIUM | Needs manual check — training data cutoff Aug 2025 |
| Redis/Valkey + LearnDash user meta | MEDIUM | Community-documented, not in official docs; must test |
| Backup (UpdraftPlus + Hetzner Object Storage) | MEDIUM-HIGH | Needs a test run to confirm endpoint compatibility |
| PHP-FPM pool sizing | MEDIUM | FEATURES.md and ARCHITECTURE.md give slightly different numbers (20/30 vs 10/20); use ARCHITECTURE.md figures (20/30) as they account for authenticated LMS sessions more conservatively |

**Overall: MEDIUM-HIGH.** Core architecture decisions are solid. Two MEDIUM items (HPOS, Redis+LearnDash) require functional testing that cannot be confirmed from static research.
