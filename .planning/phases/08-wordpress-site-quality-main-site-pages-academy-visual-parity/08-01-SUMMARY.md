---
phase: 08-wordpress-site-quality-main-site-pages-academy-visual-parity
plan: "01"
subsystem: ansible/roles/nginx_wordpress
tags: [wordpress, plugins, learndash, academy, zip]
dependency_graph:
  requires: []
  provides: [ZIP plugin install automation for nginx_wordpress role]
  affects: [ansible/playbooks/dual-wordpress.yml, ansible/roles/nginx_wordpress]
tech_stack:
  added: []
  patterns: [WP-CLI ZIP plugin install via shell with idempotency check]
key_files:
  created:
    - ansible/roles/nginx_wordpress/tasks/wordpress-plugins-zip.yml
    - ansible/roles/nginx_wordpress/files/plugins/.gitignore
  modified:
    - ansible/roles/nginx_wordpress/tasks/main.yml
    - ansible/roles/nginx_wordpress/defaults/main.yml
    - ansible/playbooks/dual-wordpress.yml
decisions:
  - "molecule-notest tag applied to copy and shell tasks — ZIP file not present in CI environment"
  - "Idempotency via wp-cli plugin is-installed check before install — changed_when driven by SKIP: prefix in stdout"
  - "Temp directory /tmp/wp-plugin-zips created and cleaned per-run to avoid stale ZIP collisions"
metrics:
  duration: "~10 minutes"
  completed: "2026-04-11"
  tasks_completed: 2
  files_changed: 5
requirements_covered: [ACAD-01, ACAD-02]
---

# Phase 08 Plan 01: ZIP Plugin Install Automation Summary

**One-liner:** WP-CLI ZIP-based plugin install task file for commercial plugins (LearnDash Pro), wired into nginx_wordpress role with idempotency guard and academy vars declared.

## What Was Built

The `nginx_wordpress` role now supports installing commercial plugins distributed as ZIP files (not available on WP.org). A new task file `wordpress-plugins-zip.yml` handles the full lifecycle: stat check, temp dir creation, ZIP copy, WP-CLI install with idempotency, and cleanup. The task file is conditionally included from `main.yml` only when `nginx_wordpress_plugins_zip` list has entries.

The academy section of `dual-wordpress.yml` now declares `sfwd-lms.4.25.7.1.zip` as the LearnDash Pro ZIP to install. The actual ZIP must be placed at `ansible/roles/nginx_wordpress/files/plugins/sfwd-lms.4.25.7.1.zip` before running the playbook — the `.gitignore` prevents it from being committed.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Create wordpress-plugins-zip.yml and wire into role | d747c4b | wordpress-plugins-zip.yml, main.yml, defaults/main.yml, files/plugins/.gitignore |
| 2 | Add LearnDash ZIP to academy vars in dual-wordpress.yml | 8a0c549 | dual-wordpress.yml |

## Verified Truths

- `force-gd.php` (configure.yml ~line 405) deploys to `{{ nginx_wordpress_web_root }}` with no site-name condition — deploys to academy automatically
- `tmt-perf.php` (wordpress-mu-plugins.yml line 20) deploys to `{{ nginx_wordpress_web_root }}` with no site-name condition — deploys to academy automatically

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no hardcoded empty values or placeholders in delivered files.

## Pre-existing Issues (Out of Scope)

- `yaml[comments-indentation]` in `defaults/main.yml` line 185 — comment inside `nginx_wordpress_plugins_manual` list, pre-existing before this plan
- `no-changed-when` warnings in `configure.yml` lines 286, 317, 333 — pre-existing, not in scope

## Manual Step Required

Before running `dual-wordpress.yml` for academy, place the LearnDash Pro ZIP at:
```
ansible/roles/nginx_wordpress/files/plugins/sfwd-lms.4.25.7.1.zip
```
The `.gitignore` prevents it from being committed to the repository.

## Self-Check: PASSED
