# Requirements: Two Minds Trading — Dual WordPress Rebuild

**Defined:** 2026-03-28
**Core Value:** Un alumno puede descubrir cursos en el main site, comprar en academy, y aprender sin fricciones — con <2s LCP y sin riesgo de perder datos.

---

## v1 Requirements

### IaC — Role Refactor

- [ ] **ROLE-01**: Variable `nginx_wordpress_site_name` añadida a `defaults/main.yml` como discriminador de instancia
- [ ] **ROLE-02**: `tasks/configure.yml` parametrizado: vhost conf, pool conf, log names usan `nginx_wordpress_site_name`
- [ ] **ROLE-03**: `templates/php-fpm-wordpress.conf.j2` parametrizado: pool name + socket path por instancia
- [ ] **ROLE-04**: `templates/sites-available/wordpress.conf.j2` parametrizado: socket path + `fastcgi_cache_path` + zone name (separados por instancia) + log names
- [ ] **ROLE-05**: `templates/conf.d/fastcgi-cache.conf.j2` eliminado o vaciado — `fastcgi_cache_path` movido al vhost (previene cross-site cache purge via nginx-helper)
- [ ] **ROLE-06**: `templates/sites-available/wordpress.conf.j2` añade bypass rules para `/ld-focus-mode/` y `/learndash-checkout/`
- [ ] **ROLE-07**: `nginx_wordpress_woocommerce_enabled` activado para la invocación de academy

### IaC — Playbook & Inventory

- [ ] **PLAY-01**: Nuevo playbook `dual-wordpress.yml` con 2 databases, 2 usuarios MariaDB, 2 invocaciones `include_role`
- [ ] **PLAY-02**: Invocación main site: `nginx_wordpress_site_name=main`, sin LearnDash, sin WooCommerce
- [ ] **PLAY-03**: Invocación academy: `nginx_wordpress_site_name=academy`, LearnDash enabled, WooCommerce enabled, `letsencrypt_enabled=false`
- [ ] **PLAY-04**: PHP-FPM pool sizes diferenciados: main=20 workers, academy=30 workers
- [ ] **PLAY-05**: Vault añade: `vault_wp_main_db_password`, `vault_wp_academy_db_password`, salts independientes para academy

### IaC — wp-config.php

- [ ] **WP-01**: Template `wp-config.php.j2` acepta `WP_REDIS_DATABASE` y `WP_REDIS_PREFIX` como variables por instancia
- [ ] **WP-02**: Main site: `WP_REDIS_DATABASE=0`, prefix `wp_main_`
- [ ] **WP-03**: Academy site: `WP_REDIS_DATABASE=1`, prefix `wp_academy_`

### Terraform / DNS

- [x] **TF-01**: DNS A record `academy.twomindstrading.com` añadido en `cloudflare-config/dns.tf` (proxied, misma IP)

### Servidor — Operaciones

- [ ] **OPS-01**: `valkey_maxmemory` aumentado a 512MB en `ansible/inventory/group_vars/wordpress_servers/valkey.yml`
- [ ] **OPS-02**: MariaDB binary logging aplicado al servidor (ya en group_vars, pendiente `ansible-playbook --tags mariadb`)
- [ ] **OPS-03**: `setup-openbao-rotation.yml` ejecutado por primera vez correctamente; `WP_PATH` apunta a `/var/www/twomindstrading.com`
- [ ] **OPS-04**: Fail2ban jails configurados para monitorear ambos log paths (`/var/log/nginx/main-*.log`, `/var/log/nginx/academy-*.log`)
- [ ] **OPS-05**: AppArmor perfiles actualizados para cubrir `/var/www/*/` (ambas rutas web)

### Testing

- [ ] **TEST-01**: `molecule test` pasa en `nginx_wordpress` role con el refactor aplicado
- [ ] **TEST-02**: `ansible-lint` y `pre-commit run --all-files` limpios en el branch `feature/dual-wordpress`

### Main site — twomindstrading.com

- [ ] **MAIN-01**: WordPress instalado con Kadence theme (libre) + Kadence Blocks
- [ ] **MAIN-02**: Contenido importado desde XML export de Fase 0
- [ ] **MAIN-04**: Páginas reconstruidas en Kadence Blocks: home, metodología, cursos (listing con CTAs → academy), instructores, contacto
- [ ] **MAIN-05**: Google Fonts configurado como "Local" en Kadence (elimina latencia externa)
- [ ] **MAIN-06**: LCP <2s mobile, PageSpeed >90
- [ ] **MAIN-07**: Plugin stack: kadence-blocks, redis-cache, nginx-helper, wp-mail-smtp, seo-by-rank-math, cookie-notice, limit-login-attempts-reloaded, wordfence-login-security, updraftplus
- [ ] **MAIN-08**: UpdraftPlus configurado con backup a Google Drive (DB + files, diario, 14 días retención)
- [ ] **MAIN-09**: WP Activity Log instalado (para audit trail antes de cualquier acceso de terceros)
- [ ] **MAIN-10**: WP-cron desactivado en wp-config, system cron configurado via Ansible

