---
phase: 01-iac-refactor
plan: "02"
subsystem: infra
tags: [ansible, playbook, dual-wordpress, mariadb, php-fpm, vault]

requires:
  - "01-01: nginx_wordpress role supports nginx_wordpress_site_name variable"

provides:
  - dual-wordpress.yml orchestration playbook with two isolated WordPress deployments
  - Two MariaDB databases (wordpress_main, wordpress_academy) with isolated users (wp_main, wp_academy)
  - Main site include_role invocation: site_name=main, max_children=20, learndash=false, woocommerce=false
  - Academy site include_role invocation: site_name=academy, max_children=30, learndash=true, woocommerce=true
  - Valkey DB isolation: main uses db=0 (wp_main_ prefix), academy uses db=1 (wp_academy_ prefix)
  - New vault variables documented in secrets.yml.example

affects:
  - 01-03 (Terraform cloudflare-config needs academy A record for academy.twomindstrading.com)
  - Phase 3 (OpenBao rotation scripts reference WP paths — both sites need coverage)

tech-stack:
  added: []
  patterns:
    - "Dual include_role pattern: same role invoked twice with distinct site_name values produces isolated deployments"
    - "Per-site vault salts: main uses vault_nginx_wordpress_* (existing), academy uses vault_wp_academy_* (new)"
    - "secrets.yml.example committed with git add -f (gitignore pattern *secret* too broad for .example files)"

key-files:
  created:
    - ansible/playbooks/dual-wordpress.yml
  modified:
    - ansible/inventory/group_vars/all/secrets.yml.example

key-decisions:
  - "Main site reuses existing vault_nginx_wordpress_* salt variables — no rename, backward compat with original wordpress.yml"
  - "vault_wordpress_db_password preserved in secrets.yml.example — still used by original wordpress.yml playbook"
  - "secrets.yml.example force-added with git add -f — .example files are documentation and should be tracked despite *secret* gitignore pattern"

metrics:
  duration: "2min"
  completed: "2026-03-28"
  tasks: 2
  files: 2
---

# Phase 01 Plan 02: Dual-WordPress Playbook Summary

**dual-wordpress.yml playbook created with two isolated MariaDB databases, two php-fpm pool configs (20/30 max_children), and two include_role invocations using per-site vault salts and Valkey DB separation**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-28T18:31:04Z
- **Completed:** 2026-03-28T18:33:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- `dual-wordpress.yml` created as the orchestration playbook for the dual-site rebuild
- Two MariaDB databases (wordpress_main, wordpress_academy) with no cross-access between wp_main and wp_academy users
- Main site: site_name=main, max_children=20, LearnDash disabled, WooCommerce disabled, Valkey db=0
- Academy site: site_name=academy, max_children=30, LearnDash enabled, WooCommerce enabled, Valkey db=1
- Independent vault salts per site — main reuses existing `vault_nginx_wordpress_*`, academy gets new `vault_wp_academy_*`
- `secrets.yml.example` updated with 10 new vault variables (2 DB passwords + 8 academy salts)

## Task Commits

1. **Task 1: Create dual-wordpress.yml** - `a9d0b75` (feat)
2. **Task 2: Update secrets.yml.example with new vault variables** - `b096f91` (feat)

## Files Created/Modified

- `ansible/playbooks/dual-wordpress.yml` - New 127-line dual-site playbook (roles: geerlingguy.mysql + valkey; tasks: 2x include_role; post_tasks: debug)
- `ansible/inventory/group_vars/all/secrets.yml.example` - Added 10 new vault_ variables with comment headers

## Decisions Made

- Main site reuses existing `vault_nginx_wordpress_*` salt variables — avoids renaming variables that may already be in encrypted vault files
- `vault_wordpress_db_password` preserved — still referenced by the original `wordpress.yml` playbook
- `secrets.yml.example` committed with `git add -f` — the `.example` file is documentation (no real secrets), but the gitignore `*secret*` pattern is too broad

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] secrets.yml.example gitignored by *secret* pattern**

- **Found during:** Task 2 commit
- **Issue:** `.gitignore` has `*secret*` pattern which matched `secrets.yml.example`
- **Fix:** Used `git add -f` to force-add the file — it is a documentation template, not an actual secrets file
- **Files modified:** None (commit procedure only)
- **Commit:** b096f91

## Known Stubs

None — the playbook uses real vault variable references. No hardcoded placeholder data flows to runtime behavior.

## Self-Check: PASSED

- `ansible/playbooks/dual-wordpress.yml` exists: FOUND
- `ansible/inventory/group_vars/all/secrets.yml.example` tracked: FOUND
- Commit a9d0b75: FOUND
- Commit b096f91: FOUND
