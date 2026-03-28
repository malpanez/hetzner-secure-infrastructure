# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-28)

**Core value:** Un alumno puede descubrir cursos en el main site, comprar en academy, y aprender sin fricciones — con <2s LCP y sin riesgo de perder datos.
**Current focus:** Phase 1 — IaC Refactor

## Current Position

Phase: 1 of 5 (IaC Refactor)
Plan: 0 of 4 in current phase
Status: Ready to plan
Last activity: 2026-03-28 — Roadmap created, STATE initialized

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

## Accumulated Context

### Decisions

Decisions are logged in PROJECT.md Key Decisions table.
Recent decisions affecting current work:

- Planning: `include_role` x2 approach chosen over `wordpress_instances` loop (4-5 file changes vs 45+)
- Planning: FastCGI cache path must be per-vhost — moved from `conf.d/` into `wordpress.conf.j2` (ROLE-05 critical)
- Planning: Valkey DB 0 (main) / DB 1 (academy) with distinct prefixes — prevents object cache key collisions
- Planning: terraform destroy + apply chosen over surgical approach (clean slate, binary logging from day one)

### Pending Todos

None yet.

### Blockers/Concerns

- [Phase 3] OpenBao transit (8201) requires manual unseal with 3 of 5 key shares before primary (8200) starts — key shares must be available at rebuild time. See docs/openbao_unseal_procedure.md.
- [Phase 5] LearnDash Pro requires manual ZIP install via wp-admin — cannot be automated. License must be available.
- [Phase 5] WooCommerce HPOS + LearnDash WC Integration compatibility is MEDIUM confidence — check plugin GitHub issues before enabling HPOS.

## Session Continuity

Last session: 2026-03-28
Stopped at: Roadmap and STATE created. Ready to begin planning Phase 1.
Resume file: None
