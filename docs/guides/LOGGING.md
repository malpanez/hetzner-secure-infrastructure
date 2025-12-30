# Centralización de Logs con Loki + Promtail

Guía completa sobre el sistema de centralización de logs usando Grafana Loki y Promtail.

## 📋 Tabla de Contenidos

1. [Arquitectura](#arquitectura)
2. [Qué es cada componente](#qué-es-cada-componente)
3. [Logs que se recopilan](#logs-que-se-recopilan)
4. [Configuración](#configuración)
5. [Retención de logs](#retención-de-logs)
6. [Uso en Grafana](#uso-en-grafana)
7. [Queries útiles (LogQL)](#queries-útiles-logql)
8. [Troubleshooting](#troubleshooting)
9. [Backups](#backups)
10. [Logrotate](#logrotate)

---

## Arquitectura

```
┌─────────────────────────────────────────────────┐
│ SERVIDOR (Hetzner CX22)                         │
│                                                  │
│  ┌──────────────┐         ┌──────────────┐     │
│  │   Promtail   │────────▶│     Loki     │     │
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

---

## Qué es cada componente

### **Promtail** (Agente recolector)
- **Función:** Leer archivos de log y enviarlos a Loki
- **Puerto:** 9080
- **RAM:** ~30-50 MB
- **Config:** `/etc/promtail/promtail.yml`
- **Logs propios:** `/var/log/promtail/`
- **Posiciones:** `/var/lib/promtail/positions.yaml` (guarda offset de cada archivo leído)

**¿Qué hace?**
1. Lee archivos de log en tiempo real
2. Parsea el contenido (extrae timestamp, level, etc.)
3. Añade etiquetas (labels) para categorizar
4. Envía batch de logs a Loki vía HTTP

### **Loki** (Base de datos de logs)
- **Función:** Almacenar, indexar y consultar logs
- **Puerto:** 3100
- **RAM:** ~100-150 MB
- **Config:** `/etc/loki/loki.yml`
- **Datos:** `/var/lib/loki/`
- **Backups:** `/var/backups/loki/`

**¿Qué hace?**
1. Recibe logs de Promtail
2. Los comprime (gzip)
3. Los indexa por etiquetas (NO por contenido completo)
4. Responde a queries de Grafana
5. Borra logs automáticamente después del período de retención

**Diferencias con Elasticsearch:**
| Característica | Loki | Elasticsearch |
|----------------|------|---------------|
| RAM | ~150 MB | ~3 GB |
| Indexing | Solo labels | Todo el texto |
| Compresión | Automática | Manual |
| Queries | LogQL | Query DSL |
| Integración Grafana | Nativa | Plugin |

---

## Logs que se recopilan

Promtail está configurado para recopilar los siguientes logs:

| Fuente | Archivo | Etiquetas | Parseo |
|--------|---------|-----------|--------|
| **Nginx Access** | `/var/log/nginx/access.log` | `job=nginx, type=access` | Extrae IP, método, status, UA |
| **Nginx Error** | `/var/log/nginx/error.log` | `job=nginx, type=error` | Extrae level, mensaje |
| **PHP-FPM** | `/var/log/php*.fpm.log` | `job=php, type=fpm` | Extrae level, mensaje |
| **MariaDB Error** | `/var/log/mysql/error.log` | `job=mariadb, type=error` | Extrae level, thread_id |
| **MariaDB Slow** | `/var/log/mysql/slow.log` | `job=mariadb, type=slow_query` | Queries lentas |
| **WordPress Debug** | `/var/www/html/wp-content/debug.log` | `job=wordpress, type=debug` | Errores PHP de WordPress |
| **Syslog** | `/var/log/syslog` | `job=system, type=syslog` | Eventos del sistema |
| **Auth** | `/var/log/auth.log` | `job=auth, type=authentication` | Logins SSH, sudo |
| **Fail2ban** | `/var/log/fail2ban.log` | `job=fail2ban, type=security` | Baneos de IPs |

---

## Configuración

### Variables principales (en `group_vars/monitoring_servers/`)

**Loki (`loki.yml`):**
```yaml
# Despliegue
deploy_loki: true
loki_version: "latest"

# Retención (ajustar según necesidad)
loki_retention_period: "720h"  # 30 días (recomendado)
# Alternativas:
# - 7 días: "168h" (~140-210 MB)
# - 90 días: "2160h" (~1.8-2.7 GB)

# Límites de ingesta
loki_ingestion_rate_mb: 4
loki_ingestion_burst_size_mb: 6

# Límites de query
loki_max_query_series: 500
loki_max_query_parallelism: 32

# Backups
loki_backup_enabled: true
loki_backup_schedule: "0 3 * * *"  # Diario 3 AM
loki_backup_retention_days: 7
```

**Promtail (`promtail.yml`):**
```yaml
# Despliegue
deploy_promtail: true
promtail_version: "latest"

# Conexión a Loki
promtail_loki_url: "http://localhost:3100/loki/api/v1/push"

# Qué logs recopilar (true/false)
promtail_scrape_nginx: true
promtail_scrape_php: true
promtail_scrape_mariadb: true
promtail_scrape_wordpress: true
promtail_scrape_syslog: true
promtail_scrape_auth: true
promtail_scrape_fail2ban: true
```

### Habilitar/deshabilitar en deployment

En `playbooks/site.yml` (ya configurado):
```yaml
- role: loki
  tags: [monitoring, loki, logging]
  when: deploy_loki | default(true) | bool

- role: promtail
  tags: [monitoring, promtail, logging]
  when: deploy_promtail | default(true) | bool
```

Para **NO** desplegar Loki/Promtail, añadir a tu inventory:
```yaml
deploy_loki: false
deploy_promtail: false
```

---

## Retención de logs

### Cálculo de espacio

**Estimación para WordPress LMS (tráfico moderado):**

```
Logs diarios SIN comprimir:
- Nginx Access: ~50-100 MB/día
- Nginx Error: ~10 MB/día
- PHP-FPM: ~20 MB/día
- MariaDB: ~10 MB/día
- WordPress: ~5 MB/día
- Syslog: ~10 MB/día
TOTAL: ~105 MB/día sin comprimir

CON compresión Loki (gzip):
~20-30 MB/día (ahorro 70-80%)

Retención por período:
├─ 7 días:  140-210 MB
├─ 30 días: 600-900 MB  ← RECOMENDADO
└─ 90 días: 1.8-2.7 GB  ← Extendido
```

### Cambiar período de retención

Editar `ansible/inventory/group_vars/monitoring_servers/loki.yml`:

```yaml
# Para 7 días (mínimo):
loki_retention_period: "168h"

# Para 30 días (recomendado):
loki_retention_period: "720h"

# Para 90 días (extendido):
loki_retention_period: "2160h"
```

Luego re-ejecutar Ansible:
```bash
cd ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --tags loki --ask-vault-pass
```

---

## Uso en Grafana

### Acceder a Grafana

```bash
# URL
https://monitoring.tudominio.com

# Credenciales
Username: admin
Password: (vault_grafana_admin_password en secrets.yml)
```

### Ver logs en Explore

1. **Grafana** → **Explore** (icono brújula)
2. **Data source:** Seleccionar **Loki**
3. **Label filters:** Elegir job (nginx, php, mariadb, etc.)
4. **Run query**

### Dashboards pre-instalados

Los siguientes dashboards se instalan automáticamente:

1. **Loki Logs Dashboard** (ID: 13639)
   - Vista general de todos los logs
   - Gráficos de volumen por job
   - Top logs por nivel (ERROR, WARN, INFO)

2. **Nginx Loki Dashboard** (ID: 12559)
   - Requests por segundo
   - Top URLs
   - Errores 4xx/5xx
   - Top IPs
   - User agents

---

## Queries útiles (LogQL)

### Sintaxis básica

```
{label="value"} |= "search text"
```

- `{job="nginx"}` → Filtrar por etiqueta
- `|=` → Contiene texto
- `!=` → NO contiene texto
- `|~ "regex"` → Regex match
- `!~ "regex"` → Regex NO match

### Ejemplos reales

#### 1. Ver todos los errores de Nginx
```
{job="nginx", type="error"}
```

#### 2. Errores 500 en Nginx Access
```
{job="nginx", type="access"} |= "500"
```

#### 3. Errores PHP (Fatal, Warning)
```
{job="php"} |~ "Fatal error|Warning"
```

#### 4. Logins SSH fallidos
```
{job="auth"} |= "Failed password"
```

#### 5. IPs baneadas por Fail2ban
```
{job="fail2ban"} |= "Ban"
```

#### 6. Queries MySQL lentas (>1 segundo)
```
{job="mariadb", type="slow_query"}
```

#### 7. Top 10 IPs con más requests (última hora)
```
topk(10, sum by (remote_addr) (
  count_over_time({job="nginx", type="access"}[1h])
))
```

#### 8. Rate de errores (por minuto)
```
sum(rate({job="nginx", type="error"}[1m]))
```

#### 9. Logs de WordPress con "Fatal error"
```
{job="wordpress"} |= "Fatal error"
```

#### 10. Ver logs de múltiples fuentes a la vez
```
{job=~"nginx|php|mariadb"} |= "ERROR"
```

### Funciones útiles

| Función | Descripción | Ejemplo |
|---------|-------------|---------|
| `rate()` | Tasa de cambio por segundo | `rate({job="nginx"}[5m])` |
| `count_over_time()` | Contar logs en período | `count_over_time({job="php"}[1h])` |
| `sum()` | Sumar valores | `sum(count_over_time({job="nginx"}[1h]))` |
| `topk(N)` | Top N resultados | `topk(5, count_over_time({job="nginx"}[1h]))` |
| `json` | Parsear JSON logs | `{job="app"} | json` |

---

## Troubleshooting

### Verificar que Loki está corriendo

```bash
# Ver status
sudo systemctl status loki

# Ver logs
sudo journalctl -u loki -n 50

# Probar API
curl http://localhost:3100/ready
# Debe retornar: "ready"

# Ver métricas
curl http://localhost:3100/metrics
```

### Verificar que Promtail está corriendo

```bash
# Ver status
sudo systemctl status promtail

# Ver logs
sudo journalctl -u promtail -n 50

# Probar API
curl http://localhost:9080/ready

# Ver targets configurados
curl http://localhost:9080/targets
```

### Verificar que logs se están enviando

```bash
# Ver métricas de Promtail
curl http://localhost:9080/metrics | grep promtail_sent

# Debe mostrar algo como:
# promtail_sent_entries_total{...} 12345
```

### Problema: No aparecen logs en Grafana

**1. Verificar que Loki data source está configurado:**

Grafana → Configuration → Data Sources → Loki

- URL: `http://localhost:3100`
- Access: `Server (default)`
- Click **"Save & test"** → debe mostrar "Data source connected"

**2. Verificar que Promtail puede leer los archivos:**

```bash
# Verificar permisos
sudo -u promtail cat /var/log/nginx/access.log

# Si falla, añadir promtail al grupo adm
sudo usermod -aG adm promtail
sudo systemctl restart promtail
```

**3. Verificar que Loki está recibiendo logs:**

```bash
# Query directo a Loki API
curl -G http://localhost:3100/loki/api/v1/query_range \
  --data-urlencode 'query={job="nginx"}' \
  --data-urlencode 'limit=10'

# Debe retornar JSON con logs
```

### Problema: Loki usa mucho espacio

```bash
# Ver tamaño actual
du -sh /var/lib/loki/

# Ver logs más antiguos
ls -lht /var/lib/loki/chunks/ | tail -20

# Forzar limpieza manual (NO recomendado)
sudo systemctl stop loki
sudo rm -rf /var/lib/loki/chunks/fake/*
sudo systemctl start loki
```

**Mejor solución:** Reducir `loki_retention_period` en configuración.

### Problema: Queries muy lentas

**Causas comunes:**
1. Query sin filtrar por tiempo (`[24h]` en vez de `[5m]`)
2. Query muy amplia (regex complejo)
3. Demasiados streams

**Solución:**
```yaml
# En loki.yml, aumentar:
loki_max_query_parallelism: 64  # Default: 32
loki_max_query_series: 1000     # Default: 500
```

---

## Backups

### Backup automático

Configurado en `loki.yml`:
```yaml
loki_backup_enabled: true
loki_backup_schedule: "0 3 * * *"  # Diario 3 AM
loki_backup_retention_days: 7      # Mantener 7 días
```

Script: `/usr/local/bin/backup-loki.sh`

Backups guardados en: `/var/backups/loki/`

### Backup manual

```bash
# Ejecutar script
sudo /usr/local/bin/backup-loki.sh

# Ver backups
ls -lh /var/backups/loki/

# Ejemplo salida:
# loki-backup-20241228-030000.tar.gz (234 MB)
```

### Restaurar backup

```bash
# 1. Parar Loki
sudo systemctl stop loki

# 2. Respaldar datos actuales
sudo mv /var/lib/loki /var/lib/loki.old

# 3. Restaurar desde backup
sudo tar xzf /var/backups/loki/loki-backup-YYYYMMDD-HHMMSS.tar.gz -C /

# 4. Verificar permisos
sudo chown -R loki:loki /var/lib/loki

# 5. Iniciar Loki
sudo systemctl start loki

# 6. Verificar
sudo systemctl status loki
curl http://localhost:3100/ready
```

---

## Logrotate

### Archivos de configuración

**Promtail logs:**
```bash
/etc/logrotate.d/promtail
```

**Loki logs:**
```bash
/etc/logrotate.d/loki
```

**Nginx logs** (gestionado por Nginx role):
```bash
/etc/logrotate.d/nginx
```

**PHP-FPM logs:**
```bash
/etc/logrotate.d/php8.2-fpm
```

**MariaDB logs:**
```bash
/etc/logrotate.d/mysql-server
```

### Configuración logrotate (Loki/Promtail)

```
/var/log/loki/*.log {
    size 100M         # Rotar cuando alcanza 100MB
    rotate 7          # Mantener 7 archivos antiguos
    daily             # Revisar diariamente
    compress          # Comprimir archivos antiguos
    delaycompress     # Comprimir en siguiente rotación
    missingok         # No error si falta archivo
    notifempty        # No rotar si está vacío
    create 0640 loki loki
    postrotate
        systemctl reload loki > /dev/null 2>&1 || true
    endscript
}
```

### Probar logrotate manualmente

```bash
# Test (dry-run, no hace cambios)
sudo logrotate -d /etc/logrotate.d/loki

# Forzar rotación (para testing)
sudo logrotate -f /etc/logrotate.d/loki

# Ver estado de logrotate
cat /var/lib/logrotate/status
```

### Ver logs rotados

```bash
# Listar logs de Nginx
ls -lh /var/log/nginx/

# Ejemplo salida:
# access.log
# access.log.1
# access.log.2.gz
# access.log.3.gz
# error.log
# error.log.1.gz
```

---

## Monitoreo del sistema de logs

### Métricas de Loki en Prometheus

Loki expone métricas en `http://localhost:3100/metrics`.

Prometheus las recopila automáticamente (scrape config).

**Métricas útiles:**
```
# Total de logs ingestados
loki_distributor_lines_received_total

# Bytes almacenados
loki_ingester_chunks_stored_total

# Queries ejecutadas
loki_query_frontend_queries_total

# Errores
loki_distributor_lines_received_total{status="error"}
```

### Alertas recomendadas (Prometheus)

```yaml
groups:
  - name: loki
    rules:
      - alert: LokiDown
        expr: up{job="loki"} == 0
        for: 5m
        annotations:
          summary: "Loki is down"

      - alert: LokiHighIngestionRate
        expr: rate(loki_distributor_lines_received_total[5m]) > 10000
        for: 10m
        annotations:
          summary: "Loki ingesting >10k lines/sec"

      - alert: LokiDiskSpaceLow
        expr: (node_filesystem_avail_bytes{mountpoint="/var/lib/loki"} / node_filesystem_size_bytes{mountpoint="/var/lib/loki"}) < 0.1
        for: 5m
        annotations:
          summary: "Loki disk space <10%"
```

---

## Recursos adicionales

- **Loki Docs:** https://grafana.com/docs/loki/latest/
- **LogQL Reference:** https://grafana.com/docs/loki/latest/query/
- **Promtail Config:** https://grafana.com/docs/loki/latest/clients/promtail/configuration/
- **Grafana Dashboards:** https://grafana.com/grafana/dashboards/?search=loki

---

## Resumen de comandos útiles

```bash
# Ver status de servicios
sudo systemctl status loki
sudo systemctl status promtail

# Ver logs de servicios
sudo journalctl -u loki -f
sudo journalctl -u promtail -f

# Reiniciar servicios
sudo systemctl restart loki
sudo systemctl restart promtail

# Verificar health
curl http://localhost:3100/ready  # Loki
curl http://localhost:9080/ready  # Promtail

# Ver métricas
curl http://localhost:3100/metrics  # Loki
curl http://localhost:9080/metrics  # Promtail

# Backup manual
sudo /usr/local/bin/backup-loki.sh

# Ver espacio usado
du -sh /var/lib/loki/
du -sh /var/log/loki/
du -sh /var/backups/loki/

# Validar configuración
/usr/bin/loki -config.file=/etc/loki/loki.yml -verify-config
/usr/bin/promtail -config.file=/etc/promtail/promtail.yml -dry-run

# Ver logs rotados
ls -lh /var/log/nginx/
ls -lh /var/log/mysql/
```

---

**✅ Con esta configuración tienes centralización de logs completa, automática y eficiente.**
