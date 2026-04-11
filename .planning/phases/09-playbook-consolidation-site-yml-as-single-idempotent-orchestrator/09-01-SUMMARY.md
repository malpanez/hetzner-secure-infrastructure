---
phase: 09-playbook-consolidation-site-yml-as-single-idempotent-orchestrator
plan: "01"
subsystem: ansible-playbooks
tags: [playbook-consolidation, site.yml, orchestrator, cleanup]
dependency_graph:
  requires: []
  provides: [unified-site-yml-orchestrator]
  affects: [ci-workflow, staging-deploy-script]
tech_stack:
  added: []
  patterns: [single-entrypoint-orchestrator, import_playbook-chain]
key_files:
  created: []
  modified:
    - ansible/playbooks/site.yml
    - .github/workflows/ci.yml
    - scripts/staging-deploy.sh
    - CLAUDE.md
  deleted:
    - ansible/playbooks/deploy.yml
    - ansible/playbooks/wordpress.yml
    - ansible/playbooks/wordpress-only.yml
decisions:
  - site.yml is the canonical entrypoint — deploy.yml deleted; openbao.yml and openbao-transit-bootstrap.yml kept as standalone day-2 playbooks
metrics:
  duration: "~10min"
  completed: "2026-04-11"
  tasks_completed: 3
  files_modified: 4
  files_deleted: 3
---

# Phase 09 Plan 01: Playbook Consolidation — site.yml as Unified Orchestrator Summary

**One-liner:** Replaced legacy site.yml (simple import chain) with deploy.yml content (full transit+primary OpenBao bootstrap, dual-WordPress, monitoring, rotation, validate sequence) and deleted the now-obsolete deploy.yml, wordpress.yml, and wordpress-only.yml.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Replace site.yml with deploy.yml content, delete legacy playbooks | 11bd040 | site.yml (overwrite), deploy.yml/wordpress.yml/wordpress-only.yml (deleted) |
| 2 | Update cross-references in CI, scripts, and CLAUDE.md | e6aff43 | ci.yml, staging-deploy.sh, CLAUDE.md |
| 3 | Lint validation of consolidated site.yml | (verification only) | — |

## Verification Results

- `test -f ansible/playbooks/site.yml` — PASS
- `! test -f ansible/playbooks/deploy.yml` — PASS
- `! test -f ansible/playbooks/wordpress.yml` — PASS
- `! test -f ansible/playbooks/wordpress-only.yml` — PASS
- `grep -c "import_playbook" ansible/playbooks/site.yml` — 5 (common, monitoring, dual-wordpress, setup-openbao-rotation, validate)
- `grep -c "meta: end_play" ansible/playbooks/site.yml` — 3 (all idempotency guards preserved)
- `ansible-lint playbooks/site.yml` — exit code 0 (0 failures, 3 pre-existing warnings in nginx_wordpress role)
- `yamllint ansible/playbooks/site.yml` — PASS

## Decisions Made

- `deploy.yml` deleted — its content is now `site.yml`. This is the only change to the orchestration logic.
- `openbao.yml` and `openbao-transit-bootstrap.yml` kept — used independently for day-2 operations (re-unseal, token regeneration).
- `staging-deploy.sh` simplified to always use `site.yml` — the wordpress-only.yml option was removed since that file no longer exists.
- `site.yml` now included in the ansible-lint file list in CI (was previously excluded with a comment saying it only calls Galaxy roles — that was the old site.yml; the new one contains substantial custom logic).

## Deviations from Plan

None — plan executed exactly as written.

## Known Stubs

None — no placeholder data or incomplete wiring introduced.

## Self-Check: PASSED

- `ansible/playbooks/site.yml` exists: CONFIRMED
- `ansible/playbooks/deploy.yml` removed: CONFIRMED
- `ansible/playbooks/wordpress.yml` removed: CONFIRMED
- `ansible/playbooks/wordpress-only.yml` removed: CONFIRMED
- Commit 11bd040 exists: CONFIRMED
- Commit e6aff43 exists: CONFIRMED
