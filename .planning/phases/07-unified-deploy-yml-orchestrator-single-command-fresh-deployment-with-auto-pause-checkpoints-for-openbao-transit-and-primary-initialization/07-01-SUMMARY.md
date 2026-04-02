---
phase: 07-unified-deploy-yml-orchestrator
plan: 01
subsystem: infra
tags: [ansible, openbao, orchestrator, deploy, playbook]

requires:
  - phase: 01-iac-refactor
    provides: dual-wordpress.yml, nginx_wordpress role refactored for two sites
  - phase: 02-testing-validation
    provides: ansible-lint and molecule passing for all roles

provides:
  - Unified deploy.yml orchestrator — single-command full stack deployment
  - Safe default for vault_openbao_transit_token in security.yml (prevents inventory load failure)
  - Inline transit bootstrap play with auto-pause on fresh initialization
  - Inline primary bootstrap play with auto-pause on fresh initialization
  - Rotation token placement pause conditioned on openbao_wordpress_token fact

affects:
  - 07-02 (validate.yml and any follow-on plans that run deploy.yml)

tech-stack:
  added: []
  patterns:
    - "Two-pass openbao role application: first pass without transit token to install/start service, second pass with token to configure transit seal"
    - "Inline bootstrap plays with meta: end_play for idempotent re-runs"
    - "Conditional pause using when: fact is defined — pauses only on fresh initialization, skipped on re-runs"

key-files:
  created:
    - ansible/playbooks/deploy.yml
  modified:
    - ansible/inventory/group_vars/hetzner/security.yml

key-decisions:
  - "Two-pass openbao role: first pass with openbao_transit_enabled: false installs binaries and starts transit service; second pass with transit token reconfigures primary with auto-unseal seal block"
  - "deploy_transit_token fact exported from transit bootstrap play and consumed by second openbao role pass, falling back to vault_openbao_transit_token for day-2 re-runs"
  - "Pause conditioned on fact existence (transit_init is defined, openbao_init is defined) — ensures pauses only appear on fresh init, never on idempotent re-runs"
  - "import_playbook kept for common/monitoring/dual-wordpress/rotation/validate — preserves independent runnability for day-2 ops"

requirements-completed:
  - DEPLOY-01
  - DEPLOY-02

duration: 15min
completed: 2026-04-02
---

# Phase 07 Plan 01: Unified Deploy Orchestrator Summary

**deploy.yml single-command orchestrator with conditional OpenBao bootstrap pauses, two-pass openbao role application, and safe vault_openbao_transit_token default**

## Performance

- **Duration:** 15 min
- **Started:** 2026-04-02T00:00:00Z
- **Completed:** 2026-04-02T00:15:00Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments

- Created deploy.yml encoding the full 9-step deployment sequence in correct order
- Transit and primary bootstrap pauses only trigger on fresh initialization (fact-conditioned)
- Re-running deploy.yml on an already-deployed server produces no pauses and is idempotent
- Prevented Ansible inventory load failure on fresh deploy by adding `| default('')` to vault_openbao_transit_token

## Task Commits

1. **Task 1: Add safe default for vault_openbao_transit_token** - `248dae3` (fix)
2. **Task 2: Create unified deploy.yml orchestrator** - `d668941` (feat)

## Files Created/Modified

- `ansible/playbooks/deploy.yml` - Unified orchestrator with 10 plays: common import, openbao install (no transit), transit bootstrap with pause, openbao redeploy with transit, primary bootstrap with pause, monitoring import, dual-wordpress import, rotation token placement pause, rotation import, validate import
- `ansible/inventory/group_vars/hetzner/security.yml` - `openbao_transit_token` now uses `| default('')` filter to prevent inventory load failure on fresh deploys

## Decisions Made

- Two-pass openbao role: first with `openbao_transit_enabled: false` to install without transit seal block, second with token to apply transit auto-unseal configuration
- `deploy_transit_token` set_fact after transit bootstrap exports runtime-captured token; consumed by second pass, with fallback to `vault_openbao_transit_token` for day-2 re-runs
- `meta: end_play` in pre_tasks of transit bootstrap and token-guarded skip in second pass enable fully idempotent re-runs
- Monitoring runs before WordPress so Prometheus is up before scraping begins

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness

- deploy.yml is ready for use in Phase 07 Plan 02 (validate.yml review) and full stack rebuild
- Operator runs: `ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/deploy.yml -e "openbao_transit_bootstrap_ack=true openbao_bootstrap_ack=true" --ask-vault-pass`

---
*Phase: 07-unified-deploy-yml-orchestrator*
*Completed: 2026-04-02*
