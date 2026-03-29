# Phase 1: IaC Refactor — Research

**Researched:** 2026-03-28
**Domain:** Ansible role parametrization, Nginx/PHP-FPM dual-instance, Terraform Cloudflare DNS
**Confidence:** HIGH

---

<phase_requirements>

## Phase Requirements

| ID | Description | Research Support |
|----|-------------|------------------|
| ROLE-01 | Add `nginx_wordpress_site_name` to `defaults/main.yml` | defaults/main.yml fully read — no such var exists yet |
| ROLE-02 | Parametrize `tasks/configure.yml`: vhost conf, pool conf, log names use site_name | configure.yml fully read — 4 hardcoded "wordpress" strings identified (see below) |
| ROLE-03 | Parametrize `php-fpm-wordpress.conf.j2`: pool name + socket path | Template read — pool name `[wordpress]` and socket `/run/php/phpX-fpm.sock` both hardcoded |
| ROLE-04 | Parametrize `wordpress.conf.j2`: socket path + fastcgi_cache_path + zone name + log names | Template read — 6 `fastcgi_pass` occurrences + 2 hardcoded log paths + hardcoded zone `wordpress` |
| ROLE-05 | Empty/remove `fastcgi-cache.conf.j2` — move `fastcgi_cache_path` to vhost | fastcgi-cache.conf.j2 fully read — exact directive documented below |
| ROLE-06 | Add `/ld-focus-mode/` and `/learndash-checkout/` bypass rules to `wordpress.conf.j2` | Cache bypass snippet pattern identified; bypass block location documented |
| ROLE-07 | `nginx_wordpress_woocommerce_enabled: true` for academy invocation | Variable already exists in defaults — just needs override in playbook call |
| PLAY-01 | New `dual-wordpress.yml` with 2 DBs, 2 users, 2 `include_role` calls | wordpress.yml structure fully read — geerlingguy.mysql vars format documented below |
| PLAY-02 | Main site invocation: `nginx_wordpress_site_name=main`, no LearnDash, no WooCommerce | Defaults show both `learndash_enabled: true` and `woocommerce_enabled: false` — both need explicit overrides |
| PLAY-03 | Academy invocation: `nginx_wordpress_site_name=academy`, LearnDash+WooCommerce, `letsencrypt_enabled=false` | Variables exist in defaults; `letsencrypt_enabled` maps to `nginx_wordpress_letsencrypt_enabled` |
| PLAY-04 | PHP-FPM pool sizes: main=20, academy=30 | Variables `nginx_wordpress_php_fpm_max_children` etc. exist in defaults |
| PLAY-05 | Vault: `vault_wp_main_db_password`, `vault_wp_academy_db_password`, independent salts for academy | secrets.yml.example naming convention documented below |
| WP-01 | wp-config.php.j2 accepts `WP_REDIS_DATABASE` and `WP_REDIS_PREFIX` | Template read — no Redis config exists yet; both defines must be added |
| WP-02 | Main site: `WP_REDIS_DATABASE=0`, prefix `wp_main_` | Requires new variables `nginx_wordpress_redis_database` and `nginx_wordpress_redis_prefix` |
| WP-03 | Academy: `WP_REDIS_DATABASE=1`, prefix `wp_academy_` | Same variables, different values passed per invocation |
| TF-01 | DNS A record `academy.twomindstrading.com` in `cloudflare-config/dns.tf` | dns.tf fully read — exact HCL pattern for A record documented below |
</phase_requirements>

---

## Summary

Phase 1 is a pure IaC refactor — no server changes, no production impact until Phase 3 (server rebuild). Every change is to files in the `ansible/` and `terraform/` trees. The role currently assumes a single WordPress instance: pool name, socket path, cache zone, log names, and cache directory are all hardcoded to the string `"wordpress"`. The refactor introduces `nginx_wordpress_site_name` as a per-invocation discriminator that flows through all of those locations.

