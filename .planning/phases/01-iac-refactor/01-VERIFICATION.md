---
phase: 01-iac-refactor
verified: 2026-03-28T00:00:00Z
status: passed
score: 16/16 requirements verified
re_verification: false
human_verification:
  - test: "Run ansible-playbook dual-wordpress.yml against a live wordpress_servers inventory"
    expected: "Both sites deploy without errors; PHP-FPM creates two separate pool sockets"
    why_human: "Requires a live Hetzner server with valid vault secrets — cannot test without network/server access"
  - test: "Verify nginx -t passes after dual deployment produces main.conf and academy.conf in sites-available"
    expected: "Two independent vhost files with separate fastcgi_cache_path zones; nginx reload succeeds"
    why_human: "Requires a running nginx instance with both config files present"
  - test: "Confirm WooCommerce cart/checkout are not cached on academy site"
    expected: "Requests to /cart/, /checkout/, /my-account/ return Cache-Status: BYPASS"
    why_human: "Requires a live nginx + PHP-FPM + WooCommerce installation"
---

# Phase 01: IaC Refactor Verification Report

**Phase Goal:** The nginx_wordpress role and dual-wordpress.yml playbook are ready to deploy two independent WordPress sites, with correct cache isolation, per-site PHP-FPM pools, Valkey DB separation, and academy-specific bypass rules.
**Verified:** 2026-03-28
**Status:** PASSED
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Two include_role invocations with different site_name values produce separate PHP-FPM pools, vhost configs, log files, and cache directories | VERIFIED | configure.yml lines 24, 143, 152-153, 195 all use `{{ nginx_wordpress_site_name }}`; dual-wordpress.yml has 2 include_role calls with site_name=main and site_name=academy |
| 2 | fastcgi_cache_path is per-vhost (inside wordpress.conf.j2), not global | VERIFIED | fastcgi-cache.conf.j2 has 0 matches for fastcgi_cache_path; wordpress.conf.j2 line 18 has parametrized `fastcgi_cache_path /var/cache/nginx/{{ nginx_wordpress_site_name }}` |
| 3 | LearnDash bypass rules render conditionally when learndash_enabled is true | VERIFIED | wordpress.conf.j2 lines 189-201: `{% if nginx_wordpress_learndash_enabled %}` wraps location block for `/(ld-focus-mode|learndash-checkout)/` |
| 4 | WooCommerce bypass rules render conditionally when woocommerce_enabled is true | VERIFIED | wordpress-cache-bypass.conf.j2 wraps `/cart/|/checkout/|/my-account/|/wc-api/` in `{% if nginx_wordpress_woocommerce_enabled %}`; academy invocation passes `true` |
| 5 | Default value nginx_wordpress_site_name=wordpress preserves backward compatibility | VERIFIED | defaults/main.yml line 26: `nginx_wordpress_site_name: "wordpress"` |
| 6 | nginx_wordpress_php_version defaults to 8.3 | VERIFIED | defaults/main.yml line 68: `nginx_wordpress_php_version: "8.3"` |
| 7 | dual-wordpress.yml creates two MariaDB databases with no cross-access | VERIFIED | mysql_databases has wordpress_main + wordpress_academy; mysql_users has wp_main (priv: wordpress_main.*:ALL) and wp_academy (priv: wordpress_academy.*:ALL) |
| 8 | Main site: site_name=main, learndash=false, woocommerce=false, redis_db=0 | VERIFIED | dual-wordpress.yml lines 38, 50-52: confirmed |
| 9 | Academy: site_name=academy, learndash=true, woocommerce=true, letsencrypt=false, redis_db=1 | VERIFIED | dual-wordpress.yml lines 68, 79-83: confirmed |
| 10 | PHP-FPM pool sizes differ: main=20, academy=30 | VERIFIED | dual-wordpress.yml lines 46 and 75: `nginx_wordpress_php_fpm_max_children: 20` and `30` |
| 11 | wp-config.php.j2 renders WP_REDIS_DATABASE and WP_REDIS_PREFIX per invocation | VERIFIED | wp-config.php.j2 lines 32-33: `define('WP_REDIS_DATABASE', {{ nginx_wordpress_redis_database | default(0) }})` and `WP_REDIS_PREFIX` driven by variables |
| 12 | Terraform plan shows cloudflare_record.academy resource | VERIFIED | dns.tf lines 63-72: properly formatted academy A record pointing to var.server_ipv4, proxied=true |