### Academy — academy.twomindstrading.com

- [ ] **ACAD-01**: WordPress instalado con Kadence theme + Kadence Blocks
- [ ] **ACAD-02**: LearnDash Pro instalado manualmente (requiere licencia — subir ZIP vía wp-admin)
- [ ] **ACAD-03**: WooCommerce instalado y configurado para enrollment (Stripe o PayPal)
- [ ] **ACAD-04**: Cursos creados desde cero (no hay backup de contenido — Fase 0 confirmó que se perdió)
- [ ] **ACAD-05**: Plugin stack: kadence-blocks, redis-cache, nginx-helper, wp-mail-smtp, limit-login-attempts-reloaded, wordfence-login-security, updraftplus, woocommerce, LearnDash Pro
- [ ] **ACAD-06**: UpdraftPlus configurado con backup a Google Drive (DB + files, diario, 14 días retención)
- [ ] **ACAD-07**: WP Activity Log instalado
- [ ] **ACAD-08**: WP-cron desactivado, system cron via Ansible
- [ ] **ACAD-09**: Verificar compatibilidad WooCommerce HPOS + LearnDash WC Integration bridge (deshabilitar HPOS si hay warning)

### Infraestructura Servidor — Post-destroy

- [ ] **INFRA-01**: `terraform destroy + apply` ejecutado en ventana de mantenimiento
- [ ] **INFRA-02**: OpenBao transit (8201) unsealed manualmente post-deploy antes de arrancar primary (8200)
- [ ] **INFRA-03**: OpenBao primary (8200) arrancado y verificado unsealed
- [ ] **INFRA-04**: `site.yml` + `dual-wordpress.yml` ejecutados limpiamente en servidor nuevo

---

## v2 Requirements

### Rendimiento avanzado (post-estabilización)

- Brotli en Nginx (requiere `nginx-module-brotli`, no en repo oficial)
- PHP-FPM `pm = ondemand` en academy si tráfico bajo
- Cloudflare Cache Rules para `/courses/*` bypass en plan Free
- Hetzner snapshots automáticos diarios (7 días retención)
- Restic/borgbackup a Hetzner Object Storage como backup offsite adicional

### Seguridad post-incidente

- Pin GitHub Actions `@master` → SHA específicos (aquasecurity/trivy-action, ludeeus/action-shellcheck)
- `no_log: true` en 3 tasks de `openbao-bootstrap.yml`
- `set -euo pipefail` en todos los shell scripts

---

## Out of Scope

| Feature | Reason |
|---------|--------|
| WordPress Multisite | Instalaciones separadas son más resilientes y aisladas |
| Cross-site SSO automático | Enrollment ocurre directamente en academy; main solo tiene CTAs |
| WooCommerce en main site | Toda la lógica de compra vive en academy.twomindstrading.com |
| Contenido LearnDash legacy | Perdido en el incidente (confirmado en Fase 0) |
| Elementor en cualquiera de los dos sitios | Causa del LCP 18.9s; no se instala en el nuevo servidor (clean slate) |
| Multisite/Network activation de LearnDash | Dos instancias independientes es el modelo elegido |

---

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| ROLE-01, ROLE-02, ROLE-03, ROLE-04, ROLE-05, ROLE-06, ROLE-07 | Phase 1 — IaC Refactor | Pending |
| PLAY-01, PLAY-02, PLAY-03, PLAY-04, PLAY-05 | Phase 1 — IaC Refactor | Pending |
| WP-01, WP-02, WP-03 | Phase 1 — IaC Refactor | Pending |
| TF-01 | Phase 1 — IaC Refactor | Complete |
| TEST-01, TEST-02 | Phase 2 — Testing & Validation | Pending |
| INFRA-01, INFRA-02, INFRA-03, INFRA-04 | Phase 3 — Server Rebuild | Pending |
| OPS-01, OPS-02, OPS-03, OPS-04, OPS-05 | Phase 3 — Server Rebuild | Pending |
| MAIN-01, MAIN-02, MAIN-04, MAIN-05, MAIN-06, MAIN-07, MAIN-08, MAIN-09, MAIN-10 | Phase 4 — Main Site | Pending |
| ACAD-01, ACAD-02, ACAD-03, ACAD-04, ACAD-05, ACAD-06, ACAD-07, ACAD-08, ACAD-09 | Phase 5 — Academy Site | Pending |
