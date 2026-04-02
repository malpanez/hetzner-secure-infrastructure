---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed Phase 07 Plan 02 — deployment-playbook.md rewritten for deploy.yml 3-step workflow
last_updated: "2026-04-02T19:00:00.028Z"
last_activity: 2026-04-02
progress:
  total_phases: 8
  completed_phases: 4
  total_plans: 13
  completed_plans: 10
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-28)

**Core value:** Un alumno puede descubrir cursos en el main site, comprar en academy, y aprender sin fricciones — con <2s LCP y sin riesgo de perder datos.
**Current focus:** Phase 07 — unified-deploy-yml-orchestrator

## Current Position

Phase: 07
Plan: Not started
Status: Ready to execute
Last activity: 2026-04-02

Progress: [░░░░░░░░░░] 0%

## Performance Metrics

**Velocity:**

- Total plans completed: 0
- Average duration: -
- Total execution time: -

**By Phase:**

| Phase | Plans | Total | Avg/Plan |
|-------|-------|-------|----------|
| - | - | - | - |

**Recent Trend:**

- Last 5 plans: -
- Trend: -

*Updated after each plan completion*
| Phase 01-iac-refactor P04 | 2 | 1 tasks | 1 files |
| Phase 01-iac-refactor P01 | 3 | 2 tasks | 5 files |
| Phase 01-iac-refactor P03 | 4 | 1 tasks | 1 files |
| Phase 01-iac-refactor P02 | 2min | 2 tasks | 2 files |
| Phase 02-testing-validation P01 | 55 | 2 tasks | 5 files |
| Phase 02-testing-validation P02 | 120 | 2 tasks | 18 files |
| Phase 07-unified-deploy-yml-orchestrator P02 | 2min | 1 tasks | 1 files |

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Planning: `include_role` x2 approach chosen over `wordpress_instances` loop (4-5 file changes vs 45+)
- Planning: FastCGI cache path must be per-vhost — moved from `conf.d/` into `wordpress.conf.j2` (ROLE-05 critical)
- Planning: Valkey DB 0 (main) / DB 1 (academy) with distinct prefixes — prevents object cache key collisions
- Planning: terraform destroy + apply chosen over surgical approach (clean slate, binary logging from day one)
- [Phase 01-iac-refactor]: proxied=true for academy A record — consistent with all other A records, enables CDN + DDoS protection
- [Phase 01-iac-refactor]: 01-01: nginx_wordpress_site_name defaults to 'wordpress' for backward compat; fastcgi_cache_path moved to per-vhost wordpress.conf.j2; php_version corrected to 8.3 (Debian 13 production)
- [Phase 01-iac-refactor]: 01-03: WP_CACHE set unconditionally true — redis-cache plugin is mandatory in the role; | default() filters retained in template as safety net
- [Phase 01-iac-refactor]: 01-02: Main site reuses existing vault_nginx_wordpress_*salts; academy gets independent vault_wp_academy_* vars
- [Phase 01-iac-refactor]: 01-02: secrets.yml.example force-committed with git add -f — .example files are documentation despite *secret* gitignore
- [Phase 02-testing-validation]: PHP 8.4 used in molecule (not 8.3) — Debian 13 container ships 8.4 natively; production continues to use PHP 8.3 via sury.org
- [Phase 02-testing-validation]: changed_when: false on apt update pre_task in converge.yml — no cache_valid_time per CLAUDE.md constraint; suppression correct for idempotency
- [Phase 02-testing-validation]: 02-02: ansible-lint pre-commit needs additional_dependencies: ansible-core>=2.13.3,<2.17 to avoid 2.18+ which removed ansible.parsing.yaml.constructor
- [Phase 02-testing-validation]: 02-02: trivy, kics, terraform-docs, tflint-hcloud-plugin in ci.skip — not installed; system ansible-lint (6.17.2) used directly instead of pre-commit hook
- [Phase 02-testing-validation]: 02-02: ansible-lint full-tree scan times out under system load; scan via playbook entrypoint exits 0 and covers all first-party code
- [Phase 07-unified-deploy-yml-orchestrator]: 07-02: Old 10-step manual sequence removed — deploy.yml handles full sequence automatically with two credential-saving pauses

### Pending Todos

- Complete OpenBao secret coverage and rotation — academy scripts, Grafana/exporter/SMTP/Stripe in KV, static credentials MOTD
- Migrate Promtail to Grafana Alloy — Promtail removed from Loki 3.x, use grafana.grafana.alloy role with River syntax scrape config

### Roadmap Evolution

- Phase 6 added: Complete OpenBao secret coverage and rotation — academy scripts, Grafana/exporter/SMTP/Stripe in KV, static credentials MOTD
- Phase 7 added: Unified deploy.yml orchestrator — single-command fresh deployment with auto-pause checkpoints for OpenBao transit and primary initialization

### Blockers/Concerns

- [Phase 3] OpenBao transit (8201) requires manual unseal with 3 of 5 key shares before primary (8200) starts — key shares must be available at rebuild time. See docs/openbao_unseal_procedure.md.
- [Phase 5] LearnDash Pro requires manual ZIP install via wp-admin — cannot be automated. License must be available.
- [Phase 5] WooCommerce HPOS + LearnDash WC Integration compatibility is MEDIUM confidence — check plugin GitHub issues before enabling HPOS.

## Session Continuity

Last session: 2026-04-02T18:50:56.819Z
Stopped at: Completed Phase 07 Plan 02 — deployment-playbook.md rewritten for deploy.yml 3-step workflow
Resume file: None
