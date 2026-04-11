---
phase: 08-wordpress-site-quality-main-site-pages-academy-visual-parity
plan: "02"
subsystem: ansible/roles/nginx_wordpress
tags: [wordpress, content, seo, themes, optimization]
dependency_graph:
  requires: ["08-01"]
  provides: ["MAIN-01", "MAIN-04", "MAIN-05"]
  affects: ["ansible/roles/nginx_wordpress", "ansible/playbooks/dual-wordpress.yml"]
tech_stack:
  added: []
  patterns: [Jinja2 conditional in shell block scalar, WP-CLI theme loop]
key_files:
  created: []
  modified:
    - ansible/roles/nginx_wordpress/tasks/wordpress-content.yml
    - ansible/roles/nginx_wordpress/tasks/wordpress-optimization.yml
    - ansible/playbooks/dual-wordpress.yml
decisions:
  - "Jinja2 {% if %} tags indented 4 spaces inside block scalar to keep YAML valid"
  - "Theme cleanup uses WP-CLI --status=inactive list + shell loop (idempotent, no WP-CLI bulk-delete)"
  - "molecule-notest on theme cleanup — WP-CLI not available in CI Docker container"
metrics:
  duration: "~5 min"
  completed_date: "2026-04-11"
  tasks_completed: 3
  files_modified: 3
---

# Phase 08 Plan 02: SEO Titles, Theme Cleanup, Mobile Nav Verification Summary

SEO titles via conditional --post_title in WP-CLI post update, theme cleanup loop for both sites, MAIN-05 mobile nav confirmed in 9/9 HTML pages.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add --post_title to wordpress-content.yml and titles to dual-wordpress.yml | 758fd70 | wordpress-content.yml, dual-wordpress.yml |
| 2 | Add theme cleanup task to wordpress-optimization.yml | 7bf7a01 | wordpress-optimization.yml |
| 3 | Verify MAIN-05 mobile nav coverage (already committed) | — (no changes) | — |

## What Was Built

### Task 1: SEO Post Title Support
`wordpress-content.yml` now conditionally passes `--post_title="{{ item.title }}"` to `wp post update` when `item.title` is defined in the page dict. The Jinja2 conditional block is indented 4 spaces to stay within the YAML block scalar boundary.

`dual-wordpress.yml` `nginx_wordpress_content_pages` expanded from compact flow-map format to multi-line dict with `title:` field for all 10 main site pages.

### Task 2: Theme Cleanup
New task in `wordpress-optimization.yml` inserted before Cache Optimization section:
- Lists all inactive themes via `wp theme list --status=inactive`
- Compares each against `nginx_wordpress_themes_keep` (default: `[kadence]`)
- Deletes themes not in the keep list; logs `DELETED:` prefix
- `changed_when: "'DELETED:' in theme_cleanup.stdout"` — fully idempotent
- Tagged `molecule-notest` — WP-CLI not present in CI Docker image
- Runs for both main site and academy (wordpress-optimization.yml included per site)

### Task 3: MAIN-05 Verification
9 HTML pages in `ansible/roles/nginx_wordpress/files/pages/` contain `.nav-toggle` button markup. `tmt-page-homepage.html` contains `prefers-reduced-motion` CSS. Both committed in Wave 1 (commit 176c764).

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Jinja2 block indentation in YAML block scalar**
- **Found during:** Task 1
- **Issue:** Initial edit placed `{% if %}` / `{% endif %}` at column 1 (no indent), breaking YAML block scalar parsing. Existing `{% if item.wp_current_slug %}` in the same task uses 4-space indent.
- **Fix:** Re-applied with 4-space indent matching the surrounding shell content indentation.
- **Files modified:** ansible/roles/nginx_wordpress/tasks/wordpress-content.yml
- **Commit:** 758fd70

## Known Stubs

None. All 10 title fields are populated with real SEO strings. Theme cleanup is fully wired to the `nginx_wordpress_themes_keep` variable.

## Self-Check: PASSED