The `fastcgi_cache_path` directive must move from `conf.d/fastcgi-cache.conf.j2` (global, shared) into `wordpress.conf.j2` (per-vhost) because the nginx-helper plugin's "Purge All" action does a recursive filesystem delete of the configured path with no domain filtering — a purge on academy would wipe the main site's cache. This is the single architectural change that adds scope beyond a simple string substitution.

The `wp-config.php.j2` template currently has no Redis/Valkey configuration at all. Both `WP_REDIS_DATABASE` and `WP_REDIS_PREFIX` defines must be added, with role variables to drive them.

**Primary recommendation:** Work plan-by-plan in sequence — ROLE changes first (01-01), then playbook (01-02), then wp-config (01-03), then Terraform (01-04). Each plan can be committed and linted independently.

---

## Project Constraints (from CLAUDE.md)

- Ansible: FQCN for all modules (`ansible.builtin.*`)
- YAML: 2-space indent throughout
- Terraform: `_` not `-` in resource names
- Pre-commit hooks must pass: yamllint (`--strict`, max 250 chars, `level: warning`), ansible-lint (`--profile=production`), gitleaks
- Conventional commits: `feat/fix/refactor/docs(scope): message`
- No auto-push — always confirm before pushing
- No comments in code unless explicitly requested
- `truthy` values in YAML: only `true`/`false`/`yes`/`no` allowed (yamllint enforces this)
- yamllint config file is `.yamllint.yml` (not `.yamllint`)

---

## Exact Change Inventory

### 1. configure.yml — Hardcoded "wordpress" references

File: `ansible/roles/nginx_wordpress/tasks/configure.yml`

| Line | Current value | Required change |
|------|---------------|-----------------|
| 24 | `path: /var/cache/nginx/wordpress` | `path: /var/cache/nginx/{{ nginx_wordpress_site_name }}` |
| 141 | `dest: "{{ nginx_wordpress_nginx_sites_available }}/wordpress.conf"` | `dest: "{{ nginx_wordpress_nginx_sites_available }}/{{ nginx_wordpress_site_name }}.conf"` |
| 151 | `src: "{{ nginx_wordpress_nginx_sites_available }}/wordpress.conf"` | `src: "{{ nginx_wordpress_nginx_sites_available }}/{{ nginx_wordpress_site_name }}.conf"` |
| 152 | `dest: "{{ nginx_wordpress_nginx_sites_enabled }}/wordpress.conf"` | `dest: "{{ nginx_wordpress_nginx_sites_enabled }}/{{ nginx_wordpress_site_name }}.conf"` |
| 193 | `dest: "{{ nginx_wordpress_php_fpm_pool_dir }}/wordpress.conf"` | `dest: "{{ nginx_wordpress_php_fpm_pool_dir }}/{{ nginx_wordpress_site_name }}.conf"` |

Additionally, the `Deploy FastCGI cache config` task at line 35–44 deploys to a fixed global path `/etc/nginx/conf.d/fastcgi-cache.conf`. After ROLE-05, this task becomes a no-op (the file is emptied) OR the task is removed entirely and the `fastcgi_cache_path` is embedded in the vhost template. The task can stay but the template it renders will no longer contain the `fastcgi_cache_path` directive — it will be empty when `nginx_wordpress_enable_fastcgi_cache` is false, and the global directives (`fastcgi_cache_key`, `fastcgi_cache_use_stale`, etc.) can remain global.

**Decision required in plan 01-01:** The non-path directives in `fastcgi-cache.conf.j2` (`fastcgi_cache_key`, `fastcgi_cache_use_stale`, `fastcgi_cache_background_update`, `fastcgi_cache_lock`) are global and must remain in `conf.d/` — only the `fastcgi_cache_path` line moves to the vhost. The file stays, minus that one block.

### 2. fastcgi-cache.conf.j2 — Directive to move

File: `ansible/roles/nginx_wordpress/templates/conf.d/fastcgi-cache.conf.j2`

The block to extract (lines 15–19) and move into `wordpress.conf.j2`:

