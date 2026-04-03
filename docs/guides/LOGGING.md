# Centralización de Logs con Loki + Grafana Alloy

Sistema de centralización de logs usando Grafana Loki y Grafana Alloy.

## Arquitectura

```
┌─────────────────────────────────────────────────┐
│ SERVIDOR (Hetzner CAX11)                        │
│                                                  │
│  ┌──────────────┐         ┌──────────────┐     │
│  │ Grafana Alloy│────────▶│     Loki     │     │
│  │  (Agente)    │  HTTP   │  (Storage)   │     │
│  │              │         │              │     │
│  │ Lee logs de: │         │ Puerto 3100  │     │
│  │ • Nginx      │         │              │     │
│  │ • PHP-FPM    │         │ Almacena &   │     │
│  │ • MariaDB    │         │ comprime     │     │
│  │ • WordPress  │         │              │     │
│  │ • Syslog     │         └──────┬───────┘     │
│  │ • Auth       │                │             │
│  │ • Fail2ban   │                │             │
│  └──────────────┘                │             │
│                          ┌────────▼────────┐   │
│                          │    Grafana      │   │
│                          │   (puerto 3000) │   │
│                          │                 │   │
│                          │ Datasources:    │   │
│                          │ • Prometheus    │   │
│                          │ • Loki          │   │
│                          └─────────────────┘   │
└─────────────────────────────────────────────────┘
```

> **Nota:** Promtail fue eliminado en Loki 3.x. Grafana Alloy es el sucesor oficial — reemplaza a Promtail y al Prometheus Agent en un único binario.

---

## Componentes

### **Grafana Alloy** (Agente recolector)

- **Función:** Leer archivos de log y enviarlos a Loki
- **Puerto:** 12345 (API interna, solo localhost)
- **Config:** `/etc/alloy/config.alloy` (sintaxis River)
- **Servicio:** `alloy`
- **RAM:** ~50-80 MB

### **Loki** (Base de datos de logs)

- **Función:** Almacenar, indexar y consultar logs
- **Puerto:** 3100
- **RAM:** ~100-150 MB
- **Config:** `/etc/loki/loki.yml`
- **Datos:** `/var/lib/loki/`

---

## Logs que se recopilan

| Fuente | Archivo | Label `job` |
|--------|---------|-------------|
| Syslog | `/var/log/syslog` | `syslog` |
| Auth | `/var/log/auth.log` | `auth` |
| Nginx Access | `/var/log/nginx/access.log` | `nginx_access` |
| Nginx Error | `/var/log/nginx/error.log` | `nginx_error` |
| PHP-FPM | `/var/log/php*-fpm.log` | `php_fpm` |
| MariaDB Error | `/var/log/mysql/error.log` | `mariadb_error` |
| MariaDB Slow | `/var/log/mysql/slow.log` | `mariadb_slow` |
| WordPress Debug | `{{ wordpress_root }}/wp-content/debug.log` | `wordpress` |
| Fail2ban | `/var/log/fail2ban.log` | `fail2ban` |

---

## Configuración

### Roles utilizados

- `grafana.grafana.loki` — Base de datos de logs
- `grafana.grafana.alloy` — Agente recolector (River syntax)

### Variables principales

**Loki (`ansible/inventory/group_vars/monitoring_servers/loki.yml`):**

```yaml
deploy_loki: true
loki_version: "3.7.1"
loki_http_listen_address: "127.0.0.1"
loki_http_listen_port: 3100
```

**Alloy (`ansible/inventory/group_vars/monitoring_servers/alloy.yml`):**

```yaml
deploy_alloy: true
alloy_version: "latest"

alloy_env_file_vars:
  CUSTOM_ARGS: "--server.http.listen-addr=127.0.0.1:12345"

alloy_config: |
  local.file_match "system_logs" {
    path_targets = [
      {"__path__" = "/var/log/syslog", "job" = "syslog", ...},
      ...
    ]
  }
  loki.source.file "system_logs" {
    targets    = local.file_match.system_logs.targets
    forward_to = [loki.write.local.receiver]
  }
  loki.write "local" {
    endpoint { url = "http://127.0.0.1:3100/loki/api/v1/push" }
  }
```

### Habilitar/deshabilitar

```yaml
deploy_loki: false
deploy_alloy: false
```

---

## Retención de logs

Editar `loki_limits_config` en `loki.yml`:

```yaml
loki_limits_config:
  retention_period: 720h   # 30 días (recomendado)
  reject_old_samples: true
  reject_old_samples_max_age: 720h

loki_compactor:
  working_directory: "/var/lib/loki/compactor"
  retention_enabled: true
  retention_delete_delay: 2h
```

Estimación de espacio (WordPress LMS, tráfico moderado):

```
~20-30 MB/día con compresión Loki
30 días → 600-900 MB
```

---

## Uso en Grafana

1. **Grafana** → **Explore** → Data source: **Loki**
2. Label filters: `job = nginx_access`
3. Run query

### Queries LogQL útiles

```
# Errores Nginx
{job="nginx_error"}

# Errores 500
{job="nginx_access"} |= "500"

# Errores PHP
{job="php_fpm"} |~ "Fatal error|Warning"

# Logins SSH fallidos
{job="auth"} |= "Failed password"

# IPs baneadas
{job="fail2ban"} |= "Ban"

# Múltiples fuentes
{job=~"nginx_access|php_fpm|mariadb_error"} |= "ERROR"
```

---

## Troubleshooting

### Verificar servicios

```bash
sudo systemctl status alloy
sudo systemctl status loki

sudo journalctl -u alloy -n 50
sudo journalctl -u loki -n 50
```

### Verificar que Loki recibe logs

```bash
curl http://localhost:3100/ready

curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="syslog"}' \
  --data-urlencode 'limit=5'
```

### Verificar Alloy

```bash
# Estado de la API
curl http://localhost:12345/-/ready

# Validar config
alloy fmt /etc/alloy/config.alloy
```

### Loki usa mucho espacio

```bash
du -sh /var/lib/loki/
# Reducir retention_period en loki.yml y re-ejecutar Ansible
```

---

## Backup y restauración

```bash
# Backup manual
sudo tar czf /var/backups/loki-backup-$(date +%Y%m%d-%H%M%S).tar.gz -C /var/lib loki

# Restaurar
sudo systemctl stop loki
sudo tar xzf /var/backups/loki/loki-backup-FECHA.tar.gz -C /
sudo chown -R loki:loki /var/lib/loki
sudo systemctl start loki
```

---

## Recursos

- [Alloy docs](https://grafana.com/docs/alloy/latest/)
- [Alloy River syntax reference](https://grafana.com/docs/alloy/latest/reference/components/)
- [Loki docs](https://grafana.com/docs/loki/latest/)
- [LogQL reference](https://grafana.com/docs/loki/latest/query/)
