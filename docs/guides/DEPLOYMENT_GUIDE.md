# Guía de Deployment - WordPress en Hetzner Cloud ARM64

**Última actualización:** 2026-01-13
**Arquitectura:** ARM64 (CAX11) - 2.68x mejor rendimiento que x86
**Tiempo estimado:** 45-60 minutos
**Cambios recientes:** Workspaces, pricing 2026, cloud-init hardening

---

## 📋 Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Configuración Inicial](#configuración-inicial)
3. [Deployment con Terraform](#deployment-con-terraform)
4. [Deployment con Ansible](#deployment-con-ansible)
5. [Configuración Post-Deployment](#configuración-post-deployment)
6. [Verificación](#verificación)

---

## Requisitos Previos

### Software Local

```bash
# Verificar versiones mínimas
terraform version  # >= 1.9.0
ansible --version  # >= 2.16.3
python3 --version  # >= 3.10
git --version      # >= 2.30
```

### Cuentas y Tokens

1. **Hetzner Cloud API Token**
   - Crear en: <https://console.hetzner.cloud/>/>
   - Permisos: Read & Write

2. **Cloudflare API Token** (requerido para Let's Encrypt DNS-01)
   - Crear en: <https://dash.cloudflare.com/profile/api-tokens>s>
   - Permisos: Zone:DNS:Edit

3. **SSH Key**

   ```bash
   # Si no tienes una, generar:
   ssh-keygen -t ed25519 -C "tu-email@ejemplo.com"
   ```

### Costos Estimados

| Componente | Costo Mensual | Obligatorio |
|------------|---------------|-------------|
| CAX11 (2 vCPU ARM64, 4GB RAM, IPv4 incluida) | €4.66 | ✅ Sí |
| Dominio (.com) | ~€1.00 | ✅ Sí |
| Cloudflare | €0.00 (Free) | ⚠️ Recomendado |
| **TOTAL MÍNIMO** | **€5.66/mes** | |

> **Nota:** Precios actualizados enero 2026 (Germany/NBG1 location). Incluyen Primary IPv4. Ver [Hetzner Pricing](https://www.hetzner.com/cloud/pricing/) para más opciones.

---

## Configuración Inicial

### 1. Clonar Repositorio

```bash
git clone https://github.com/tuusuario/hetzner-secure-infrastructure.git
cd hetzner-secure-infrastructure
```

### 2. Configurar Variables de Entorno

```bash
# Crear archivo de configuración
cat > .env << 'EOF'
# Hetzner Cloud
export HCLOUD_TOKEN="tu_token_hetzner_aqui"
export TF_VAR_hcloud_token="$HCLOUD_TOKEN"

# Cloudflare (requerido para DNS-01)
export CLOUDFLARE_API_TOKEN="tu_token_cloudflare"
export TF_VAR_cloudflare_api_token="$CLOUDFLARE_API_TOKEN"

# SSH
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
EOF

# Cargar variables
source .env
```

### 3. Configurar Ansible Vault

```bash
# Crear password de vault
echo "TU_PASSWORD_SEGURO_AQUI" > ~/.ansible_vault_pass
chmod 600 ~/.ansible_vault_pass

# Encriptar secretos (ya existen, solo verificar)
cd ansible
ansible-vault view inventory/group_vars/all/secrets.yml
# Debe pedir password y mostrar contenido encriptado
```

---

## Deployment con Terraform

### 1. Revisar Configuración

El archivo `terraform/production.tfvars` ya está configurado para ARM64:

```bash
cd terraform
cat production.tfvars
```

**Personalizar (obligatorio):**

```hcl
# DEBES cambiar tu IP pública (por seguridad SSH está restringido):
ssh_allowed_ips = ["TU_IP_PUBLICA/32"]  # Obtén con: curl ifconfig.me

# Opcional:
domain = "tudominio.com"                 # Tu dominio
```

> **⚠️ IMPORTANTE:** Si tu IP cambia y pierdes acceso SSH, usa la [Consola Hetzner](https://console.hetzner.cloud/) (VNC) para acceso de emergencia.

### 2. Ejecutar Terraform con Workspaces

```bash
# Desde terraform/
terraform init

# Seleccionar workspace de producción
terraform workspace select production
# Si es la primera vez, crear: terraform workspace new production

# Revisar plan
terraform plan -var-file=production.tfvars

# Aplicar (crear infraestructura)
terraform apply -var-file=production.tfvars

# Guardar IP del servidor
terraform output -raw server_ipv4 > ../server_ip.txt
```

**¿Qué son los workspaces?**

- Permiten gestionar múltiples entornos (production, staging) con el mismo código
- Estados de Terraform aislados por workspace

- Uso: `terraform workspace select <nombre>`

**Recursos creados:**

- ✅ Servidor ARM64 CAX11
- ✅ Firewall (SSH + HTTP/HTTPS)
- ✅ Reverse DNS
- ✅ Cloudflare DNS (si enabled)

---

## Deployment con Ansible

### 1. Verificar Inventario Dinámico

Ansible detecta automáticamente el servidor creado por Terraform:

```bash
cd ../ansible

# Verificar que detecta el servidor
export HCLOUD_TOKEN="tu_token_hetzner"
ansible-inventory -i inventory/hetzner.hcloud.yml --list

# Test de conectividad
ansible all -m ping
```

**Nota:** El inventario dinámico usa labels de Terraform (`environment=production`) para agrupar servidores automáticamente.

### 2. Ejecutar Playbook Completo

```bash
# 1) Bootstrap Transit (auto-unseal)
ansible-playbook -i inventory/production.yml \
  playbooks/openbao-transit-bootstrap.yml \
  -e openbao_transit_bootstrap_ack=true --ask-vault-pass

# 2) Guardar el auto-unseal token en Ansible Vault
ansible-vault edit inventory/group_vars/all/secrets.yml

# 3) Deployment completo (todos los roles)
ansible-playbook -i inventory/production.yml playbooks/site.yml --ask-vault-pass

# O por tags específicos:
ansible-playbook -i inventory/production.yml playbooks/site.yml \
  --tags common,security,nginx,wordpress \

  --ask-vault-pass
```

**Roles desplegados:**

1. `common` - Usuario, SSH, packages
2. `security_hardening` - Kernel, sysctl, fail2ban
3. `firewall` - UFW rules
4. `apparmor` - Profiles
5. `nginx_wordpress` - Nginx 1.28.1 + PHP 8.4
6. `valkey` - Cache Redis-compatible
7. `monitoring` - Prometheus + Grafana + Loki

**Tiempo:** ~15-20 minutos

---

## Configuración Post-Deployment

### 1. Completar Instalación WordPress

```bash
# Obtener IP del servidor
cat ../server_ip.txt


# Acceder vía navegador
https://TU_DOMINIO/wp-admin
```

**Datos de acceso (desde Ansible Vault):**

- Usuario admin: `vault_nginx_wordpress_admin_user`
- Contraseña: `vault_nginx_wordpress_admin_password`
- Email: `vault_nginx_wordpress_admin_email`

### 2. Configurar Cloudflare (Si Aplica)

#### Opción A: DNS Automático (Terraform)

Si `enable_cloudflare = true` en `terraform.prod.tfvars`:

- ✅ DNS A record creado automáticamente
- Solo necesitas: Cambiar nameservers en tu registrar

#### Opción B: Manual

1. Ir a Cloudflare Dashboard
2. Agregar sitio: `tudominio.com`
3. Crear A record:

   - Nombre: `@`
   - IPv4: `[IP del servidor]`
   - Proxy: ✅ Proxied (naranja)

### 3. Configurar SSL/TLS

**Con Cloudflare (proxy ON recomendado):**

- Cloudflare → SSL/TLS → Overview → **Full (strict)**
- Edge Certificates → Always Use HTTPS: ✅
- Ansible emite el cert Let's Encrypt vía DNS-01 (token en Vault).

**Sin Cloudflare (proxy OFF):**

- Puedes usar HTTP-01, pero requiere que los registros estén en “DNS only”.

---

## Verificación

### 1. Verificar Servicios

```bash
ssh malpanez@TU_IP

# Verificar servicios críticos
sudo systemctl status nginx
sudo systemctl status php8.4-fpm
sudo systemctl status mariadb
sudo systemctl status valkey
sudo systemctl status prometheus
sudo systemctl status grafana-server
```

### 2. Verificar WordPress

```bash
# Test HTTP
curl -I http://TU_IP

# Test HTTPS (si configuraste SSL)
curl -I https://tudominio.com
```

### 3. Acceder a Grafana

```
URL: http://TU_IP:3000
User: admin
Pass: (ver en ansible/group_vars/all/secrets.yml desencriptado)
```

**Dashboards instalados:**

- Node Exporter Full (métricas sistema)
- Loki Logs Dashboard (logs centralizados)
- Prometheus Stats

---

## Troubleshooting

### Terraform Falla

```bash
# Error: API token invalid
export HCLOUD_TOKEN="verificar_token"

# Error: SSH key format
cat ~/.ssh/id_ed25519.pub  # Debe empezar con "ssh-ed25519"
```

### Ansible No Conecta

```bash
# Verificar inventario dinámico
ansible-inventory -i inventory/hetzner.hcloud.yml --graph

# Test SSH directo
ssh -i ~/.ssh/id_ed25519 malpanez@TU_IP

# Verificar firewall permite tu IP
# Hetzner Console → Firewalls → Revisar regla SSH
```

### WordPress No Carga

```bash
# Verificar Nginx
sudo systemctl status nginx
sudo nginx -t

# Verificar PHP-FPM
sudo systemctl status php8.4-fpm

# Verificar logs
sudo tail -f /var/log/nginx/error.log
```

---

## Próximos Pasos

### Optimizaciones

1. **Cloudflare Cache Rules**
   - Page Rules para cacheo agresivo de assets
   - Ver: `docs/infrastructure/CLOUDFLARE_SETUP.md`

2. **Monitoreo**
   - Configurar alertas en Grafana
   - Ver: `docs/guides/GRAFANA_ALERTS_TROUBLESHOOTING.md`

3. **Backups**
   - Hetzner Backups (+20% costo)
   - Configurar snapshots automáticos
   - Ver: `docs/security/BACKUP_RECOVERY.md`

### Seguridad Adicional

1. **SSH 2FA**
   - Ver: `docs/security/SSH_2FA_INITIAL_SETUP.md`

2. **Fail2ban Fine-tuning**
   - Revisar `/etc/fail2ban/jail.local`
   - Ajustar bans según tráfico

---

## Referencias

- [Architecture Overview](../architecture/SYSTEM_OVERVIEW.md)
- [ARM64 vs x86 Performance](../performance/ARM64_vs_X86_COMPARISON.md)
- [Ansible Best Practices](ANSIBLE_BEST_PRACTICES.md)
- [Troubleshooting Guide](TROUBLESHOOTING.md)

---

**✅ Si todo funciona correctamente, tu stack WordPress ARM64 está desplegado y listo para producción.**