```nginx
fastcgi_cache_path /var/cache/nginx/wordpress
    levels=1:2
    keys_zone=wordpress:100m
    inactive=60m
    max_size=512m
    use_temp_path=off;
```

After parametrization in `wordpress.conf.j2` (placed at the top of the `server {}` block, before the `location` blocks — `fastcgi_cache_path` is valid in `http` context, which the vhost include resolves into):

```nginx
{% if nginx_wordpress_enable_fastcgi_cache | default(true) %}
fastcgi_cache_path /var/cache/nginx/{{ nginx_wordpress_site_name }}
    levels=1:2
    keys_zone={{ nginx_wordpress_site_name }}:100m
    inactive=60m
    max_size=512m
    use_temp_path=off;
{% endif %}
```

The `fastcgi_cache wordpress;` references inside the `location ~ \.php$` block (lines 110 and 238) become:

```nginx
fastcgi_cache {{ nginx_wordpress_site_name }};
```

### 3. php-fpm-wordpress.conf.j2 — Pool name and socket

File: `ansible/roles/nginx_wordpress/templates/php-fpm-wordpress.conf.j2`

Current state:

- Line 4: `[wordpress]` — pool section header
- Line 8: `listen = /run/php/php{{ nginx_wordpress_php_version }}-fpm.sock` — shared socket path

After parametrization:

- `[{{ nginx_wordpress_site_name }}]`
- `listen = /run/php/php{{ nginx_wordpress_php_version }}-{{ nginx_wordpress_site_name }}-fpm.sock`

The `listen.owner` and `listen.group` lines reference role variables already and need no change.

### 4. wordpress.conf.j2 — fastcgi_pass occurrences and log paths

File: `ansible/roles/nginx_wordpress/templates/sites-available/wordpress.conf.j2`

**fastcgi_pass — 6 occurrences**, all with identical current value:

- Line 104 (HTTPS, main PHP location)
- Line 140 (HTTPS, `/wp-login.php`)
- Line 158 (HTTPS, `/wp-json/` nested location)
- Line 172 (HTTPS, `/wp-admin/admin-ajax.php`)
- Line 234 (HTTP, main PHP location)
- Line 259 (HTTP, `/wp-login.php`)

Current value (all 6): `fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-fpm.sock;`

New value (all 6): `fastcgi_pass unix:/run/php/php{{ nginx_wordpress_php_version }}-{{ nginx_wordpress_site_name }}-fpm.sock;`

**Log paths — 2 occurrences**, one in each SSL branch:

- Line 82 (HTTPS): `access_log /var/log/nginx/wordpress-access.log;` and line 83: `error_log /var/log/nginx/wordpress-error.log;`

- Line 205 (HTTP): `access_log /var/log/nginx/wordpress-access.log;` and line 206: `error_log /var/log/nginx/wordpress-error.log;`

New pattern: `access_log /var/log/nginx/{{ nginx_wordpress_site_name }}-access.log;` / `error_log /var/log/nginx/{{ nginx_wordpress_site_name }}-error.log;`

**fastcgi_cache zone references — 2 occurrences** (one per SSL branch):

- Line 110: `fastcgi_cache wordpress;`
- Line 238: `fastcgi_cache wordpress;`

New: `fastcgi_cache {{ nginx_wordpress_site_name }};`

### 5. LearnDash bypass rules to add (ROLE-06)

The cache bypass snippet is included at `snippets/wordpress-cache-bypass.conf`. The bypass rules for LearnDash go in `wordpress.conf.j2` as additional `location` blocks that set `fastcgi_cache_bypass 1; fastcgi_no_cache 1;` — or they can be added to the bypass snippet itself if the snippet is already parameterized. Check `templates/snippets/wordpress-cache-bypass.conf.j2` before deciding.

Minimum addition required in the academy vhost (or unconditionally since it only matters when LearnDash is active):

