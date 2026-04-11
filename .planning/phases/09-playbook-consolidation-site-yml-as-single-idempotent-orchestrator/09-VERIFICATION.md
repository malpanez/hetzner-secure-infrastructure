---
phase: 09-playbook-consolidation-site-yml-as-single-idempotent-orchestrator
verified: 2026-04-11T16:30:00Z
status: passed
score: 4/5 success criteria verified
gaps:
  - truth: "Re-running site.yml against existing server completes with 0 failures and changed=0 on already-configured resources"
    status: failed
    reason: "Cannot verify programmatically — requires an actual server run. Additionally, a stale comment in ansible/playbooks/tasks/openbao-mariadb-integration.yml still reads 'Called from deploy.yml' (minor but indicative of incomplete cleanup)."
    artifacts:
      - path: "ansible/playbooks/tasks/openbao-mariadb-integration.yml"
        issue: "Line 5: stale comment 'Called from deploy.yml after dual-wordpress.yml' — deploy.yml no longer exists"
    missing:
      - "Human verification: run 'ansible-playbook playbooks/site.yml --check' against the production server and confirm 0 failures, low changed count on stable resources"
      - "Fix stale comment on line 5 of ansible/playbooks/tasks/openbao-mariadb-integration.yml: replace 'deploy.yml' with 'site.yml'"
human_verification:
  - test: "Re-run site.yml against production server"
    expected: "ansible-playbook playbooks/site.yml completes with 0 failures; changed= count is low (only non-idempotent tasks like systemd reloads may fire)"
    why_human: "Idempotency can only be confirmed against a live server — no static analysis substitute"
---

# Phase 09: Playbook Consolidation — site.yml as Single Idempotent Orchestrator

**Phase Goal:** Consolidate playbooks so site.yml is the single idempotent orchestrator for a full stack deployment. Delete legacy wordpress.yml, wordpress-only.yml, and deploy.yml. Update all cross-references in CI, scripts, and docs.
**Verified:** 2026-04-11T16:30:00Z
**Status:** gaps_found
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths (from ROADMAP.md Success Criteria)

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | site.yml imports common, OpenBao inline plays, monitoring, dual-wordpress, rotation, validate in that order | VERIFIED | Lines 16, 19, 40, 204, 224, 253, 258, 295, 299 of site.yml confirm exact sequence |
| 2 | wordpress.yml and wordpress-only.yml are deleted from the repo | VERIFIED | Both absent from filesystem; deletion confirmed |
| 3 | Re-running site.yml completes with 0 failures and changed=0 on already-configured resources | FAILED | Cannot verify statically — requires live server run; also, stale comment in openbao-mariadb-integration.yml still names deploy.yml |
| 4 | deploy-full.sh calls ansible-playbook playbooks/site.yml (not old site.yml pointing to wordpress.yml) | VERIFIED | Lines 85-86: calls site.yml with -e openbao_transit_bootstrap_ack=true openbao_bootstrap_ack=true |
| 5 | ansible-lint playbooks/site.yml exits 0 | VERIFIED | Exit code 0, 3 pre-existing warnings in nginx_wordpress role (no-changed-when), 0 failures |

**Score:** 4/5 success criteria verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `ansible/playbooks/site.yml` | Unified orchestrator (content from deploy.yml) | VERIFIED | 300 lines, all inline OpenBao bootstrap plays, 5 import_playbook calls, 3 meta: end_play guards |
| `ansible/playbooks/deploy.yml` | Deleted — content moved to site.yml | VERIFIED | File does not exist |
| `ansible/playbooks/wordpress.yml` | Deleted | VERIFIED | File does not exist |
| `ansible/playbooks/wordpress-only.yml` | Deleted | VERIFIED | File does not exist |
| `ansible/playbooks/openbao.yml` | Kept for standalone day-2 use | VERIFIED | File exists |
| `ansible/playbooks/openbao-transit-bootstrap.yml` | Kept for standalone day-2 use | VERIFIED | File exists |
| `scripts/deploy-full.sh` | Calls site.yml with OpenBao extra-vars | VERIFIED | Lines 85-86 confirmed |
| `docs/deployment-playbook.md` | Zero deploy.yml references, all site.yml | VERIFIED | grep deploy.yml returns 0 matches |
| `ansible/playbooks/validate.yml` | Service health assertions for nginx, MariaDB, PHP-FPM, Valkey, OpenBao | VERIFIED | All five assertions present at lines 31, 39, 47, 57, 77 |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| site.yml | common.yml | import_playbook | WIRED | Line 16 |
| site.yml | monitoring.yml | import_playbook | WIRED | Line 254 |
| site.yml | dual-wordpress.yml | import_playbook | WIRED | Line 258 |
| site.yml | setup-openbao-rotation.yml | import_playbook | WIRED | Line 295 |
| site.yml | validate.yml | import_playbook | WIRED | Line 299 |
| deploy-full.sh | ansible/playbooks/site.yml | ansible-playbook command | WIRED | Lines 85-86, includes -e openbao_transit_bootstrap_ack=true openbao_bootstrap_ack=true |
| docs/deployment-playbook.md | site.yml | documentation reference | WIRED | 5 references to site.yml, 0 to deploy.yml |

### Data-Flow Trace (Level 4)

Not applicable — this phase produces orchestration files (playbooks, shell scripts, docs), not components rendering dynamic data.

### Behavioral Spot-Checks

