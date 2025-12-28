# Loki Role

Ansible role para desplegar Grafana Loki (log aggregation system).

## Qué hace este role

- ✅ Instala Loki desde repositorio oficial de Grafana (APT, formato DEB822)
- ✅ Configura almacenamiento filesystem con compresión automática
- ✅ Retención configurable de logs (default: 30 días)
- ✅ Logrotate automático para logs propios
- ✅ Backups automáticos diarios
- ✅ Systemd service con hardening de seguridad
- ✅ Tests con Molecule

## Variables principales

Ver [`defaults/main.yml`](defaults/main.yml) para todas las variables.

```yaml
# Retención de logs
loki_retention_period: "720h"  # 30 días (recomendado)

# Alternativas:
# - 7 días: "168h" (~140-210 MB)
# - 90 días: "2160h" (~1.8-2.7 GB)

# Backups
loki_backup_enabled: true
loki_backup_schedule: "0 3 * * *"  # Diario 3 AM
```

## Uso

```yaml
- hosts: monitoring_servers
  roles:
    - role: loki
      when: deploy_loki | default(true) | bool
```

## Testing

```bash
cd ansible/roles/loki
molecule test
```

## Documentación completa

Ver [docs/LOGGING.md](../../../docs/LOGGING.md)