**Score:** 12/12 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ansible/roles/nginx_wordpress/defaults/main.yml` | nginx_wordpress_site_name default variable | VERIFIED | Line 26: `nginx_wordpress_site_name: "wordpress"`. Also contains redis_database=0, redis_prefix="wp_" |
| `ansible/roles/nginx_wordpress/tasks/configure.yml` | Parametrized task paths using site_name | VERIFIED | 6 occurrences of `nginx_wordpress_site_name`: cache dir, vhost deploy, vhost symlink, PHP-FPM pool dest, FastCGI conf guard |
| `ansible/roles/nginx_wordpress/templates/php-fpm-wordpress.conf.j2` | Per-instance pool name and socket | VERIFIED | Line 4: `[{{ nginx_wordpress_site_name }}]`, line 8: socket path includes site_name. 2 occurrences total. |
| `ansible/roles/nginx_wordpress/templates/sites-available/wordpress.conf.j2` | Per-vhost fastcgi_cache_path, socket, logs, bypass rules | VERIFIED | 15 occurrences of site_name; fastcgi_cache_path at top; 5 socket paths; 4 log paths; 2 cache zone refs; LearnDash bypass block |
| `ansible/roles/nginx_wordpress/templates/conf.d/fastcgi-cache.conf.j2` | Global cache directives only (no fastcgi_cache_path) | VERIFIED | 0 occurrences of fastcgi_cache_path; retains fastcgi_cache_key, use_stale, lock, ignore_headers |
| `ansible/roles/nginx_wordpress/templates/wp-config.php.j2` | Per-site Redis/Valkey configuration | VERIFIED | Lines 30-34: WP_REDIS_HOST, WP_REDIS_PORT, WP_REDIS_DATABASE, WP_REDIS_PREFIX, WP_CACHE — all present, 4 WP_REDIS matches |
| `ansible/playbooks/dual-wordpress.yml` | Dual-site playbook with 2 DBs + 2 include_role calls | VERIFIED | 128 lines; 2 ansible.builtin.include_role calls; geerlingguy.mysql with 2 databases/users; valkey role; post_tasks debug |
| `ansible/inventory/group_vars/all/secrets.yml.example` | Documentation of new vault variables | VERIFIED | Lines 39-51: vault_wp_main_db_password, vault_wp_academy_db_password, 8 academy salts; `grep -c vault_wp_academy` returns 9 |
| `terraform/modules/cloudflare-config/dns.tf` | Academy subdomain A record | VERIFIED | Lines 63-72: `cloudflare_record.academy`, name="academy", content=var.server_ipv4, proxied=true, ttl=1 |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| configure.yml | wordpress.conf.j2 | template task dest uses site_name | VERIFIED | Line 143: `dest: "{{ nginx_wordpress_nginx_sites_available }}/{{ nginx_wordpress_site_name }}.conf"` |
| wordpress.conf.j2 | php-fpm-wordpress.conf.j2 | socket path `fpm-{{ nginx_wordpress_site_name }}.sock` | VERIFIED | vhost fastcgi_pass: `php{{ nginx_wordpress_php_version }}-{{ nginx_wordpress_site_name }}-fpm.sock`; pool listen matches same pattern |
| dual-wordpress.yml | nginx_wordpress/defaults/main.yml | include_role vars override defaults | VERIFIED | Both include_role blocks set nginx_wordpress_site_name explicitly (main / academy) |
| dual-wordpress.yml | geerlingguy.mysql | mysql_databases and mysql_users vars | VERIFIED | mysql_databases: [wordpress_main, wordpress_academy]; mysql_users: [wp_main priv→wordpress_main, wp_academy priv→wordpress_academy] |
| wp-config.php.j2 | defaults/main.yml | nginx_wordpress_redis_database / redis_prefix variables | VERIFIED | Template uses `{{ nginx_wordpress_redis_database | default(0) }}` and `{{ nginx_wordpress_redis_prefix | default("wp_") }}` |
| dns.tf academy resource | var.server_ipv4 | content attribute references existing variable | VERIFIED | Line 67: `content = var.server_ipv4` — same variable used by root, grafana, prometheus records |

---

### Data-Flow Trace (Level 4)

Not applicable — all artifacts are Ansible templates and Terraform config (no runtime data rendering). Correctness is structural: variables flow from playbook invocation vars → role defaults → Jinja2 templates at deploy time.

---

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| dual-wordpress.yml passes syntax check | `ansible-playbook playbooks/dual-wordpress.yml --syntax-check` (from ansible/ dir) | `playbook: playbooks/dual-wordpress.yml` — no ERROR output | PASS |
| terraform fmt passes on dns.tf | `terraform fmt -check -recursive` (from terraform/ dir) | Exit 0 | PASS |
| fastcgi_cache_path absent from conf.d | `grep -c fastcgi_cache_path templates/conf.d/fastcgi-cache.conf.j2` | 0 | PASS |
| No hardcoded wordpress socket/log paths in active vhost template | `grep 'fpm.sock' wordpress.conf.j2 \| grep -v site_name` | 0 matches | PASS |
| 15 occurrences of site_name in wordpress.conf.j2 | `grep -c nginx_wordpress_site_name wordpress.conf.j2` | 15 | PASS |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ROLE-01 | 01-01 | nginx_wordpress_site_name added to defaults/main.yml | SATISFIED | Line 26: `nginx_wordpress_site_name: "wordpress"` |
| ROLE-02 | 01-01 | configure.yml parametrized with site_name (5 paths + 1 guard) | SATISFIED | 6 occurrences; cache dir, vhost deploy, symlink, PHP-FPM dest, FastCGI guard |
| ROLE-03 | 01-01 | php-fpm-wordpress.conf.j2 pool name + socket parametrized | SATISFIED | Pool name `[{{ nginx_wordpress_site_name }}]` and socket path both use site_name |
| ROLE-04 | 01-01 | wordpress.conf.j2 parametrized: socket, cache_path, zone, logs | SATISFIED | 15 site_name occurrences; fastcgi_cache_path and keys_zone both parametrized; 4 log paths; 5 sockets |
| ROLE-05 | 01-01 | fastcgi_cache_path removed from fastcgi-cache.conf.j2 | SATISFIED | 0 matches; only global directives remain (fastcgi_cache_key, use_stale, lock, ignore_headers) |
| ROLE-06 | 01-01 | /ld-focus-mode/ and /learndash-checkout/ bypass rules added | SATISFIED | Lines 189-201 in wordpress.conf.j2 with `{% if nginx_wordpress_learndash_enabled %}` guard |
| ROLE-07 | 01-01 | nginx_wordpress_woocommerce_enabled activates bypass for academy | SATISFIED | Variable exists in defaults (false); bypass snippet has conditional block; academy invocation sets true |
| PLAY-01 | 01-02 | dual-wordpress.yml with 2 databases, 2 users, 2 include_role | SATISFIED | File exists, 128 lines; 2 DBs in mysql_databases; 2 users in mysql_users; 2 include_role calls |
| PLAY-02 | 01-02 | Main site: site_name=main, no LearnDash, no WooCommerce | SATISFIED | Lines 38, 50, 51: confirmed |
| PLAY-03 | 01-02 | Academy: site_name=academy, LearnDash+WooCommerce enabled, letsencrypt=false | SATISFIED | Lines 68, 79-81: confirmed |
| PLAY-04 | 01-02 | PHP-FPM pool sizes: main=20, academy=30 | SATISFIED | Lines 46 and 75: `nginx_wordpress_php_fpm_max_children: 20` and `30` |
| PLAY-05 | 01-02 | Vault variables added to secrets.yml.example | SATISFIED | 9 vault_wp_academy_* vars + vault_wp_main_db_password = 10 new variables documented |
| WP-01 | 01-03 | wp-config.php.j2 accepts WP_REDIS_DATABASE and WP_REDIS_PREFIX | SATISFIED | Lines 32-33: both defines use role variables with defaults |
| WP-02 | 01-03 | Main site: redis_db=0, prefix=wp_main_ | SATISFIED | dual-wordpress.yml lines 52-53: `nginx_wordpress_redis_database: 0`, `redis_prefix: "wp_main_"` |
| WP-03 | 01-03 | Academy site: redis_db=1, prefix=wp_academy_ | SATISFIED | dual-wordpress.yml lines 82-83: `nginx_wordpress_redis_database: 1`, `redis_prefix: "wp_academy_"` |
| TF-01 | 01-04 | DNS A record academy.twomindstrading.com in dns.tf | SATISFIED | dns.tf lines 63-72: cloudflare_record.academy, type=A, proxied=true, content=var.server_ipv4 |

**All 16 Phase 1 requirements satisfied. No orphaned requirements detected.**

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `ansible/roles/nginx_wordpress/templates/nginx-wordpress.conf.j2` | 5, 36-37, 131-132 | Hardcoded `nginx/wordpress` cache path and log paths | Info | Legacy template — NOT referenced by any task in tasks/. Dead file, no deployment impact. |
| `ansible/roles/nginx_wordpress/templates/nginx-wordpress-optimized.conf.j2` | 17, 107-108, 359-360 | Hardcoded `nginx/wordpress` paths | Info | Legacy template — NOT referenced by any task in tasks/. Dead file, no deployment impact. |
| `ansible/roles/nginx_wordpress/templates/sites-available/wordpress.conf.j2` | 189 | LearnDash bypass block only in SSL server block (not in HTTP block) | Info | HTTP block is used only in pre-SSL or Molecule test scenarios. Production runs with SSL enabled. For Molecule tests with `nginx_wordpress_ssl_enabled: false`, ld-focus-mode bypass will not be active. |

None of these are blockers. The two legacy template files (`nginx-wordpress.conf.j2`, `nginx-wordpress-optimized.conf.j2`) contain hardcoded strings but are unreferenced by any Ansible task and do not affect deployments.

---

### Human Verification Required

#### 1. Live Dual Deployment

**Test:** Run `ansible-playbook playbooks/dual-wordpress.yml` against the production wordpress_servers host with populated vault secrets.
**Expected:** PHP-FPM creates `/run/php/php8.3-main-fpm.sock` and `/run/php/php8.3-academy-fpm.sock`; nginx serves both vhosts; sites-available contains `main.conf` and `academy.conf`.
**Why human:** Requires live Hetzner server with valid vault credentials and Hetzner API token. Cannot test without network access to the server.

#### 2. Cache Isolation Verification

**Test:** Send requests to `https://twomindstrading.com` and `https://academy.twomindstrading.com` and inspect `X-FastCGI-Cache` headers; then verify `/var/cache/nginx/main/` and `/var/cache/nginx/academy/` are populated independently.
**Expected:** Cache misses on one site do not affect the other; cache directories are isolated.
**Why human:** Requires running nginx + WordPress + FastCGI on live server.

#### 3. WooCommerce Cart Bypass (Academy)

**Test:** Add a product to cart on `academy.twomindstrading.com`, then check `X-Cache-Bypass` header on `/cart/` and `/checkout/`.
**Expected:** Both return `X-Cache-Bypass: 1` (bypass active because `woocommerce_enabled: true` activates the `$no_cache` rule in the bypass snippet).
**Why human:** Requires WooCommerce installed and a live product on the academy site.

---

### Gaps Summary

No gaps. All 16 requirements are implemented, verified in code, and correctly wired. The playbook passes syntax check. Terraform fmt passes. The two legacy template files with hardcoded strings are inert (not referenced by tasks) and do not constitute blockers.

The only unresolved items are the three human verification points above, which cannot be confirmed without a live deployment.

---

_Verified: 2026-03-28_
_Verifier: Claude (gsd-verifier)_
