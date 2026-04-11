---
phase: 08-wordpress-site-quality-main-site-pages-academy-visual-parity
verified: 2026-04-11T00:00:00Z
status: passed
score: 7/7 must-haves verified
re_verification: false
gaps: []
human_verification:
  - test: "Run dual-wordpress.yml against a test academy site with sfwd-lms.4.25.7.1.zip placed at ansible/roles/nginx_wordpress/files/plugins/"
    expected: "LearnDash Pro is installed and activated via WP-CLI on the academy site"
    why_human: "ZIP file not committed to repo (by design); CI cannot test the install task (molecule-notest tag)"
  - test: "Run dual-wordpress.yml against the main site and confirm page titles appear correctly in browser tab and Google search snippet"
    expected: "All 10 pages show their SEO title (e.g. 'Cursos de Trading | Two Minds Trading') in browser tab and source <title> tag"
    why_human: "WP-CLI post update executes on live server; cannot verify rendered output without running against production"
  - test: "Run wordpress-optimization.yml against a site with an inactive non-kadence theme installed"
    expected: "Theme is deleted; subsequent run shows changed=false"
    why_human: "Theme cleanup task has molecule-notest; WP-CLI not available in CI Docker image"
---

# Phase 08: WordPress Site Quality Verification Report

**Phase Goal:** Improve WordPress site quality — fix mobile nav on all secondary pages, add SEO post_title to content deployment, add LearnDash ZIP install automation, and add theme cleanup. Both sites (main + academy) benefit via the include_role pattern.
**Verified:** 2026-04-11
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | LearnDash Pro ZIP can be installed on academy via Ansible automation | VERIFIED | `wordpress-plugins-zip.yml` exists (52 lines, 5 tasks); wired in `main.yml` line 51-57; academy declares `sfwd-lms.4.25.7.1.zip` in `dual-wordpress.yml` line 134-135 |
| 2 | The role deploys tmt-perf.php and force-gd.php unconditionally (no site-name gate) | VERIFIED | `configure.yml` line 405: force-gd.php deploys to `nginx_wordpress_web_root` with no `when:` site filter; `wordpress-mu-plugins.yml` line 20-27: tmt-perf.php same pattern |
| 3 | All 10 main site pages have correct SEO post_title set via WP-CLI | VERIFIED | `wordpress-content.yml` lines 51-53: Jinja2 `{% if item.title is defined %}` adds `--post_title`; `dual-wordpress.yml` has exactly 10 entries with "Two Minds Trading" in title (grep count = 10) |
| 4 | Inactive themes are removed on both sites, keeping only kadence | VERIFIED | `wordpress-optimization.yml` lines 221-242: theme cleanup task with shell loop, `nginx_wordpress_themes_keep`, `changed_when: "'DELETED:' in theme_cleanup.stdout"`, runs per-site via shared role |
| 5 | wordpress-content.yml supports --post_title when item.title is defined | VERIFIED | Jinja2 conditional at lines 51-53 in `wordpress-content.yml`; does not modify behavior when `title:` absent (backward compatible) |
| 6 | At least 9 HTML pages have .nav-toggle button markup | VERIFIED | 9 of 12 HTML files contain `nav-toggle` (commit 176c764); the 3 without it are pure Gutenberg block files (sobre-nosotros, inicio-4, registro-de-estudiante-4) that rely on Kadence theme nav — architecturally correct |
| 7 | homepage HTML has prefers-reduced-motion CSS | VERIFIED | `tmt-page-homepage.html`: 6 matches for `prefers-reduced-motion` |

