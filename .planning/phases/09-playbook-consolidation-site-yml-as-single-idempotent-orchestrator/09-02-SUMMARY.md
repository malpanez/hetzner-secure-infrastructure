---
phase: 09-playbook-consolidation-site-yml-as-single-idempotent-orchestrator
plan: 02
subsystem: infra
tags: [ansible, site.yml, deploy-full, validate, openbao, service-health]

requires:
  - phase: 09-01
    provides: site.yml as unified orchestrator, deploy.yml deleted

provides:
  - deploy-full.sh calls site.yml with OpenBao bootstrap extra-vars
  - docs/deployment-playbook.md fully aligned to site.yml (zero deploy.yml references)
  - validate.yml service health assertions for nginx, MariaDB, PHP-FPM, Valkey, OpenBao

affects: [phase-03-server-rebuild, phase-10-operations]

tech-stack:
  added: []
  patterns:
    - "Service health assertions use ansible.builtin.service_facts + ansible.builtin.assert per host group"
    - "failed_when: false on soft-assert tasks (PHP-FPM, Valkey) — prevents failure on name ambiguity"

key-files:
  created: []
  modified:
    - scripts/deploy-full.sh
    - docs/deployment-playbook.md
    - ansible/playbooks/validate.yml

key-decisions:
  - "terraform-output.json workaround removed from deploy-full.sh — hcloud dynamic inventory does not use it"
  - "Legacy 2FA next-steps replaced with operational verification steps (bao status, systemctl list-timers)"
  - "PHP-FPM and Valkey health assertions use failed_when: false — service name varies by install method"

patterns-established:
  - "validate.yml structure: service health plays first (per host group), then full deployment summary"

requirements-completed: [DEPLOY-03]

duration: 10min
completed: 2026-04-11
---

# Phase 09 Plan 02: Playbook Consolidation — Shell, Docs, Validation Alignment Summary

**deploy-full.sh now calls site.yml with OpenBao bootstrap extra-vars, deployment-playbook.md has zero deploy.yml references, and validate.yml adds service health assertions for nginx, MariaDB, PHP-FPM, Valkey, and OpenBao**

## Performance

- **Duration:** 10 min
- **Started:** 2026-04-11T15:40:00Z
- **Completed:** 2026-04-11T15:50:00Z
- **Tasks:** 3
- **Files modified:** 3

## Accomplishments

- deploy-full.sh cleaned up: calls site.yml with `-e openbao_transit_bootstrap_ack=true openbao_bootstrap_ack=true`, removed stale terraform-output.json workaround, replaced legacy 2FA next-steps with operational verification steps
- docs/deployment-playbook.md updated: all three deploy.yml occurrences replaced with site.yml (Step 3 command, description paragraph, Re-runs section)
- validate.yml extended: two new plays prepended — wordpress_servers health checks (nginx, MariaDB, PHP-FPM, Valkey) and secrets_servers health check (openbao.service)

## Task Commits

1. **Task 1: Update deploy-full.sh to call site.yml with OpenBao extra-vars** - `f164436` (feat)
2. **Task 2: Update deployment-playbook.md to reference site.yml** - `ada48ce` (docs)
3. **Task 3: Add service health assertions to validate.yml** - `b136cec` (feat)

## Files Created/Modified

- `scripts/deploy-full.sh` - now calls site.yml with OpenBao bootstrap extra-vars; terraform-output.json workaround removed; next-steps cleaned up
- `docs/deployment-playbook.md` - all deploy.yml references replaced with site.yml
- `ansible/playbooks/validate.yml` - service health plays for wordpress_servers and secrets_servers prepended before existing summary play

## Decisions Made

- `terraform-output.json` workaround removed: hcloud dynamic inventory (`inventory/hetzner.yml`) reads directly from the Hetzner API via hcloud plugin — the JSON file is not needed
- PHP-FPM and Valkey assertions use `failed_when: false` because service name varies (php-fpm-main vs php8.4-fpm, valkey vs valkey-server) — soft assertions that warn without blocking the run
- Legacy setup-2fa-yubikey.sh next-step removed from deploy-full.sh — SSH 2FA is handled by the ssh_2fa role in site.yml, not a post-run manual script

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

`python3 -c "import yaml"` failed (PyYAML not installed in WSL environment). Used `ansible-playbook --syntax-check` instead to validate YAML — equivalent verification, passes with expected inventory warnings due to missing HCLOUD_TOKEN in local environment.

## Next Phase Readiness

- Phase 09 complete: site.yml is the canonical orchestrator, all tooling (deploy-full.sh, docs, validate.yml) aligned
- Ready for Phase 10 (operations) or Phase 03 (server rebuild) — deploy-full.sh is the single command for a fresh deployment

---
*Phase: 09-playbook-consolidation-site-yml-as-single-idempotent-orchestrator*
*Completed: 2026-04-11*
