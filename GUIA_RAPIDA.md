# Guía Rápida de Deployment - Versión Simple

**Para personas neurodivergentes:** Esta guía usa pasos numerados claros, sin información extra.

## ✅ ¿Qué necesito PAGAR?

### OBLIGATORIO (para empezar)
1. **LearnDash:** $199 USD → Comprar en https://learndash.com/pricing/
2. **Hetzner Cloud:** €5.39/mes → Se cobra automáticamente cuando creas el servidor

**TOTAL: ~$210 USD para empezar**

### NO necesitas pagar
- ❌ Cloudflare (gratis)
- ❌ SSL/Certificados (gratis)
- ❌ WordPress Core (gratis)
- ❌ Tu dominio (ya lo tienes)

---

## 📝 Pasos del Deployment (En Orden)

```mermaid
graph TD
    A[1. Comprar LearnDash] --> B[2. Crear API Token Hetzner]
    B --> C[3. Configurar archivos]
    C --> D[4. Terraform crea servidor]
    D --> E[5. Migrar DNS a Cloudflare]
    E --> F[6. Ansible configura servidor]
    F --> G[7. Instalar LearnDash manualmente]
    G --> H[8. ✅ Listo!]

    style A fill:#ffe1e1
    style B fill:#fff4e1
    style H fill:#e1ffe1
```

---

## 1️⃣ ANTES de empezar

### Comprar LearnDash
1. Ir a https://learndash.com/pricing/
2. Comprar licencia ($199 USD)
3. Descargar el archivo `.zip`
4. **GUARDAR** el archivo y la license key

### Obtener API Token de Hetzner
1. Ir a https://console.hetzner.cloud
2. Crear cuenta (tarjeta de crédito requerida)
3. Crear proyecto "wordpress-production"
4. Ir a: Security → API Tokens
5. Click "Generate API Token"
6. **COPIAR** el token (solo se muestra una vez)

---

## 2️⃣ Configurar archivos (tu máquina local)

### Paso 1: Crear archivo `.env`

```bash
# En la carpeta del proyecto
nano .env
```

**Copiar esto y cambiar TUS valores:**

```bash
export HCLOUD_TOKEN="pega-aqui-tu-token-de-hetzner"
export TF_VAR_hcloud_token="${HCLOUD_TOKEN}"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
export TF_VAR_admin_username="miguel"
export TF_VAR_ssh_allowed_ips='["TU.IP.AQUI/32"]'
```

**Para saber tu IP:**
```bash
curl -4 ifconfig.me
# Resultado ejemplo: 203.0.113.42
# Usar como: ["203.0.113.42/32"]
```

### Paso 2: Crear passwords fuertes

```bash
# Generar 3 passwords diferentes
openssl rand -base64 32
openssl rand -base64 32
openssl rand -base64 32
```

### Paso 3: Editar secrets

```bash
nano ansible/inventory/group_vars/all/secrets.yml
```

**Pegar los 3 passwords generados:**

```yaml
---
vault_grafana_admin_password: "password-1-aqui"
vault_mariadb_root_password: "password-2-aqui"
vault_wordpress_db_password: "password-3-aqui"
```

### Paso 4: Cifrar secrets

```bash
ansible-vault encrypt ansible/inventory/group_vars/all/secrets.yml
# Te pedirá una contraseña → GUARDARLA en lugar seguro
```

### Paso 5: Configurar Terraform

```bash
nano terraform/environments/production/terraform.tfvars
```

**Cambiar estos valores:**

```hcl
server_name     = "wordpress-prod"
admin_username  = "miguel"
ssh_allowed_ips = ["TU.IP.AQUI/32"]  # Usar tu IP real
allow_http      = true
allow_https     = true
volume_size     = 0  # 0 = sin disco extra (ahorra €2.40/mes)
```

---

## 3️⃣ Crear servidor con Terraform

```bash
# Cargar variables
source .env

# Ir a carpeta terraform
cd terraform/environments/production

# Inicializar
terraform init

# Ver qué se va a crear
terraform plan

# Crear servidor (SE COBRARÁ €5.39)
terraform apply
# Escribir: yes

# GUARDAR la IP del servidor
terraform output server_ip
# Ejemplo: 203.0.113.42
```

**⏱️ Tiempo: 2-3 minutos**

---

## 4️⃣ Configurar DNS en Cloudflare

### Migrar dominio de GoDaddy a Cloudflare

**En Cloudflare:**
1. Ir a https://dash.cloudflare.com
2. Click "Add a Site"
3. Escribir tu dominio
4. Elegir plan **Free**
5. Cloudflare te da 2 nameservers (ejemplo: `alex.ns.cloudflare.com`)

**En GoDaddy:**
1. Ir a https://account.godaddy.com
2. My Products → Domains → tu dominio
3. Manage DNS → Nameservers → Custom
4. Pegar los 2 nameservers de Cloudflare
5. Guardar

**⏱️ Esperar: 2-6 horas (puede ser hasta 48h)**

### Crear registros DNS

**En Cloudflare → DNS → Records:**

Crear **3 registros A**:

| Tipo | Nombre | IP | Proxy |
|------|--------|-----|-------|
| A | @ | TU.IP.DEL.SERVIDOR | ✅ ON |
| A | www | TU.IP.DEL.SERVIDOR | ✅ ON |
| A | monitoring | TU.IP.DEL.SERVIDOR | ❌ OFF |

### Configurar SSL