**Score:** 7/7 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ansible/roles/nginx_wordpress/tasks/wordpress-plugins-zip.yml` | ZIP plugin install automation | VERIFIED | 52 lines, 5 tasks: stat, mkdir, copy, shell install, cleanup. FQCN modules. `set -euo pipefail`. Idempotency via `plugin is-installed` check. Commit d747c4b. |
| `ansible/roles/nginx_wordpress/files/plugins/.gitignore` | Prevent ZIP files from being committed | VERIFIED | Contains `*.zip` |
| `ansible/roles/nginx_wordpress/tasks/main.yml` | Wires wordpress-plugins-zip.yml | VERIFIED | Line 51-57: `include_tasks: wordpress-plugins-zip.yml` with conditional on `nginx_wordpress_plugins_zip | default([]) | length > 0` |
| `ansible/roles/nginx_wordpress/defaults/main.yml` | New default variables | VERIFIED | Line 212: `nginx_wordpress_plugins_zip: []`; Line 213-214: `nginx_wordpress_themes_keep: [kadence]` |
| `ansible/playbooks/dual-wordpress.yml` | Academy LearnDash ZIP + 10 page titles | VERIFIED | Lines 134-135: `sfwd-lms.4.25.7.1.zip` in academy vars; Lines 67-89: 10 content pages with `title:` fields |
| `ansible/roles/nginx_wordpress/tasks/wordpress-content.yml` | --post_title conditional | VERIFIED | Lines 51-53: Jinja2 `{% if item.title is defined %}` guard with correct 4-space indent inside block scalar |
| `ansible/roles/nginx_wordpress/tasks/wordpress-optimization.yml` | Theme cleanup task | VERIFIED | Lines 221-242: shell loop over inactive themes, excludes `nginx_wordpress_themes_keep`, `changed_when`, `molecule-notest` tag |

---

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `main.yml` | `wordpress-plugins-zip.yml` | `include_tasks` with `plugins_zip` length condition | WIRED | Line 51-57 confirmed |
| `dual-wordpress.yml` (academy vars) | `nginx_wordpress_plugins_zip` | `sfwd-lms` entry in vars block | WIRED | Lines 134-135 inside academy vars block (before `tags:` line 136) |
| `dual-wordpress.yml` (main vars) | `wordpress-content.yml` | `nginx_wordpress_content_pages` with `title:` field | WIRED | 10 entries with `title:` field; role picks up variable via include_role |
| `wordpress-optimization.yml` | `nginx_wordpress_themes_keep` | shell loop excludes kept themes | WIRED | Line 224 uses `nginx_wordpress_themes_keep | default(['kadence'])` |

---

### Data-Flow Trace (Level 4)

Not applicable — this phase produces Ansible task files, not components that render dynamic data. The data flow is: Ansible variable → WP-CLI command → WordPress DB. The WP-CLI commands contain real operations (plugin install, post update, theme delete), not static returns.

---

### Behavioral Spot-Checks

Step 7b: SKIPPED — no runnable entry points. Ansible playbooks require a live Hetzner target and vault credentials. The relevant tasks are tagged `molecule-notest` for CI.

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| ACAD-01 | 08-01 | WordPress instalado con Kadence theme + Kadence Blocks | ALREADY SATISFIED (pre-phase) | Marked `[x]` in REQUIREMENTS.md. Phase 08 adds automation that supports re-deployment idempotently. |
| ACAD-02 | 08-01 | LearnDash Pro instalado (subir ZIP vía wp-admin) | ENHANCED | Marked `[x]` in REQUIREMENTS.md (manual install). Phase 08 adds Ansible ZIP automation (`wordpress-plugins-zip.yml`) for repeatable installs. |
| MAIN-01 | 08-02 | WordPress instalado con Kadence theme (libre) + Kadence Blocks | ALREADY SATISFIED (pre-phase) | Marked `[x]` in REQUIREMENTS.md. |
| MAIN-04 | 08-02 | Páginas reconstruidas en Kadence Blocks | ENHANCED | Marked `[x]` in REQUIREMENTS.md. Phase 08 adds SEO `post_title` and ensures pages are re-deployable with correct titles. |
| MAIN-05 | 08-02 | Google Fonts configurado como "Local" en Kadence | REQUIREMENT MISMATCH | REQUIREMENTS.md defines MAIN-05 as "Google Fonts local" (already `[x]`). The PLAN repurposed MAIN-05 to cover "mobile nav" work. The actual mobile nav HTML files were committed in Wave 1 (commit 176c764). No conflict in the delivered code, but the PLAN's labeling is incorrect vs REQUIREMENTS.md definition. The mobile nav work is real and present; it just maps to MAIN-04 (page quality) rather than MAIN-05. |

**Note on MAIN-05 mismatch:** The PLAN claimed MAIN-05 = mobile hamburger nav. REQUIREMENTS.md defines MAIN-05 = Google Fonts local configuration. Both things exist: the nav is in the HTML files (commit 176c764), and Google Fonts local setting is already `[x]`. There is no missing implementation — only an incorrect requirement ID assignment in the plan. This does not block the phase goal.

---

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| None found | — | — | — | — |

No TODO/FIXME/placeholder/stub patterns found in any of the 7 modified files. All shell tasks use `set -euo pipefail`. `changed_when` defined on all shell tasks. `molecule-notest` applied to tasks that cannot run in CI (ZIP copy, shell installs requiring WP-CLI + live WP).

---

### Human Verification Required

#### 1. LearnDash ZIP Install on Academy

**Test:** Place `sfwd-lms.4.25.7.1.zip` at `ansible/roles/nginx_wordpress/files/plugins/`, then run `ansible-playbook ansible/playbooks/dual-wordpress.yml --tags academy,plugins,zip`
**Expected:** LearnDash Pro (`sfwd-lms`) appears as active in `wp plugin list --path=/var/www/academy.twomindstrading.com`
**Why human:** ZIP file not committed to repo by design; task tagged `molecule-notest`

#### 2. SEO Title Rendering on Main Site

**Test:** Run `ansible-playbook ansible/playbooks/dual-wordpress.yml --tags main,content` and view each page in browser
**Expected:** All 10 pages show their configured SEO title in the `<title>` HTML tag (e.g. "Cursos de Trading | Two Minds Trading")
**Why human:** WP-CLI `post update --post_title` requires a live WordPress install with a seeded DB; cannot verify rendered output programmatically

#### 3. Theme Cleanup Idempotency

**Test:** Run `ansible-playbook ansible/playbooks/dual-wordpress.yml` twice against main and academy sites with a non-kadence inactive theme present on first run
**Expected:** First run: `changed=1` (theme deleted); second run: `changed=0`
**Why human:** Task tagged `molecule-notest`; requires live WordPress with non-kadence theme installed

---

### Gaps Summary

No gaps. All 7 observable truths verified. All artifacts exist, are substantive, and are wired. One requirement ID mismatch was noted (MAIN-05 label in plan does not match REQUIREMENTS.md definition) but does not represent missing implementation — both the mobile nav work and Google Fonts local setting exist and are `[x]` in REQUIREMENTS.md. The phase goal is achieved.

The only outstanding item is the manual step documented in 08-01-SUMMARY.md: the LearnDash Pro ZIP must be placed manually at `ansible/roles/nginx_wordpress/files/plugins/sfwd-lms.4.25.7.1.zip` before running the academy deployment. This is expected (commercial license restriction) and documented.

---

_Verified: 2026-04-11_
_Verifier: Claude (gsd-verifier)_
