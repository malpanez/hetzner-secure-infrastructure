# Promtail Role

Ansible role para desplegar Grafana Promtail (log shipping agent).

## Qué hace este role

- ✅ Instala Promtail desde repositorio oficial de Grafana (APT, formato DEB822)
- ✅ Configura scraping automático de logs (Nginx, PHP, MariaDB, WordPress, Syslog, Auth, Fail2ban)
- ✅ Parsea logs con regex para extraer campos útiles
- ✅ Añade etiquetas (labels) para categorización
- ✅ Envía logs a Loki en batches
- ✅ Logrotate automático
- ✅ Systemd service con hardening de seguridad
- ✅ Tests con Molecule

## Logs que recopila

Por defecto recopila logs de:

- **Nginx** (access + error)
- **PHP-FPM**
- **MariaDB** (error + slow queries)
- **WordPress** (debug.log)
- **Syslog**
- **Auth** (SSH logins)
- **Fail2ban** (bans de IPs)

Configurable con variables `promtail_scrape_*`.

## Variables principales

Ver [`defaults/main.yml`](defaults/main.yml) para todas las variables.

```yaml
# Habilitar/deshabilitar fuentes
promtail_scrape_nginx: true
promtail_scrape_php: true
promtail_scrape_mariadb: true
promtail_scrape_wordpress: true
promtail_scrape_syslog: true
promtail_scrape_auth: true
promtail_scrape_fail2ban: true

# Conexión a Loki
promtail_loki_url: "http://localhost:3100/loki/api/v1/push"
```

## Uso

```yaml
- hosts: monitoring_servers
  roles:
    - role: promtail
      when: deploy_promtail | default(true) | bool
```

## Testing

```bash
cd ansible/roles/promtail
molecule test
```

## Documentación completa

Ver [docs/LOGGING.md](../../../docs/LOGGING.md)
