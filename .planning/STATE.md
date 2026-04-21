---
gsd_state_version: 1.0
milestone: v1.0
milestone_name: milestone
status: executing
stopped_at: Completed Phase 09.1 Plan 01 — module_defaults + firewall task consolidation
last_updated: "2026-04-21T07:06:37.324Z"
last_activity: 2026-04-21
progress:
  total_phases: 11
  completed_phases: 6
  total_plans: 24
  completed_plans: 17
  percent: 0
---

# Project State

## Project Reference

See: .planning/PROJECT.md (updated 2026-03-28)

**Core value:** Un alumno puede descubrir cursos en el main site, comprar en academy, y aprender sin fricciones — con <2s LCP y sin riesgo de perder datos.
**Current focus:** Phase 09.1 — ansible-roles-optimization-module-defaults-block-consolidation-idiomatic-file-management

## Current Position

Phase: 09.1 (ansible-roles-optimization-module-defaults-block-consolidation-idiomatic-file-management) — EXECUTING
Plan: 2 of 3
Status: Ready to execute
Last activity: 2026-04-21

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
| Phase 07-unified-deploy-yml-orchestrator P03 | 7min | 3 tasks | 3 files |
| Phase 08 P01 | 10 | 2 tasks | 5 files |
| Phase 08 P02 | 5min | 3 tasks | 3 files |
| Phase 09-playbook-consolidation P01 | 10min | 3 tasks | 7 files |
| Phase 09-playbook-consolidation P02 | 10min | 3 tasks | 3 files |
| Phase 03.6 P02 | 10 | 5 tasks | 4 files |
| Phase 03.6 P03 | 45 | 4 tasks | 5 files |
| Phase 09.1 P02 | 20min | 2 tasks | 4 files |
| Phase 09.1 P01 | 20 | 2 tasks | 5 files |

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
- [Phase 07-unified-deploy-yml-orchestrator]: Academy certbot uses Cloudflare DNS-01 with explicit domains — cannot inherit main site letsencrypt_domains
- [Phase 07-unified-deploy-yml-orchestrator]: VAULT_SKIP_VERIFY=1 safe for localhost-only HTTPS communication against self-signed cert
- [Phase 08]: molecule-notest tag applied to ZIP copy and shell tasks — ZIP file not present in CI environment
- [Phase 08]: Idempotency via wp-cli plugin is-installed check before install — changed_when driven by SKIP: prefix in stdout
- [Phase 08]: Jinja2 {% if %} tags indented 4 spaces inside block scalar — matches surrounding shell indent, keeps YAML valid
- [Phase 08]: Theme cleanup uses WP-CLI --status=inactive list + shell loop; molecule-notest tag applied (WP-CLI absent in CI)
- [Phase 09-playbook-consolidation]: site.yml is now the canonical entrypoint — deploy.yml deleted; openbao.yml and openbao-transit-bootstrap.yml kept as standalone day-2 playbooks
- [Phase 09-playbook-consolidation]: terraform-output.json workaround removed from deploy-full.sh — hcloud dynamic inventory reads directly from Hetzner API
- [Phase 09-playbook-consolidation]: validate.yml service health plays use failed_when: false for PHP-FPM and Valkey — service names vary by install method
- [Phase 03.6]: Monitoring ports bound to 127.0.0.1; UFW deny rules added for 9090/9096/9100 (C3)
- [Phase 03.6]: php_admin_flag for allow_url_fopen (boolean flag type); apparmor_profiles uses filenames not binary paths
- [Phase 09.1]: 09.1-02: valkey module_defaults keeps state: directory on individual tasks for readability; only owner/group/mode in defaults
- [Phase 09.1]: 09.1-02: openbao block/rescue wraps TLS cert generation; backup script keeps explicit root owner override
- [Phase 09.1]: 09.1-02: OPT-06 audit complete — all uri/get_url calls are single-use with no shared params, no consolidation needed
- [Phase 09.1-01]: module_defaults at block level does not satisfy ansible-lint risky-file-permissions — noqa inline required per task relying on defaults
- [Phase 09.1-01]: AppArmor enforce/complain merged via ternary — removes when condition entirely, command selected at runtime
- [Phase 09.1-01]: Firewall relaxed-idempotence pairs merged via changed_when: not (firewall_relax_idempotence | default(false))

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

Last session: 2026-04-21T07:06:37.314Z
Stopped at: Completed Phase 09.1 Plan 01 — module_defaults + firewall task consolidation
Resume file: None
