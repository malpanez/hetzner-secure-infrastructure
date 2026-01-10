# Guía Completa de Testing - x86 vs ARM con Stack Completo

**Última actualización**: 2026-01-09
**Propósito**: Testing completo de arquitectura x86 vs ARM con WordPress + Monitorización

---

## 📋 Resumen

Esta guía te lleva paso a paso para:

1. Desplegar servidor con Terraform (x86 o ARM)
2. Configurar stack completo con Ansible (WordPress + MariaDB + Valkey + Nginx)
3. Desplegar monitorización completa (Prometheus + Grafana + Loki + Promtail)
4. Ejecutar benchmarks de rendimiento
5. Analizar resultados en Grafana
6. Comparar arquitecturas y tomar decisión

---

## 🎯 Estado Actual

✅ **x86 (CX23) - COMPLETADO**

- Desplegado y testeado: 30-12-2024
- Resultados documentados en: [docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md](docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md)
- Rendimiento: 3,114 req/s, 32ms latencia, A+ grade
- Destruido: Sí

✅ **ARM (CAX11) - COMPLETADO**

- Resultados comparados en: [docs/performance/ARM64_vs_X86_COMPARISON.md](docs/performance/ARM64_vs_X86_COMPARISON.md)
- Ganador: ARM64 (CAX11) por mejor rendimiento y coste/beneficio

---

## 📚 Tabla de Contenidos