```nginx
location ~* ^/(ld-focus-mode|learndash-checkout)/ {
    try_files $uri $uri/ /index.php?$args;
    fastcgi_cache_bypass 1;
    fastcgi_no_cache 1;
}
```

Condition in template: wrap in `{% if nginx_wordpress_learndash_enabled | default(true) %}`.

---

## defaults/main.yml — New variable

Add at the top of the `Nginx Configuration` section (after line 26, before `nginx_wordpress_server_name`):

```yaml
nginx_wordpress_site_name: "wordpress"
```

Default of `"wordpress"` preserves backward compatibility with any existing single-site deploys that do not pass this variable.

Also add defaults for the new Redis variables (WP-01):

```yaml
nginx_wordpress_redis_database: 0
nginx_wordpress_redis_prefix: "wp_"
```

---

## wp-config.php.j2 — Redis section to add

File: `ansible/roles/nginx_wordpress/templates/wp-config.php.j2`

Current state: no Redis/Valkey configuration exists anywhere in the file.

Add after the `WP_DEBUG` define (after line 27), before `$table_prefix`:

```php
define('WP_REDIS_HOST', '127.0.0.1');
define('WP_REDIS_PORT', 6379);
define('WP_REDIS_DATABASE', {{ nginx_wordpress_redis_database | default(0) }});
define('WP_REDIS_PREFIX', '{{ nginx_wordpress_redis_prefix | default("wp_") }}');
define('WP_CACHE', true);
```

---

## Vault variable naming convention

File: `ansible/inventory/group_vars/all/secrets.yml.example`

Existing pattern: `vault_` prefix + descriptive snake_case name.

Examples already in use:

- `vault_mariadb_root_password`
- `vault_wordpress_db_password`
- `vault_nginx_wordpress_admin_password`
- `vault_nginx_wordpress_auth_key` (and all 8 salts)

New variables required (PLAY-05) — following the same pattern:

- `vault_wp_main_db_password` — MariaDB password for `wp_main` user
- `vault_wp_academy_db_password` — MariaDB password for `wp_academy` user
- `vault_wp_academy_auth_key` — academy-specific WP salt (and the other 7 salts)
- `vault_wp_academy_secure_auth_key`
- `vault_wp_academy_logged_in_key`
- `vault_wp_academy_nonce_key`
- `vault_wp_academy_auth_salt`
- `vault_wp_academy_secure_auth_salt`
- `vault_wp_academy_logged_in_salt`
- `vault_wp_academy_nonce_salt`

The existing `vault_nginx_wordpress_*` salts become the main site salts (no rename needed — the main site invocation passes them directly).

Both `vault_wp_main_db_password` and `vault_wp_academy_db_password` must also be added to `secrets.yml.example` for documentation.

---

## dual-wordpress.yml — Structure and geerlingguy.mysql format

Base pattern from `ansible/playbooks/wordpress.yml` — the `geerlingguy.mysql` role accepts:

```yaml
mysql_databases:
  - name: "wordpress_main"
    encoding: utf8mb4
    collation: utf8mb4_unicode_ci
  - name: "wordpress_academy"
    encoding: utf8mb4
    collation: utf8mb4_unicode_ci

mysql_users:
  - name: "wp_main"
    host: localhost
    password: "{{ vault_wp_main_db_password }}"
    priv: "wordpress_main.*:ALL"
  - name: "wp_academy"
    host: localhost
    password: "{{ vault_wp_academy_db_password }}"
    priv: "wordpress_academy.*:ALL"
```

The two `include_role` invocations follow this structure:

