---
phase: 02
phase_name: Testing & Validation
created: 2026-03-28
mode: auto
---

# Phase 02: Testing & Validation — Context

## Phase Goal

The refactored role passes Molecule tests and the entire codebase is lint-clean on the
feature branch, confirming the IaC changes are safe to run against a real server.

## Canonical Refs

- `.planning/REQUIREMENTS.md` — TEST-01, TEST-02 acceptance criteria
- `.planning/ROADMAP.md` — Phase 2 success criteria
- `ansible/roles/nginx_wordpress/molecule/default/` — existing Molecule scenario
- `CLAUDE.md` — yamllint max 250 chars, ansible-lint production profile, pre-commit hooks

## Decisions

### Branch Strategy

**Decision:** Run all tests on `main` branch.

`branching_strategy: "none"` is set in config.json. All Phase 1 changes (role refactor, playbook,
Terraform DNS, wp-config Redis) were committed directly to `main`. There is no
`feature/dual-wordpress` branch. The ROADMAP mention of that branch reflects the original
planning intent but is superseded by the project config. Tests run against the current `main`.

### Molecule Scenario Scope

**Decision:** Single-instance test only — the Molecule scenario tests the role with
`nginx_wordpress_site_name: wordpress` (the backward-compatible default).

The existing `molecule/default/converge.yml` uses `role: nginx_wordpress` without setting
`site_name`. It will use the default `"wordpress"`, which is correct for single-site
verification. A dual-invocation Molecule scenario (testing two include_role calls) is
Phase 3+ work — not required to pass Phase 2 success criteria.

**Required converge.yml update:** Add `nginx_wordpress_site_name: wordpress` explicitly to
molecule.yml host_vars to document intent and prevent ambiguity. This is the ONLY
molecule file change needed unless existing tasks fail.

### ansible-lint Profile

**Decision:** `production` profile, matching REQUIREMENTS.md TEST-02 and CLAUDE.md.
Run: `ansible-lint --profile production .` from the repo root.

### pre-commit Scope

**Decision:** `pre-commit run --all-files` — run all hooks against all files.
This matches the TEST-02 success criterion verbatim.
If pre-commit environment is locked, clear the lock file before running.

### Terraform Validation

**Decision:** `terraform validate && terraform fmt -check -recursive` in
`terraform/` directory. Already confirmed passing in Phase 1 spot-check (Wave 1).
Include it again to satisfy TEST-02 success criteria formally.

### Fix Strategy

**Decision:** Fix issues in-place on `main`. Each fix is a separate commit with
conventional commit format. Do not revert Phase 1 changes — fix forward only.

## Specifics

- PHP-FPM socket path changed from `php8.3-fpm.sock` to `php8.3-wordpress-fpm.sock`
  (when site_name=wordpress). Both pool conf and vhost templates are updated consistently,
  so `nginx -t` should pass without manual socket pre-creation.
- The Molecule verify.yml checks `/var/www/html` — this may be a pre-existing test that
  uses the default `nginx_wordpress_web_root`. If it fails, update the verify assertion
  to use `/var/www/wordpress` (the role's actual default). Do not change the role default.
- `secrets.yml.example` was force-committed with `git add -f` in Phase 1 (gitignored by
  `*secret*` pattern). Do not re-add to .gitignore — it's intentional documentation.

## Deferred Ideas

None surfaced in auto mode.
