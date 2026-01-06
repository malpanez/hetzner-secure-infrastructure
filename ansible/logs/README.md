# Ansible Deployment Logs

Este directorio contiene los logs de las ejecuciones de Ansible playbooks.

## Estructura de Logs

- **Logs con timestamp**: `ansible-YYYYMMDD-HHMMSS.log`
  - Cada ejecución crea un nuevo archivo con fecha/hora
  - Formato: `ansible-20260103-143022.log`
  - Previene sobreescritura de logs anteriores

- **Symlink latest**: `latest.log`
  - Siempre apunta al log más reciente
  - Útil para revisar rápidamente la última ejecución
  - Actualizado automáticamente por `deploy.sh`

## Uso

### Método 1: Script deploy.sh (RECOMENDADO)

El script `deploy.sh` configura logging automáticamente:

```bash
# Desde el directorio ansible/
./deploy.sh -u root playbooks/site.yml

# Con tags específicos
./deploy.sh -u root playbooks/site.yml --tags ssh,firewall

# Dry-run (check mode)
./deploy.sh -u root playbooks/site.yml --check
```

**Ventajas**:

- ✅ Logging automático con timestamp
- ✅ Symlink `latest.log` actualizado
- ✅ Muestra ubicación del log al inicio y fin
- ✅ Preserva código de salida de ansible-playbook

### Método 2: Variable de entorno manual

Si prefieres ejecutar ansible-playbook directamente:

```bash
export ANSIBLE_LOG_PATH="./logs/ansible-$(date +%Y%m%d-%H%M%S).log"
ansible-playbook -u root playbooks/site.yml
```

### Método 3: Sin logging (solo stdout)

Si no necesitas logs persistentes:

```bash
unset ANSIBLE_LOG_PATH
ansible-playbook -u root playbooks/site.yml
```

## Revisar Logs

### Ver último log

```bash
# Ver en tiempo real (si deploy está corriendo)
tail -f logs/latest.log

# Ver log completo
less logs/latest.log

# Buscar errores
grep -i error logs/latest.log
grep -i failed logs/latest.log
```

### Ver log específico por fecha

```bash
# Listar logs disponibles
ls -lht logs/ansible-*.log

# Ver log de fecha específica
less logs/ansible-20260103-143022.log
```

### Buscar en múltiples logs

```bash
# Buscar patrón en todos los logs
grep -h "pattern" logs/ansible-*.log

# Buscar con contexto (3 líneas antes/después)
grep -C 3 "FAILED" logs/ansible-*.log
```

## Mantenimiento

### Limpiar logs antiguos (manual)

```bash
# Ver cuánto espacio usan los logs
du -sh logs/

# Eliminar logs más antiguos de 30 días
find logs/ -name "ansible-*.log" -mtime +30 -delete

# Mantener solo los últimos 10 logs
ls -t logs/ansible-*.log | tail -n +11 | xargs rm -f
```

### Rotación automática (opcional)

Si deseas rotación automática, considera agregar a `ansible.cfg`:

```ini
[defaults]
# Uncomment to enable automatic log rotation
# log_path = ./logs/ansible.log  # Main log
# log_file_mode = 0644
```

Y configurar logrotate en el sistema:

```
/path/to/ansible/logs/ansible.log {
    daily
    rotate 30
    compress
    delaycompress
    missingok
    notifempty
}
```

## Contenido de los Logs

Los logs incluyen:

- **Timestamp de cada task**: Cuando inicia y termina
- **Output de comandos**: Salida de módulos como `command`, `shell`
- **Cambios aplicados**: Qué configuraciones se modificaron
- **Errores y warnings**: Problemas encontrados durante ejecución
- **Facts recolectados**: Variables detectadas del sistema
- **Handlers ejecutados**: Servicios reiniciados, etc.
- **Timing information**: Duración de cada task (callback: profile_tasks)

## Búsquedas Útiles

```bash
# Ver solo tasks que cambiaron algo
grep "changed:" logs/latest.log

# Ver solo errores fatales
grep "fatal:" logs/latest.log

# Ver tiempo de ejecución de tasks lentas
grep "seconds" logs/latest.log | sort -k2 -n | tail -10

# Ver qué archivos se modificaron
grep "changed:.*template" logs/latest.log

# Ver servicios reiniciados
grep "RUNNING HANDLER" logs/latest.log

# Ver versión SSH detectada
grep "Detected OpenSSH version" logs/latest.log

# Ver si reboot fue necesario
grep "reboot.*required" logs/latest.log
```

## Git Ignore

Los archivos de log (`.log`) están excluidos del control de versiones por `.gitignore`:

```gitignore
*.log          # Todos los archivos .log ignorados
logs/*         # Todo el contenido de logs/ ignorado
!logs/.gitkeep # Excepto .gitkeep para mantener el directorio
!logs/latest.log  # Excepto latest.log (symlink tracked)
```

Esto previene:

- ❌ Commits accidentales de logs con información sensible
- ❌ Inflado del repositorio git
- ❌ Conflictos de merge en logs

## Seguridad

⚠️ **IMPORTANTE**: Los logs pueden contener información sensible:

- Direcciones IP de servidores
- Nombres de usuario
- Rutas de archivos del sistema
- Output de comandos que podrían revelar configuración

**Recomendaciones**:

1. ✅ Nunca committear logs al repositorio git
2. ✅ Revisar logs antes de compartirlos
3. ✅ Usar `ansible-playbook --diff` con cuidado (muestra contenido de archivos)
4. ✅ Considerar encriptar logs si contienen secrets
5. ✅ Eliminar logs al terminar debugging

## Troubleshooting

### Problema: No se crea el log

```bash
# Verificar que el directorio existe y tiene permisos
ls -ld logs/
# Debería mostrar: drwxr-xr-x

# Verificar variable de entorno
echo $ANSIBLE_LOG_PATH

# Ejecutar con deploy.sh que lo configura automáticamente
./deploy.sh -u root playbooks/site.yml
```

### Problema: latest.log es un archivo en vez de symlink

```bash
# Eliminar y dejar que deploy.sh lo recree
rm logs/latest.log
./deploy.sh -u root playbooks/site.yml
```

### Problema: Logs muy grandes

```bash
# Ver tamaño de logs
du -h logs/*.log

# Los logs grandes suelen indicar:
# - Output verbose de comandos
# - Muchos tasks ejecutados
# - Debug output habilitado

# Reducir verbosidad en siguiente ejecución
./deploy.sh -u root playbooks/site.yml -v  # Solo -v en vez de -vvv
```