```yaml
- name: Deploy main site
  ansible.builtin.include_role:
    name: nginx_wordpress
  vars:
    nginx_wordpress_site_name: main
    nginx_wordpress_server_name: twomindstrading.com
    nginx_wordpress_web_root: /var/www/twomindstrading.com
    nginx_wordpress_db_name: wordpress_main
    nginx_wordpress_db_user: wp_main
    nginx_wordpress_db_password: "{{ vault_wp_main_db_password }}"
    nginx_wordpress_php_fpm_max_children: 20
    nginx_wordpress_learndash_enabled: false
    nginx_wordpress_woocommerce_enabled: false
    nginx_wordpress_redis_database: 0
    nginx_wordpress_redis_prefix: "wp_main_"
    nginx_wordpress_auth_key: "{{ vault_nginx_wordpress_auth_key }}"
    # ... remaining salts from existing vault vars

- name: Deploy academy site
  ansible.builtin.include_role:
    name: nginx_wordpress
  vars:
    nginx_wordpress_site_name: academy
    nginx_wordpress_server_name: academy.twomindstrading.com
    nginx_wordpress_web_root: /var/www/academy.twomindstrading.com
    nginx_wordpress_db_name: wordpress_academy
    nginx_wordpress_db_user: wp_academy
    nginx_wordpress_db_password: "{{ vault_wp_academy_db_password }}"
    nginx_wordpress_php_fpm_max_children: 30
    nginx_wordpress_learndash_enabled: true
    nginx_wordpress_woocommerce_enabled: true
    nginx_wordpress_letsencrypt_enabled: false
    nginx_wordpress_redis_database: 1
    nginx_wordpress_redis_prefix: "wp_academy_"
    nginx_wordpress_auth_key: "{{ vault_wp_academy_auth_key }}"
    # ... remaining salts from vault_wp_academy_* vars
```

**Note on handler deduplication:** Both `include_role` invocations share the same `restart php-fpm` handler by name. It fires once at flush time after both roles complete — this is correct behavior, not a bug.

---

## Terraform DNS pattern — TF-01

File: `terraform/modules/cloudflare-config/dns.tf`

Existing A record pattern (lines 6–13 — `cloudflare_record.root`):

```hcl
resource "cloudflare_record" "root" {
  zone_id = data.cloudflare_zone.main.id
  name    = "@"
  content = var.server_ipv4
  type    = "A"
  proxied = true
  ttl     = 1
  comment = "Root domain pointing to Hetzner server"
}
```

New record for TF-01 — add after `cloudflare_record.prometheus` (line ~62):

```hcl
resource "cloudflare_record" "academy" {
  zone_id = data.cloudflare_zone.main.id
  name    = "academy"
  content = var.server_ipv4
  type    = "A"
  proxied = true
  ttl     = 1
  comment = "Academy WordPress site (LMS + WooCommerce)"
}
```

Resource name uses `_` — consistent with project convention. No new variables needed — `var.server_ipv4` is already used by `root`, `grafana`, and `prometheus` records.

---

## YAML linting constraints

Config file: `.yamllint.yml` (the pre-commit hook references `-c=.yamllint.yml`)

| Rule | Value | Impact |
|------|-------|--------|
| `line-length.max` | 250 | Warning (not error), but `--strict` promotes warnings to errors in pre-commit |
| `indentation.spaces` | 2 | Hard error — all new YAML must use 2-space indent |
| `indentation.indent-sequences` | true | List items must be indented under their parent key |
| `truthy.allowed-values` | `true`, `false`, `yes`, `no` | No bare `on`/`off` values in YAML |
| `comments.min-spaces-from-content` | 1 | Single space between code and inline comment |

`geerlingguy.mysql/` is excluded from yamllint. All new files in `ansible/` (except that role) must pass yamllint with `--strict`.

ansible-lint runs with `--profile=production` — his enforces FQCN for all modules (no shorthand like `copy:`, must be `ansible.builtin.copy:`). The `dual-wordpress.yml` playbook must use FQCN for the `include_role` call: `ansible.builtin.include_role`.

Terraform files must pass `terraform fmt -check -recursive` — the pre-commit hook enforces this. The new `cloudflare_record.academy` block must be formatted consistently with adjacent records (no extra blank lines, aligned `=` signs are not required by `terraform fmt`).

---

## Architecture Patterns

### Role variable overrid via include_role vars

`include_role` with `vars:` creates a per-invocation scope. Variables passed via `vars:` take precedence over `defaults/main.yml`. This is the correct mechanism — no `allow_duplicates: true` in `meta/main.yml` is required.

