---
phase: 02-testing-validation
plan: "01"
subsystem: ansible-molecule
tags: [molecule, ansible-lint, nginx_wordpress, testing, php]
dependency_graph:
  requires: []
  provides: [TEST-01]
  affects: [nginx_wordpress role, molecule test suite]
tech_stack:
  added: []
  patterns:
    - notify handler instead of inline reload task
    - PHP version override in molecule host_vars for container compatibility
    - changed_when: false on apt update for idempotency
key_files:
  created: []
  modified:
    - ansible/roles/nginx_wordpress/molecule/default/molecule.yml
    - ansible/roles/nginx_wordpress/molecule/default/verify.yml
    - ansible/roles/nginx_wordpress/molecule/default/converge.yml
    - ansible/roles/nginx_wordpress/tasks/configure.yml
    - ansible/roles/nginx_wordpress/tasks/nginx-repo.yml
decisions:
  - PHP 8.4 used in molecule (not 8.3) — Debian 13 container ships 8.4 natively; sury.org repo not available in geerlingguy Docker image; production will still use 8.3 via sury.org
  - changed_when: false on apt update pre_task — no cache_valid_time allowed per CLAUDE.md, and update_cache always reports changed; suppression is the correct fix
metrics:
  duration: "55 min"
  completed: "2026-03-28T20:49:08Z"
  tasks_completed: 2
  files_modified: 5
  commits: 6
---

# Phase 02 Plan 01: Molecule Test Fix and Validation Summary

**One-liner:** Fixed 4 ansible-lint violations and 2 molecule test failures; molecule test passes all stages (create/converge/idempotence/verify/destroy) with exit 0.

## Tasks Completed

| # | Task | Commit | Files |
|---|------|--------|-------|
| 1A | Add explicit site_name to molecule host_vars | 715ea76 | molecule.yml |
| 1B | Correct verify.yml web root path to /var/www/wordpress | 0d37e87 | verify.yml |
| 1C | Replace inline nginx reload with handler notification | 46ef3f7 | configure.yml |
| 1D | Fix jinja spacing in nginx-repo.yml | ea9c5cb | nginx-repo.yml |
| 2A | Fix PHP version for molecule container (8.3→8.4) | 33c9bdb | molecule.yml, verify.yml |
| 2B | Suppress apt update idempotency false-positive | a70eb4c | converge.yml |

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocker] PHP 8.3 not available in Debian 13 Docker container**
- **Found during:** Task 2 — first molecule test run
- **Issue:** `php8.3-fpm` install failed with "No package matching 'php8.3-fpm' is available". Debian 13 (Trixie) ships PHP 8.4 natively; PHP 8.3 requires the sury.org PPA which is not configured in the geerlingguy Docker image.
- **Fix:** Added `nginx_wordpress_php_version: "8.4"` to molecule.yml host_vars; parameterized the php-fpm package assertion in verify.yml using `nginx_wordpress_php_version | default('8.4')`. Production server continues to use PHP 8.3 via sury.org (set in group_vars, unaffected).
- **Files modified:** `molecule/default/molecule.yml`, `molecule/default/verify.yml`
- **Commit:** 33c9bdb

**2. [Rule 1 - Bug] apt update pre_task reports changed on every converge run**
- **Found during:** Task 2 — idempotency check failed with `Update apt cache` as changed
- **Issue:** `ansible.builtin.apt: update_cache: true` always reports changed. `cache_valid_time` cannot be used per CLAUDE.md constraint (Docker image has fresh mtime, causes task failure).
- **Fix:** Added `changed_when: false` to the Update apt cache pre_task in converge.yml.
- **Files modified:** `molecule/default/converge.yml`
- **Commit:** a70eb4c

## Verification Results

```
molecule test stages:
  destroy:     Successful
  syntax:      Successful
  create:      Successful
  converge:    Successful  (ok=72, changed=31, failed=0)
  idempotence: Successful
  verify:      Successful
  destroy:     Successful
Exit code: 0
```

ansible-lint violations fixed:
- no-handler in configure.yml:178 — resolved
- jinja[spacing] in nginx-repo.yml:29 — resolved

## Decisions Made

1. **PHP 8.4 in molecule**: Debian 13 Docker container ships PHP 8.4 natively. Rather than adding sury.org PPA setup to converge pre_tasks (which would test infra setup, not the role itself), overriding `nginx_wordpress_php_version` to `8.4` in molecule host_vars tests the role logic against the native Debian 13 package. Production continues to use PHP 8.3 via sury.org.

2. **changed_when: false on apt update**: CLAUDE.md explicitly forbids `cache_valid_time` in molecule converge.yml (Docker image mtime issue). Using `changed_when: false` is the correct idempotency approach for a pre_task that must always run but doesn't represent a meaningful configuration change.

## Known Stubs

None.

## Self-Check: PASSED
