# Testing Guide

Guía para probar la infraestructura localmente antes de desplegar en producción.

## Opción 1: Docker (Recomendado para WSL2)

### Prerequisitos
```bash
# Verificar Docker
docker --version

# Instalar Ansible en WSL2 si no lo tienes
sudo apt update
sudo apt install -y ansible

# Instalar Galaxy dependencies
cd ansible
ansible-galaxy install -r requirements.yml
```

### Testing Rápido con Docker

```bash
# Crear contenedor Debian 12 para testing
docker run -d --name wordpress-test \
  --privileged \
  -p 8080:80 \
  -p 8443:443 \
  debian:12 /sbin/init

# Ejecutar playbook
ansible-playbook -i ansible/inventory/docker.yml \
  ansible/playbooks/site.yml \
  --limit wordpress_servers

# Acceder al contenedor
docker exec -it wordpress-test bash

# Ver WordPress
http://localhost:8080
```

### Limpieza
```bash
docker stop wordpress-test
docker rm wordpress-test
```

## Opción 2: Vagrant + VirtualBox (Windows)

**Nota**: Solo funciona desde Windows (no WSL2). Requiere VirtualBox instalado.

### Instalar VirtualBox
```powershell
# Desde Windows PowerShell como Administrador
choco install virtualbox

# O descargar de: https://www.virtualbox.org/
```

### Usar Vagrant
```powershell
# Desde Windows PowerShell (NO desde WSL2)
cd C:\path\to\hetzner-secure-infrastructure

# Iniciar VM
vagrant up wordpress-aio

# Acceder vía SSH
vagrant ssh wordpress-aio

# Acceder vía web
# http://localhost:8888 (HTTP)
# https://localhost:8889 (HTTPS)
```

## Opción 3: VPS de Prueba en Hetzner (Más realista)

La opción más cercana a producción:

```bash
# Crear servidor CX22 en Hetzner Cloud (€5.83/mes)
# Debian 12, 4GB RAM, 2 vCPU, 80GB SSD

# Ejecutar playbook contra servidor real
ansible-playbook -i ansible/inventory/staging.yml \
  ansible/playbooks/site.yml
```

## Verificación Básica

```bash
# Verificar servicios
sudo systemctl status nginx php8.2-fpm mysql valkey

# Verificar plugins WordPress
wp plugin list --path=/var/www/wordpress

# Verificar seguridad
sudo ufw status verbose
sudo fail2ban-client status
```

## Checklist

### WordPress (Básico)
- [ ] WordPress carga
- [ ] Login admin funciona
- [ ] 8 plugins instalados

### Seguridad
- [ ] UFW activo
- [ ] Fail2ban corriendo
- [ ] AppArmor activo
- [ ] Redis cache funciona

## Plugins Instalados Automáticamente

1. Wordfence - Security
2. Sucuri Scanner - Security
3. WP 2FA - 2FA
4. UpdraftPlus - Backups
5. Redis Cache - Performance
6. Yoast SEO - SEO
7. Enable Media Replace - Media
8. WP Mail SMTP - Email
9. Health Check - Monitoring

## Recomendación

**Para testing inicial**: Usa Docker en WSL2 (más rápido)
**Para testing completo**: Usa VPS de Hetzner staging (más realista)

VirtualBox requiere instalación en Windows y ejecutar Vagrant desde PowerShell.