### fastcgi_cache_path placement

`fastcgi_cache_path` is valid in `http {}` context. A vhost config file in `sites-available/` is included inside `http {}` by Nginx's main config. Placing `fastcgi_cache_path` at the top of `wordpress.conf.j2` (outside the `server {}` block) is architecturally correct and the standard approach for per-site cache isolation.

### PHP-FPM socket naming

PHP-FPM pools with distinct socket paths (`/run/php/phpX.X-main-fpm.sock`, `/run/php/phpX.X-academy-fpm.sock`) are independent — the pool manager for each listens on its own socket. Nginx connects to the correct socket per vhost.

---

## Common Pitfalls

### Pitfall 1: fastcgi_cache zone name collision

**What goes wrong:** Two vhosts referencing the same `keys_zone` name share a cache memory zone. Nginx will start, but cache entries from different sites collide on keys that don't include `$host`.
**Why it happens:** The `fastcgi_cache_key` in `fastcgi-cache.conf.j2` includes `$host` — so hits won't collide. But the `fastcgi_cache_path` filesystem directory must still be separate to prevent nginx-helper purge cross-contamination.
**How to avoid:** Use `{{ nginx_wordpress_site_name }}` in both the `keys_zone` name and the path.

### Pitfall 2: configure.yml still deploying fastcgi-cache.conf per-invocation

**What goes wrong:** Both `include_role` invocations render `fastcgi-cache.conf.j2` to the same global path `/etc/nginx/conf.d/fastcgi-cache.conf`. The second invocation overwrites the first's file. Since the file only contains global directives (no per-site paths after ROLE-05), this is harmless — but it's an unnecessary duplicate write.
**How to avoid:** Add `when: nginx_wordpress_site_name == 'main'` to the "Deploy FastCGI cache config" task, OR extract the global directives to a separate always-deployed task that runs outside the per-site role. The `when: nginx_wordpress_site_name == 'main'` guard is the simplest approach.

### Pitfall 3: PHP-FPM pool conf filename collision

**What goes wrong:** Both invocations write to `{{ php_fpm_pool_dir }}/wordpress.conf` if the dest is not parametrized (line 193 of configure.yml). The second invocation silently overwrites the first pool config.
**Why it happens:** Line 193 of configure.yml uses a hardcoded `wordpress.conf` destination — this is the exact line that ROLE-02 must fix.
**How to avoid:** `dest: "{{ nginx_wordpress_php_fpm_pool_dir }}/{{ nginx_wordpress_site_name }}.conf"`

### Pitfall 4: wp-config.php.j2 idempotency gate

**What goes wrong:** The configure.yml task at line 215 only creates `wp-config.php` if the file does not already exist. Adding new Redis defines is safe in the template — but an existing wp-config.php on a live server will not be updated.
**Impact for this phase:** Phase 1 is pure IaC (no server apply until Phase 3). On the new rebuilt server (Phase 3), the wp-config.php will never pre-exist, so the new template will be rendered in full. No action needed in Phase 1.

### Pitfall 5: Molecule test failure after socket rename

**What goes wrong:** Molecule's `verify.yml` or `converge.yml` may assert the old socket path `/run/php/phpX.X-fpm.sock`. After parametrization, the socket name changes to `/run/php/phpX.X-wordpress-fpm.sock` (with the default `nginx_wordpress_site_name: "wordpress"`).
**How to avoid:** The default value `nginx_wordpress_site_name: "wordpress"` means the rendered socket is `/run/php/php8.4-wordpress-fpm.sock`. Check Molecule verify tasks for hardcoded socket assertions. This is a Phase 2 (TEST-01) concern — flagged for the testing plan.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Per-site variable scope in Ansible | Custom wrapper role or loop | `include_role` with `vars:` | Native dynamic scoping, no `allow_duplicates` needed |
| DNS record management | Terraform null_resource + curl | `cloudflare_record` resource | Declarative, state-tracked, idempotent |
| PHP-FPM pool isolation | Custom PHP-FPM master config | Pool `.conf` files in `pool.d/` | Standard PHP-FPM mechanism, supported by package |
| FastCGI cache isolation | Nginx map module + custom keys | Separate `fastcgi_cache_path` per vhost | Only reliable way to prevent nginx-helper cross-site purge |