**En Cloudflare → SSL/TLS:**
- Overview: Cambiar a **Full (strict)**
- Edge Certificates: Activar **Always Use HTTPS**

**✅ Verificar DNS:**
```bash
dig tudominio.com +short
# Debe mostrar una IP
```

---

## 5️⃣ Configurar servidor con Ansible

### Opción A: Inventario Dinámico (automático)

```bash
cd ansible

# Crear variables de WordPress
mkdir -p inventory/group_vars/env_production
nano inventory/group_vars/env_production/wordpress.yml
```

**Contenido:**
```yaml
---
wordpress_domain: "tudominio.com"
wordpress_title: "Mi Plataforma LMS"
wordpress_admin_email: "admin@tudominio.com"
wordpress_db_name: "wordpress_prod"
wordpress_db_user: "wordpress"
grafana_domain: "monitoring.tudominio.com"
ansible_user: miguel
ansible_ssh_private_key_file: ~/.ssh/id_ed25519
```

**Ejecutar:**
```bash
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --ask-vault-pass
# Introducir la contraseña del vault
```

### Opción B: Inventario Estático (manual)

```bash
cd ansible
nano inventory/production/hosts.yml
```

**Contenido (cambiar IP):**
```yaml
---
all:
  children:
    wordpress_servers:
      hosts:
        wordpress-prod:
          ansible_host: 203.0.113.42  # TU IP AQUI
          ansible_user: miguel
          ansible_ssh_private_key_file: ~/.ssh/id_ed25519
      vars:
        wordpress_domain: "tudominio.com"
        wordpress_title: "Mi Plataforma LMS"
        wordpress_admin_email: "admin@tudominio.com"
        wordpress_db_name: "wordpress_prod"
        wordpress_db_user: "wordpress"
        grafana_domain: "monitoring.tudominio.com"
```

**Ejecutar:**
```bash
ansible-playbook -i inventory/production/hosts.yml playbooks/site.yml --ask-vault-pass
```

**⏱️ Tiempo: 15-25 minutos**

---

## 6️⃣ Instalar LearnDash (MANUAL)

1. Ir a `https://tudominio.com/wp-admin/install.php`
2. Crear usuario admin
3. Login en WordPress
4. Ir a: Plugins → Add New → Upload Plugin
5. Subir el archivo `learndash-xxx.zip` que descargaste
6. Click "Install Now"
7. Click "Activate"
8. Ir a: LearnDash LMS → Settings → LMS License
9. Introducir tu license key
10. Click "Update License"

---

## ✅ Verificar que todo funciona

### WordPress
```bash
# Abrir en navegador
https://tudominio.com
```
**Debe mostrar:** Sitio WordPress funcionando

### Grafana Monitoring
```bash
# Abrir en navegador
https://monitoring.tudominio.com
```
**Debe mostrar:** Página de login Grafana

### SSH al servidor
```bash
ssh miguel@tudominio.com
```
**Debe conectar** y pedir TOTP (código Google Authenticator)

---

## 🆘 Problemas Comunes

### "No puedo conectar por SSH"
- ✅ Verificar que tu IP está en `ssh_allowed_ips`
- ✅ Esperar 5 minutos después de `terraform apply`

### "WordPress no carga"
- ✅ Verificar DNS: `dig tudominio.com`
- ✅ Esperar propagación DNS (hasta 6 horas)

### "Ansible falla con vault"
- ✅ Verificar contraseña del vault
- ✅ Verificar que secrets.yml está cifrado

---

## 📊 Qué instala automáticamente Ansible

### ✅ SE INSTALA SOLO
- WordPress Core
- Nginx (web server)
- PHP-FPM
- MariaDB (database)
- Prometheus + Grafana (monitoring)
- UFW Firewall
- Fail2ban
- Auditd (logs de seguridad)

### ❌ DEBES INSTALAR MANUAL
- LearnDash Plugin ($199 - OBLIGATORIO)
- Wordfence Security (gratis - recomendado)
- UpdraftPlus Backups (gratis - recomendado)
- Otros plugins según necesidad

---

## 💰 Resumen de Gastos

### Hoy (para empezar)
- LearnDash: $199 USD
- Hetzner mes 1: €5.39
- **TOTAL: ~$210 USD**

### Cada mes
- Hetzner: €5.39/mes

### Cada año
- LearnDash renovación: $199 USD
- Dominio renovación: ~€12
- **TOTAL: ~€77/año**

---

## 🔑 Información Importante

### SSH Keys
- ✅ Puedes usar tu clave existente `~/.ssh/id_ed25519`
- ✅ NO necesitas crear claves nuevas
- ✅ La misma clave funciona para GitHub + Codeberg + Hetzner

### Usuario
- ✅ Usar `miguel` (tu nombre)
- ❌ NO usar `admin`, `root`, `administrator`

### Puerto SSH
- ✅ Mantener puerto 22 (estándar)
- ✅ Ya está protegido con IP filtering + 2FA

### Cloudflare
- ✅ Plan Free es suficiente
- ❌ NO necesitas Cloudflare Pro ($20/mes)

---

## 📞 Siguiente Paso

Después de completar todos los pasos, tu sitio estará en:
- **WordPress:** https://tudominio.com
- **Admin:** https://tudominio.com/wp-admin
- **Monitoring:** https://monitoring.tudominio.com

**¡Listo para crear cursos con LearnDash! 🎓**

---

**Nota:** Si algo no funciona, revisa [DEPLOYMENT_GUIDE.md](DEPLOYMENT_GUIDE.md) para más detalles.
