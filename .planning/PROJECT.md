# Two Minds Trading — Dual WordPress Infrastructure Rebuild

## What This Is

Rebuild completo de la infraestructura web de Two Minds Trading sobre un Hetzner CAX11 ARM64, reemplazando un único WordPress con Elementor por dos instalaciones independientes: `twomindstrading.com` (marketing, Kadence Blocks) y `academy.twomindstrading.com` (campus LMS con LearnDash + WooCommerce). El objetivo es pasar de 18.9s LCP a <2s, eliminar la deuda técnica del incidente de seguridad del 26/03/2026, y establecer una base de infraestructura mantenible.

## Core Value

Un alumno puede descubrir los cursos en el main site, comprar en el academy, y aprender sin fricciones — con el servidor respondiendo en <2s y sin riesgo de perder datos por falta de backups.

## Requirements

### Validated

*Validated in Phase 1: IaC Refactor (2026-03-28)*

- [x] Role `nginx_wordpress` refactorizado para soportar múltiples instancias (include_role x2) — parametrizado con `nginx_wordpress_site_name`, PHP 8.3, fastcgi_cache_path per-vhost, LearnDash bypass
- [x] Nuevo playbook `dual-wordpress.yml` con 2 DBs, 2 usuarios MariaDB, 2 invocaciones del role — pool sizes 20/30, Valkey db 0/1, vault vars documentadas
- [x] DNS A record `academy.twomindstrading.com` añadido en Terraform/Cloudflare — `cloudflare_record.academy`, proxied, misma IP
- [x] `wp-config.php.j2` renderiza `WP_REDIS_DATABASE` y `WP_REDIS_PREFIX` distintos por instancia

### Active

**Infraestructura (IaC)**

- [ ] Molecule tests pasando con el role refactorizado (Phase 2)
- [ ] MariaDB binary logging aplicado al servidor de producción
- [ ] AppArmor + fail2ban perfiles actualizados para cubrir ambas rutas web
- [ ] Servidor reconstruido con `terraform destroy + apply` (clean slate)

**Seguridad y Operaciones**

- [ ] OpenBao rotation (`setup-openbao-rotation.yml`) ejecutado correctamente por primera vez
- [ ] `WP_PATH` en rotation scripts apunta a `/var/www/twomindstrading.com`
- [ ] UpdraftPlus activo en ambos sitios con backup a Google Drive
- [ ] Molecule tests pasando con el role refactorizado

**Main site — twomindstrading.com**

- [ ] WordPress instalado con Kadence + Kadence Blocks (sin Elementor)
- [ ] Contenido del tercero importado (XML export + reconstrucción en Kadence)
- [ ] Páginas: home, metodología, cursos (listing con CTAs a academy), instructores, contacto
- [ ] LCP <2s en mobile (PageSpeed >90)
- [ ] Plugin stack mínimo: kadence-blocks, redis-cache, nginx-helper, wp-mail-smtp, seo-by-rank-math, cookie-notice, limit-login-attempts-reloaded, wordfence-login-security, updraftplus

**Academy — academy.twomindstrading.com**

- [ ] WordPress instalado con Kadence + LearnDash Pro (licencia manual)
- [ ] WooCommerce configurado para enrollment y pagos
- [ ] Cursos creados desde cero (no hay backup de contenido)
- [ ] Plugin stack: kadence-blocks, redis-cache (db 1), nginx-helper, wp-mail-smtp, limit-login-attempts-reloaded, wordfence-login-security, updraftplus, woocommerce, LearnDash Pro

### Out of Scope

- **WordPress Multisite** — Instalaciones separadas son más resilientes y aisladas
- **Cross-site SSO automático** — El enrollment ocurre directamente en academy; main site solo tiene CTAs que apuntan a academy
- **WooCommerce en main site** — Toda la lógica de compra vive en academy.twomindstrading.com
- **Contenido LearnDash legacy** — Se perdió en el incidente. Los cursos se crean desde cero.
- **Elementor en main site** — El tercero lo construyó en Elementor pero se migra a Kadence