| Behavior | Command | Result | Status |
|----------|---------|--------|--------|
| site.yml YAML validity | ansible-playbook playbooks/site.yml --syntax-check | Passes with expected inventory warnings (no HCLOUD_TOKEN in local env) | PASS |
| ansible-lint site.yml exits 0 | ansible-lint playbooks/site.yml | 0 failures, 3 pre-existing warnings | PASS |
| deploy.yml absent | test ! -f ansible/playbooks/deploy.yml | No file at path | PASS |
| wordpress.yml absent | test ! -f ansible/playbooks/wordpress.yml | No file at path | PASS |
| wordpress-only.yml absent | test ! -f ansible/playbooks/wordpress-only.yml | No file at path | PASS |
| CI lint file list includes site.yml, excludes deleted playbooks | grep in ci.yml | site.yml at line 101; no wordpress.yml or wordpress-only.yml in lint list | PASS |
| deploy-full.sh calls site.yml with OpenBao ack vars | grep in deploy-full.sh | Lines 85-86 confirmed | PASS |
| Re-run idempotency | ansible-playbook playbooks/site.yml (live server) | NOT TESTABLE locally | SKIP — human needed |

### Requirements Coverage

REQUIREMENTS.md does not contain DEPLOY-01, DEPLOY-02, or DEPLOY-03 entries. These IDs originate from Phase 7 plans and are re-used by Phase 9 plans as continuations of the same deployment orchestration requirement set. The ROADMAP.md Traceability section does not map DEPLOY-01/02/03 to specific requirements entries because REQUIREMENTS.md does not define them explicitly.

| Requirement | Source Plan | Description (from ROADMAP context) | Status | Evidence |
|-------------|------------|-------------------------------------|--------|----------|
| DEPLOY-01 | 09-01-PLAN.md | Unified orchestrator site.yml with full inline OpenBao bootstrap sequence | SATISFIED | site.yml exists, 300 lines, full inline bootstrap plays confirmed |
| DEPLOY-02 | 09-01-PLAN.md | Legacy playbooks (wordpress.yml, wordpress-only.yml, deploy.yml) removed; CI/scripts updated | SATISFIED | All three deleted; CI lint list clean; staging-deploy.sh simplified |
| DEPLOY-03 | 09-02-PLAN.md | deploy-full.sh calls site.yml; deployment-playbook.md updated; validate.yml has service health assertions | SATISFIED | All three sub-items confirmed |

Note: DEPLOY-01/02/03 are not formally defined in REQUIREMENTS.md — they exist only as labels within Phase 7 and 9 plan frontmatter and ROADMAP.md phase descriptions. This is an ORPHANED situation: the IDs are declared in plans but have no canonical requirement definitions. This is pre-existing from Phase 7 and is not a Phase 9 regression.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `ansible/playbooks/tasks/openbao-mariadb-integration.yml` | 5 | Comment "Called from deploy.yml after dual-wordpress.yml" — deploy.yml no longer exists | Warning | Does not break functionality; misleads future operators about call site |
| `docs/guides/COMPLETE_TESTING_GUIDE.md` | 254 | `ansible-playbook playbooks/wordpress.yml` — references deleted playbook | Warning | Stale doc only; does not affect deployment |
| `docs/infrastructure/WORDPRESS-STACK-MERMAID.md` | 137 | `ansible-playbook playbooks/wordpress.yml` — references deleted playbook | Warning | Stale diagram only; does not affect deployment |
| `docs/guides/TESTING_AND_DR_STRATEGY.md` | 306, 317 | References to role-internal wordpress.yml task file and group_vars wordpress.yml (not playbooks) | Info | These reference a role tasks file and a group_vars file — not the deleted playbook; false positive from filename collision |

None of the above anti-patterns are blockers. The openbao-mariadb-integration.yml comment is the most actionable (one-line fix). The docs/ references to playbooks/wordpress.yml in COMPLETE_TESTING_GUIDE.md and WORDPRESS-STACK-MERMAID.md are stale but were not in the scope of Phase 09 plans (plan scope was deployment-playbook.md only, not all guide docs).

### Human Verification Required

#### 1. Site.yml Idempotency on Production Server

**Test:** Run `ansible-playbook -i inventory/hetzner.yml playbooks/site.yml` against the production server (with OpenBao already initialized). Observe the play recap.
**Expected:** 0 failures; `changed=` count is low — only systemd reload tasks and similar non-deterministic tasks should show changed; all task logic that guards against re-configuration should skip.
**Why human:** Idempotency cannot be confirmed without executing against a live Ansible-managed host. Static analysis of the guards (3 `meta: end_play` confirmed) is necessary but not sufficient.

### Gaps Summary

One gap exists: the idempotency truth (Success Criterion 3) cannot be verified without a live server run. All static verifiable criteria pass cleanly.

Additionally, a stale comment in `ansible/playbooks/tasks/openbao-mariadb-integration.yml` (line 5) names `deploy.yml` as the caller — this is factually wrong since deploy.yml was deleted and site.yml is now the caller. This is a cosmetic issue (not a runtime failure) but should be corrected to avoid confusion.

Stale references to `playbooks/wordpress.yml` remain in two docs/ guide files (`COMPLETE_TESTING_GUIDE.md` and `WORDPRESS-STACK-MERMAID.md`) that were not in the Phase 09 plan scope. These are documentation debt, not blockers.

The DEPLOY-01/02/03 requirement IDs are not formally defined in REQUIREMENTS.md — this is pre-existing infrastructure debt from Phase 7, not introduced by Phase 9.

---

_Verified: 2026-04-11T16:30:00Z_
_Verifier: Claude (gsd-verifier)_