1. [Pre-requisitos](#pre-requisitos)
2. [TEST 1: x86 (CX23) - Paso a Paso](#test-1-x86-cx23---paso-a-paso)
3. [TEST 2: ARM (CAX11) - Paso a Paso](#test-2-arm-cax11---paso-a-paso)
4. [Análisis y Comparación](#análisis-y-comparación)
5. [Decisión Final](#decisión-final)

---

## Pre-requisitos

### En tu máquina local (Linux/macOS/WSL2)

```bash
# Verificar que tienes todo instalado
terraform version   # >= 1.0
ansible --version   # >= 2.10
ssh -V             # OpenSSH

# Verificar token de Hetzner
echo $HCLOUD_TOKEN  # Debe estar configurado
```

### Archivos necesarios

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure

# Verificar estructura
tree -L 2 terraform/
tree -L 2 ansible/
```

---

## TEST 1: x86 (CX23) - Paso a Paso

### Paso 1: Configurar Terraform para x86

```bash
cd terraform
```

Edita `terraform.staging.tfvars`:

```hcl
# Servidor x86
architecture = "x86"
server_size  = "small"  # CX23: 2 vCPU, 4GB RAM, €3.68/mo
location     = "nbg1"   # Nuremberg

# Proyecto Hetzner
hcloud_token = "default"  # Usa variable de entorno HCLOUD_TOKEN

# SSH
ssh_public_key_path = "~/.ssh/id_ed25519.pub"

# Usuario
admin_username = "malpanez"
```

### Paso 2: Desplegar Servidor con Terraform

```bash
# Inicializar (solo primera vez)
terraform init

# Planificar cambios
terraform plan -var-file=terraform.staging.tfvars

# Desplegar servidor
terraform apply -var-file=terraform.staging.tfvars
```

**Salida esperada**:

```
Apply complete! Resources: 3 added, 0 changed, 0 destroyed.

Outputs:

server_ipv4 = "X.X.X.X"
server_name = "stag-de-wp-01"
server_type = "cx23"
```

**Guardar IP del servidor**:

```bash
SERVER_IP=$(terraform output -raw server_ipv4)
echo "Server IP: $SERVER_IP"
```

### Paso 3: Esperar Cloud-Init (≈5 minutos)

```bash
# Esperar a que cloud-init complete
ssh malpanez@$SERVER_IP "cloud-init status --wait"

# Verificar estado
ssh malpanez@$SERVER_IP "cloud-init status"
# Debe decir: status: done
```

**¿Qué hace cloud-init?**

- Instala paquetes base
- Configura SSH
- Actualiza sistema
- Prepara usuario malpanez

### Paso 4: Verificar Inventario Dinámico (Plugin hcloud)

**¡NO NECESITAS EDITAR NADA!** Usamos el **plugin dinámico `hcloud`** que descubre servidores automáticamente.

```bash
cd ../ansible

# 1. Verificar token de Hetzner
echo $HCLOUD_TOKEN
# Debe mostrar: tu token (si no, ejecutar: export HCLOUD_TOKEN="tu-token")

# 2. Listar servidores descubiertos automáticamente
ansible-inventory --graph

# Debe mostrar:
# @all:
#   |--@ungrouped:
#   |--@hetzner:
#   |  |--@env_staging:
#   |  |  |--stag-de-wp-01
#   |  |--@staging:
#   |  |  |--stag-de-wp-01
#   |  |--@type_cx23:
#   |  |  |--stag-de-wp-01
#   |  |--@location_nbg1:
#   |  |  |--stag-de-wp-01
```

**¿Cómo funciona?**

1. **Terraform** crea servidor con labels: `environment = "staging"`, `project = "wordpress"`
2. **Plugin hcloud** lee la API de Hetzner cada vez que ejecutas Ansible
3. **Descubre servidores** con esos labels automáticamente
4. **Crea grupos** dinámicos: `env_staging`, `staging`, `type_cx23`, `location_nbg1`
5. **Obtiene la IP** del campo `ipv4_address` (siempre actualizada)

**Ventajas**:

- ✅ **Nunca editas IPs manualmente** - todo automático
- ✅ **Siempre sincronizado** con Hetzner Cloud
- ✅ **Escalable** - funciona con 1 o 100 servidores
- ✅ **Profesional** - industry standard para cloud dinámico
- ✅ **group_vars funciona**: `group_vars/staging.yml` se aplica al grupo `staging`
- ✅ **host_vars funciona**: `host_vars/stag-de-wp-01.yml` se aplica al host específico

**Grupos disponibles automáticamente**:

```
staging              → Servidores con label environment=staging
env_staging          → Mismo grupo (prefijo alternativo)
production           → Servidores con label environment=production
type_cx23            → Servidores tipo CX23
type_cax11           → Servidores tipo CAX11
location_nbg1        → Servidores en Nuremberg
location_fsn1        → Servidores en Falkenstein
hetzner              → TODOS los servidores de Hetzner
```

**Variables aplicadas por grupo**:

```
ansible/inventory/group_vars/
├── all.yml              → Se aplica a TODOS los servidores
├── staging.yml          → Se aplica solo a staging
├── production.yml       → Se aplica solo a production
└── hetzner.hcloud.yml   → Se aplica a todos los de Hetzner
```

### Paso 5: Probar Conexión Ansible

```bash
# Ping test usando grupos dinámicos
ansible staging -m ping

# Debe responder:
# stag-de-wp-01 | SUCCESS => {
#     "changed": false,
#     "ping": "pong"
# }

# Ver detalles del servidor descubierto
ansible-inventory --host stag-de-wp-01

# Debe mostrar (JSON):
# {
#     "ansible_host": "46.224.156.140",        # ← IP automática
#     "ansible_user": "malpanez",
#     "ansible_ssh_private_key_file": "~/.ssh/github_ed25519",
#     "hcloud_datacenter": "nbg1-dc3",
#     "hcloud_location": "nbg1",
#     "hcloud_server_type": "cx23",
#     "server_type": "cx23",
#     ...
# }
```

### Paso 6: Desplegar Stack Completo con Ansible

**IMPORTANTE**: Usamos inventario dinámico vía `ansible.cfg` (no hace falta `-i`).

```bash
# Opción 1: Playbook completo (RECOMENDADO)
ansible-playbook playbooks/site.yml

# Opción 2: Solo WordPress + Monitorización (por separado)
ansible-playbook playbooks/wordpress-only.yml
ansible-playbook playbooks/site.yml --tags monitoring

# Opción 3: Limitar a grupo staging específicamente
ansible-playbook playbooks/site.yml --limit staging
```

**Duración esperada**: 10-15 minutos

**¿Qué se despliega?**

**Stack WordPress**:

- ✅ Nginx (web server)
- ✅ PHP 8.4-FPM (application)
- ✅ MariaDB 11.8 (database)
- ✅ Valkey 8.0 (cache Redis fork)
- ✅ WordPress (latest)
- ✅ Firewall (UFW)
- ✅ Fail2ban (brute force protection)
- ✅ AppArmor (security hardening)

**Stack Monitorización** (añade ~400MB RAM overhead):

- ✅ Prometheus 2.48 (metrics collection)
- ✅ Grafana (dashboards)
- ✅ Loki (log aggregation)
- ✅ Promtail (log shipping)
- ✅ Node Exporter (system metrics)

**Salida esperada**:

```
PLAY RECAP *************************************************
stag-de-wp-01  : ok=127  changed=89   unreachable=0    failed=0
```

### Paso 7: Verificar Servicios

```bash
ssh malpanez@$SERVER_IP

# Verificar servicios WordPress
sudo systemctl status nginx
sudo systemctl status php8.4-fpm
sudo systemctl status mariadb
sudo systemctl status valkey

# Verificar servicios de monitorización
sudo systemctl status prometheus
sudo systemctl status grafana-server
sudo systemctl status loki
sudo systemctl status promtail

# Ver uso de memoria
free -h
# Total: 3.7GB
# Usado: ~900MB (WordPress + Monitorización)
# Disponible: ~2.9GB

# Salir del servidor
exit
```

### Paso 8: Verificar Accesos Web

```bash
# WordPress (debe redirigir a instalación)
curl -I http://$SERVER_IP
# Debe devolver: HTTP/1.1 302 Found

# Grafana (puerto 3000)
curl -I http://$SERVER_IP:3000
# Debe devolver: HTTP/1.1 200 OK

# Prometheus (puerto 9090)
curl -I http://$SERVER_IP:9090
# Debe devolver: HTTP/1.1 200 OK
```

**Acceder desde navegador**:

```
WordPress:   http://X.X.X.X
Grafana:     http://X.X.X.X:3000 (admin/admin - cambiar password)
Prometheus:  http://X.X.X.X:9090
```

### Paso 9: Configurar Grafana (Primera vez)

1. **Abrir Grafana**: http://$SERVER_IP:3000
2. **Login**: admin / admin (cambiar password cuando pida)
3. **Add Data Source**:
   - Click "Add your first data source"
   - Seleccionar "Prometheus"
   - URL: `http://localhost:9090`
   - Click "Save & Test" (debe decir "Data source is working")
4. **Import Dashboard**:
   - Click "+" → "Import"
   - Dashboard ID: `1860` (Node Exporter Full)
   - Click "Load"
   - Seleccionar Prometheus data source
   - Click "Import"

**Dashboard instalado**: Node Exporter Full

- CPU usage
- Memory usage
- Disk I/O
- Network traffic
- System load
- Process metrics

### Paso 10: Ejecutar Benchmark

**Desde tu máquina local**:

```bash
# Conectar al servidor
ssh malpanez@$SERVER_IP

# Instalar Apache Bench (si no está)
sudo apt-get update
sudo apt-get install apache2-utils -y

# Ejecutar benchmark (100k requests, 100 concurrency)
ab -n 100000 -c 100 http://127.0.0.1/ > ~/benchmark_x86_cx23.txt

# Ver resultados
cat ~/benchmark_x86_cx23.txt
```

**Duración**: ≈30-40 segundos

**Métricas clave a buscar**:

```
Requests per second:    XXXX [#/sec] (mean)
Time per request:       XX.XXX [ms] (mean)
Failed requests:        0
```

### Paso 11: Analizar Resultados en Grafana

**Durante el benchmark** (déjalo corriendo y abre Grafana):

1. **Abrir Grafana**: http://$SERVER_IP:3000
2. **Dashboard**: Node Exporter Full
3. **Time range**: Last 15 minutes
4. **Refresh**: 5s

**Métricas a observar**:

| Panel | Métrica | Valor Esperado |
|-------|---------|----------------|
| **System Load** | Load 1m | < 2.0 (para 2 vCPUs) |
| **CPU Busy** | CPU usage % | < 80% |
| **RAM Used** | Memory usage | < 3.0GB |
| **Network Traffic** | In/Out | Pico durante test |
| **Disk I/O** | Read/Write | Mínimo (todo en RAM) |

**Ejemplo resultados x86 CX23** (ya testeado):

- Load 1m: **0.66** (excelente, 67% headroom)
- RAM used: **866 MB** (23% de 4GB)
- CPU: **33%** utilization
- Requests/sec: **3,114**
- Latency media: **32ms**

### Paso 12: Guardar Logs del Sistema

```bash
# Dentro del servidor (SSH)

# Logs de Nginx
sudo tail -n 100 /var/log/nginx/access.log > ~/nginx_access_x86.log
sudo tail -n 100 /var/log/nginx/error.log > ~/nginx_error_x86.log

# Logs de PHP-FPM
sudo tail -n 100 /var/log/php8.4-fpm.log > ~/php_fpm_x86.log

# Stats de MariaDB
sudo mysql -e "SHOW GLOBAL STATUS LIKE 'Queries';" > ~/mariadb_stats_x86.txt

# Recursos del sistema
free -h > ~/system_memory_x86.txt
vmstat 1 5 > ~/system_vmstat_x86.txt

# Copiar todo a tu local
exit  # Salir del servidor

# Desde tu local
scp malpanez@$SERVER_IP:~/*_x86.* ~/test_results_x86/
```

### Paso 13: Documentar Resultados

Crea archivo de resultados:

```bash
cd ~/test_results_x86

cat > RESULTS_x86_CX23.md <<EOF
# Resultados Test x86 (CX23)

**Fecha**: $(date)
**Servidor**: Hetzner CX23
**IP**: $SERVER_IP

## Especificaciones
- **CPU**: 2 vCPUs (AMD EPYC)
- **RAM**: 4 GB
- **Disco**: 40 GB NVMe
- **Precio**: €3.68/mes

## Stack Desplegado
- Nginx 1.28.1
- PHP 8.4-FPM
- MariaDB 11.8
- Valkey 8.0
- WordPress latest
- Prometheus 2.48
- Grafana latest
- Loki latest

## Benchmark (ab -n 100000 -c 100)
- **Requests/sec**: XXXX
- **Latency media**: XXms
- **Latency p95**: XXms
- **Latency p99**: XXms
- **Failed requests**: 0

## Recursos Durante Test
- **Load 1m**: X.XX
- **CPU usage**: XX%
- **RAM used**: XXX MB
- **RAM available**: XXX MB

## Grafana Screenshots
- (Adjuntar capturas de pantalla)

## Problemas Encontrados
- Ninguno / Lista aquí

## Conclusión
PASS / FAIL
EOF

# Editar y completar
nano RESULTS_x86_CX23.md
```

### Paso 14: Destruir Servidor (Importante!)

**Después de documentar resultados**:

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform

# Destruir servidor
terraform destroy -var-file=terraform.staging.tfvars

# Confirmar: yes
```

**Verificar facturación Hetzner**: Solo pagas por tiempo usado (~€0.007/hora).

---

## TEST 2: ARM (CAX11) - Paso a Paso

### Paso 1: Configurar Terraform para ARM

```bash
cd terraform
```

Edita `terraform.staging.tfvars`:

```hcl
# CAMBIAR a ARM
architecture = "arm"
server_size  = "small"  # CAX11: 2 vCPU ARM, 4GB RAM, €4.05/mo
location     = "nbg1"   # ARM disponible en nbg1, fsn1, hel1

# Resto igual...
```

### Paso 2-14: Repetir TODOS los Pasos del TEST 1

**Ejecutar exactamente los mismos pasos**, pero guardando resultados con sufijo `_arm`:

```bash
# Archivos de resultados ARM
~/benchmark_arm_cax11.txt
~/nginx_access_arm.log
~/test_results_arm/RESULTS_arm_CAX11.md
```

**Cambios esperados**:

- Server type: `cax11` (en vez de `cx23`)
- Architecture: `aarch64` (en vez de `x86_64`)
- Resultados de rendimiento: **medidos y comparados**

---

## Análisis y Comparación

### Tabla Comparativa

| Métrica | x86 (CX23) | ARM (CAX11) | Ganador |
|---------|------------|-------------|---------|
| **Precio** | €3.68/mo | €4.05/mo | x86 ✓ |
| **Disponibilidad** | Stock limitado | Siempre disponible | ARM ✓ |
| **Requests/sec** | 3,114 | 8,338.55 | ARM ✓ |
| **Latency p95** | 57ms | 16ms | ARM ✓ |
| **Latency p99** | 76ms | 18ms | ARM ✓ |
| **CPU Load (1m)** | 0.66 | 0.19 | ARM ✓ |
| **RAM Usage** | 866 MB | 736 MB | ARM ✓ |
| **Failed Requests** | 0 | 0 | Tie |
| **Compatibilidad** | 100% | 100% | Tie |

### Cálculo Cost per 1000 Requests

```bash
# x86 CX23
€3.68/mes ÷ (3,114 req/s × 2,592,000 seg/mes) = €0.000000456 per 1000 req

# ARM CAX11
€4.05/mes ÷ (8,338.55 req/s × 2,592,000 seg/mes) = €0.000000187 per 1000 req
```

### Criterios de Decisión

**Elige x86 (CX23) si**:

- ✅ Stock disponible cuando necesites desplegar
- ✅ Rendimiento >= ARM (dentro del 10%)
- ✅ Quieres ahorrar €0.37/mes (€4.44/año)

**Elige ARM (CAX11) si**:

- ✅ x86 sin stock disponible
- ✅ Rendimiento >= x86 (dentro del 10%)
- ✅ Priorizas disponibilidad garantizada
- ✅ Arquitectura moderna (ARM64 futuro-proof)

**Recomendación por defecto**: **ARM (CAX11)**

- Razón: Rendimiento claramente superior y disponibilidad garantizada
- Diferencia de coste: €0.37/mes (≈ €4.44/año)
- Menor latencia y mejor coste por request
- Arquitectura moderna (ARM64)

---

## Decisión Final

Después de completar ambos tests:

### Si eliges x86 (CX23)

Crear `terraform/terraform.production.tfvars`:

```hcl
# Producción - x86
environment  = "production"
architecture = "x86"
server_size  = "small"
location     = "nbg1"

# Resto de configuración...
```

### Si eliges ARM (CAX11)

Crear `terraform/terraform.production.tfvars`:

```hcl
# Producción - ARM
environment  = "production"
architecture = "arm"
server_size  = "small"
location     = "nbg1"

# Resto de configuración...
```

---

## Comandos Rápidos (Cheat Sheet)

### Desplegar

```bash
# Terraform
cd terraform
terraform apply -var-file=terraform.staging.tfvars
SERVER_IP=$(terraform output -raw server_ipv4)

# Esperar cloud-init
ssh malpanez@$SERVER_IP "cloud-init status --wait"

# Ansible con inventario dinámico (stack completo)
cd ../ansible
ansible-playbook playbooks/site.yml
```

### Verificar

```bash
# Servicios
ssh malpanez@$SERVER_IP "sudo systemctl status nginx php8.4-fpm mariadb valkey prometheus grafana-server"

# Accesos web
curl -I http://$SERVER_IP        # WordPress
curl -I http://$SERVER_IP:3000   # Grafana
curl -I http://$SERVER_IP:9090   # Prometheus
```

### Benchmark

```bash
# Dentro del servidor
ssh malpanez@$SERVER_IP
ab -n 100000 -c 100 http://127.0.0.1/ > ~/benchmark.txt
cat ~/benchmark.txt | grep -E "Requests per second|Time per request|Failed"
```

### Destruir

```bash
cd terraform
terraform destroy -var-file=terraform.staging.tfvars
```

---

## Troubleshooting

### Cloud-init no termina

```bash
# Ver progreso
ssh malpanez@$SERVER_IP "cloud-init status"

# Ver logs
ssh malpanez@$SERVER_IP "sudo tail -f /var/log/cloud-init-output.log"
```

### Ansible falla en conexión

```bash
# Verificar SSH
ssh malpanez@$SERVER_IP "whoami"

# Verificar Python
ssh malpanez@$SERVER_IP "python3 --version"

# Test Ansible
ansible wordpress_servers -m ping -vvv
```

### Servicios no arrancan

```bash
# Ver logs
ssh malpanez@$SERVER_IP
sudo journalctl -u nginx -n 50
sudo journalctl -u php8.4-fpm -n 50
sudo journalctl -u mariadb -n 50
sudo journalctl -u prometheus -n 50
```

### Grafana no carga dashboards

```bash
# Verificar Prometheus
curl http://$SERVER_IP:9090/api/v1/targets

# Verificar data source en Grafana
# Settings → Data Sources → Prometheus → Test
```

---

## Próximos Pasos

Después de testing:

1. ✅ **Decidir arquitectura** (x86 vs ARM)
2. ⏳ **Crear terraform.production.tfvars**
3. ⏳ **Desplegar producción**
4. ⏳ **Configurar DNS en Cloudflare**
5. ⏳ **Configurar SSL con Let's Encrypt**
6. ⏳ **Configurar alertas en Grafana**
7. ⏳ **Instalar LearnDash Pro**

---

## Referencias

- **Resultados x86 completos**: [docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md](docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md)
- **Guía original testing**: [TESTING_x86_vs_ARM.md](TESTING_x86_vs_ARM.md)
- **Plan de producción**: [PRODUCTION_READINESS_PLAN.md](PRODUCTION_READINESS_PLAN.md)
- **Configuración nginx modular**: [NGINX_MODULAR_IMPLEMENTATION.md](NGINX_MODULAR_IMPLEMENTATION.md)

---

**Creado**: 2024-12-31
**Autor**: Claude Code
**Estado**: Listo para usar