## Context

**Incidente de seguridad (2026-03-26):** El servidor fue reiniciado tras un patch, OpenBao quedó sellado, y el WP admin perdió acceso. Un usuario con acceso admin previo (<techdirector@grupolyown.com>) restauró su propio proyecto sobre el WP del usuario a ~03:04 UTC. Se perdió el contenido original de la DB (cursos LearnDash, etc.). El tercero contratado para reconstruir el sitio lo hizo en Elementor en lugar de Kadence.

**Estado actual del servidor:**

- WordPress activo con diseño del tercero en Elementor + Hello Elementor theme
- OpenBao correctamente unsealed (transit en 8201, primary en 8200)
- `setup-openbao-rotation.yml` NUNCA ejecutado — no hay rotation activa
- Binary logging añadido a group_vars pero no aplicado a producción
- AppArmor/fail2ban perfiles referencian `/var/www/wordpress` (obsoleto tras rebuild)

**Decisiones de arquitectura ya tomadas:**

- PHP 8.3 (Debian 13 default en group_vars — hay mismatch con defaults/main.yml que dice 8.4; usar 8.3 explícitamente)
- Cloudflare Origin wildcard `*.twomindstrading.com` cubre academy sin certbot adicional
- FastCGI cache SEPARADA por vhost (nginx-helper purge_all() borra por path de filesystem, no por dominio — cache compartida = wipe cross-site)
- Valkey db 0 para main site, db 1 para academy

## Constraints

- **Servidor**: Hetzner CAX11 ARM64 (4 vCPU, 8GB RAM, Debian 13) — single VPS, ~3.2GB RAM uso estimado con ambos sitios
- **LearnDash**: Requiere instalación manual vía wp-admin (licencia propietaria, no automatizable)
- **OpenBao post-destroy**: Requiere re-inicialización manual del transit (8201) antes del primary (8200) — ver `docs/openbao_unseal_procedure.md`
- **Downtime**: ~15-30 min durante `terraform destroy + apply` — planificar en horario de baja actividad
- **Email**: Zoho Mail configurado en Cloudflare DNS; SMTP para WordPress via Brevo
- **Fase 0 manual**: Export XML + screenshots del sitio actual deben hacerse ANTES del destroy

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| 2 WP separados vs Multisite | Mejor aislamiento, menor riesgo operacional | — Pending |
| include_role x2 vs wordpress_instances loop | 4-5 cambios de archivos vs 45+ rewrites de tasks | — Pending |
| terraform destroy vs surgical | Clean slate, OpenBao correcto desde inicio, binary logging desde el principio | — Pending |
| WooCommerce solo en academy | Simplifica main site, elimina sincronización cross-site | — Pending |
| UpdraftPlus + Google Drive para backups | Simple, gratuito, cubre DB + files sin operación manual | — Pending |
| Enrollment: CTAs en main → checkout en academy | Evita cross-site user sync, reduce complejidad | — Pending |

## Evolution

This document evolves at phase transitions and milestone boundaries.

**After each phase transition** (via `/gsd:transition`):

1. Requirements invalidated? → Move to Out of Scope with reason
2. Requirements validated? → Move to Validated with phase reference
3. New requirements emerged? → Add to Active
4. Decisions to log? → Add to Key Decisions
5. "What This Is" still accurate? → Update if drifted

**After each milestone** (via `/gsd:complete-milestone`):

1. Full review of all sections
2. Core Value check — still the right priority?
3. Audit Out of Scope — reasons still valid?
4. Update Context with current state

---
*Last updated: 2026-04-02 — Phase 7 (Unified deploy.yml) complete. All pre-deploy phases (1-2, 6-7) done. Ready for Phase 3 (Server Rebuild) — single command: `ansible-playbook playbooks/deploy.yml`*
