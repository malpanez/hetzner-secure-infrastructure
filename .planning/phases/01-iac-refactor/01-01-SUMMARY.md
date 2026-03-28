---
phase: 01-iac-refactor
plan: "01"
subsystem: infra
tags: [ansible, nginx, php-fpm, wordpress, fastcgi-cache, multi-instance]

requires: []

provides:
  - nginx_wordpress role supports multiple instances via nginx_wordpress_site_name variable
  - Per-vhost PHP-FPM pools with isolated socket paths (fpm-{{ site_name }}.sock)
  - Per-vhost fastcgi_cache_path and cache zones in wordpress.conf.j2
  - Per-vhost log files (site_name-access.log, site_name-error.log)
  - Conditional LearnDash bypass location blocks (ld-focus-mode, learndash-checkout)
  - FastCGI global conf.d no longer contains fastcgi_cache_path (moved to vhost)

affects:
  - 01-02 (dual-wordpress playbook uses nginx_wordpress_site_name)
  - 01-03 (Valkey/Redis config uses redis_database per site)
  - molecule tests for nginx_wordpress role

tech-stack:
  added: []
  patterns:
    - "include_role x2 pattern: same role, different nginx_wordpress_site_name values produce isolated configs"
    - "Per-vhost fastcgi_cache_path in sites-available (not global conf.d)"
    - "FastCGI deploy guard: only site_name=wordpress or main writes global conf.d"

key-files:
  created: []
  modified:
    - ansible/roles/nginx_wordpress/defaults/main.yml
    - ansible/roles/nginx_wordpress/tasks/configure.yml
    - ansible/roles/nginx_wordpress/templates/php-fpm-wordpress.conf.j2
    - ansible/roles/nginx_wordpress/templates/conf.d/fastcgi-cache.conf.j2
    - ansible/roles/nginx_wordpress/templates/sites-available/wordpress.conf.j2

key-decisions:
  - "nginx_wordpress_site_name defaults to 'wordpress' for full backward compatibility with existing single-site deployments"
  - "php_version corrected from 8.4 to 8.3 — Debian 13 production ships PHP 8.3; 8.4 would cause 502 errors on all socket paths"
  - "fastcgi_cache_path moved from global conf.d to per-vhost wordpress.conf.j2 — two sites need separate cache zones"
  - "FastCGI conf.d deploy guard (site_name == 'wordpress' or 'main') prevents second include_role from overwriting global directives"

patterns-established:
  - "Site isolation via site_name: pool name, socket, conf path, symlink, log files, cache zone all use {{ nginx_wordpress_site_name }}"

requirements-completed: [ROLE-01, ROLE-02, ROLE-03, ROLE-04, ROLE-05, ROLE-06, ROLE-07]

duration: 3min
completed: "2026-03-28"
---

# Phase 01 Plan 01: nginx_wordpress Multi-Instance Parametrization Summary

**nginx_wordpress role refactored with site_name variable — two include_role invocations now produce fully isolated PHP-FPM pools, vhost configs, cache zones, and log files**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-28T18:18:34Z
- **Completed:** 2026-03-28T18:21:22Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments

- All hardcoded "wordpress" strings in active templates replaced with `nginx_wordpress_site_name` variable
- PHP version corrected from 8.4 to 8.3 (production Debian 13 PHP version)
- Per-vhost `fastcgi_cache_path` moved into `wordpress.conf.j2` with per-site keys_zone
- LearnDash `/ld-focus-mode/` and `/learndash-checkout/` bypass location blocks added conditionally
- Redis database and prefix defaults added for Plan 01-03 Valkey configuration

## Task Commits

1. **Task 1: Add site_name var, parametrize defaults/configure/php-fpm/fastcgi-cache** - `4eb2ac5` (feat)
2. **Task 2: Parametrize wordpress.conf.j2 — socket paths, cache zone, logs, LearnDash bypass** - `8e74fe7` (feat)

## Files Created/Modified

- `ansible/roles/nginx_wordpress/defaults/main.yml` - Added site_name default, fixed php_version to 8.3, added Redis defaults
- `ansible/roles/nginx_wordpress/tasks/configure.yml` - Parametrized 5 paths + added FastCGI conf.d deploy guard
- `ansible/roles/nginx_wordpress/templates/php-fpm-wordpress.conf.j2` - Pool name and socket path now use site_name
- `ansible/roles/nginx_wordpress/templates/conf.d/fastcgi-cache.conf.j2` - Removed fastcgi_cache_path block (moved to vhost)
- `ansible/roles/nginx_wordpress/templates/sites-available/wordpress.conf.j2` - Per-vhost cache_path, 6 socket paths, 4 log paths, 2 cache zones, LearnDash bypass blocks

## Decisions Made

- `nginx_wordpress_site_name` defaults to `"wordpress"` — preserves full backward compat with any existing playbook that doesn't pass the variable
- PHP version fixed to 8.3 — `defaults/main.yml` had 8.4 but Debian 13 production runs 8.3; leaving 8.4 would cause 502 on both sites after rebuild
- `fastcgi_cache_path` moved to `wordpress.conf.j2` (per-vhost) — two sites need distinct `keys_zone` names or nginx would fail to load
- FastCGI conf.d deploy guard uses `or` logic (`== 'main' or == 'wordpress'`) so the first include_role writes the global directives and subsequent ones skip

## Deviations from Plan

None — plan executed exactly as written.

## Issues Encountered

Legacy templates `nginx-wordpress.conf.j2` and `nginx-wordpress-optimized.conf.j2` still contain hardcoded "wordpress" paths. These are not referenced by any task in `configure.yml` — they are archival/example templates. Out of scope for this plan (only active modular templates were in scope).

## User Setup Required

None — no external service configuration required.

## Next Phase Readiness

- Role is ready for Plan 01-02 (dual-wordpress.yml playbook with two `include_role` invocations using different `nginx_wordpress_site_name` values)
- Plan 01-03 Valkey config can use `nginx_wordpress_redis_database` and `nginx_wordpress_redis_prefix` defaults added here
- Molecule tests for `nginx_wordpress` role should be updated to test with a non-default `nginx_wordpress_site_name` (tracked separately)

---
*Phase: 01-iac-refactor*
*Completed: 2026-03-28*

## Self-Check: PASSED

All expected files exist and all task commits verified in git history.
