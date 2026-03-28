---
phase: 01-iac-refactor
plan: "03"
subsystem: infra
tags: [ansible, wordpress, valkey, redis, nginx_wordpress, jinja2]

requires:
  - phase: 01-01
    provides: nginx_wordpress_redis_database and nginx_wordpress_redis_prefix variables in defaults/main.yml

provides:
  - wp-config.php.j2 renders WP_REDIS_HOST, WP_REDIS_PORT, WP_REDIS_DATABASE, WP_REDIS_PREFIX, WP_CACHE defines
  - Per-site Valkey object cache isolation via role variables

affects:
  - 01-02 (dual-wordpress playbook that will pass site-specific redis_database/prefix per invocation)
  - Phase 05 (WordPress provisioning — wp-config.php rendered from this template)

tech-stack:
  added: []
  patterns:
    - "Jinja2 | default() filter used alongside role variable for template safety net"
    - "Redis/Valkey PHP defines driven by Ansible role variables — per-site DB isolation without hardcoding"

key-files:
  created: []
  modified:
    - ansible/roles/nginx_wordpress/templates/wp-config.php.j2

key-decisions:
  - "WP_CACHE set to true unconditionally — redis-cache plugin is mandatory in nginx_wordpress_plugins_mandatory; no conditional needed"
  - "| default() filters retained in template as safety net even though defaults/main.yml already provides values"

patterns-established:
  - "Redis block placed between WP_DEBUG and $table_prefix — consistent with WordPress convention and plan spec"

requirements-completed: [WP-01, WP-02, WP-03]

duration: 4min
completed: "2026-03-28"
---

# Phase 01 Plan 03: Redis/Valkey wp-config Defines Summary

**wp-config.php.j2 extended with 5 PHP defines (WP_REDIS_HOST, PORT, DATABASE, PREFIX, WP_CACHE) driven by Ansible role variables for per-site Valkey isolation**

## Performance

- **Duration:** ~4 min
- **Started:** 2026-03-28T18:31:53Z
- **Completed:** 2026-03-28T18:35:53Z
- **Tasks:** 1
- **Files modified:** 1

## Accomplishments

- Added Redis/Valkey configuration block to wp-config.php.j2 after WP_DEBUG, before $table_prefix
- WP_REDIS_DATABASE and WP_REDIS_PREFIX use role variables with `| default()` fallbacks
- Main site (DB 0, prefix wp_main_) and academy (DB 1, prefix wp_academy_) will receive distinct rendered configs when dual-wordpress.yml passes the appropriate vars per invocation

## Task Commits

1. **Task 1: Add Redis/Valkey defines to wp-config.php.j2** - `a5046ba` (feat)

**Plan metadata:** (docs commit — follows below)

## Files Created/Modified

- `ansible/roles/nginx_wordpress/templates/wp-config.php.j2` - Added 5 PHP defines for Valkey object cache configuration driven by nginx_wordpress_redis_database and nginx_wordpress_redis_prefix variables

## Decisions Made

- `WP_CACHE` set unconditionally to `true` — redis-cache plugin is already in `nginx_wordpress_plugins_mandatory`, so the cache is always active for this role
- Kept `| default()` Jinja2 filters in the template even though `defaults/main.yml` already sets the variables — belt-and-suspenders approach for safety net if the template is ever used outside the role context

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- wp-config.php.j2 is ready to render site-specific Valkey config when dual-wordpress.yml (Plan 01-02) passes `nginx_wordpress_redis_database` and `nginx_wordpress_redis_prefix` per `include_role` invocation
- Plan 01-02 (dual-wordpress playbook) can proceed — it provides the per-site variable overrides that this template consumes

---
*Phase: 01-iac-refactor*
*Completed: 2026-03-28*