---

## Open Questions

1. **wordpress-cache-bypass.conf.j2 LearnDash bypass rules**
   - What we know: ROLE-06 requires adding `/ld-focus-mode/` and `/learndash-checkout/` bypass rules
   - What's unclear: Whether the snippet at `templates/snippets/wordpress-cache-bypass.conf.j2` already has a LearnDash section (not read in this research pass)
   - Recommendation: Read the snippet before writing plan 01-01; if LearnDash patterns already exist in the snippet, ROLE-06 may only need to add the two missing paths there rather than in `wordpress.conf.j2`

2. **configure.yml global fastcgi-cache task guard**
   - What we know: After ROLE-05, the `fastcgi-cache.conf.j2` task becomes idempotent (second invocation writes same content)

   - What's unclear: Whether to add `when: nginx_wordpress_site_name == 'main'` guard or leave it as-is
   - Recommendation: Add the guard — it's explicit and prevents a confusing double-write in `--check` output

3. **Molecule converge.yml site_name variable**
   - What we know: Molecule tests must pass (TEST-01, Phase 2). The default `nginx_wordpress_site_name: "wordpress"` changes the socket path.
   - What's unclear: Whether Molecule's verify step checks the socket path explicitly
   - Recommendation: Flag in plan 01-01 to inspect Molecule scenario files — document the socket name change so the Phase 2 plan can address it

---

## Sources

### Primary (HIGH confidence)

- Direct read: `ansible/roles/nginx_wordpress/tasks/configure.yml` — exact line numbers for all hardcoded paths
- Direct read: `ansible/roles/nginx_wordpress/templates/conf.d/fastcgi-cache.conf.j2` — exact directive to move
- Direct read: `ansible/roles/nginx_wordpress/templates/sites-available/wordpress.conf.j2` — all 6 fastcgi_pass locations, both log path locations
- Direct read: `ansible/roles/nginx_wordpress/templates/php-fpm-wordpress.conf.j2` — pool name and socket path
- Direct read: `ansible/roles/nginx_wordpress/defaults/main.yml` — full variable inventory
- Direct read: `ansible/roles/nginx_wordpress/templates/wp-config.php.j2` — confirmed no Redis config exists
- Direct read: `ansible/playbooks/wordpress.yml` — geerlingguy.mysql vars format

- Direct read: `ansible/inventory/group_vars/all/secrets.yml.example` — vault naming convention
- Direct read: `terraform/modules/cloudflare-config/dns.tf` — exact HCL pattern for A records
- Direct read: `.yamllint.yml` + `.pre-commit-config.yaml` — all linting constraints
- Prior research: `.planning/research/ARCHITECTURE.md` — include_role scoping, fastcgi cache isolation rationale
- Prior research: `.planning/research/FEATURES.md` — Valkey isolation, WooCommerce bypass requirements

### Secondary (MEDIUM confidence)

- `.planning/research/SUMMARY.md` — synthesized findings confirming fastcgi_cache_path placement

---

## Metadata

**Confidence breakdown:**

- Exact line references: HIGH — all files read directly
- Architecture (include_role, cache isolation): HIGH — confirmed in prior research docs
- Vault naming convention: HIGH — read from secrets.yml.example
- HCL pattern: HIGH — read from dns.tf
- YAML lint constraints: HIGH — read from .yamllint.yml
- LearnDash bypass snippet content: LOW — snippet file not read; flagged as open question

**Research date:** 2026-03-28
**Valid until:** 2026-05-28 (stable tooling — Ansible, Nginx, Terraform patterns do not change rapidly)
