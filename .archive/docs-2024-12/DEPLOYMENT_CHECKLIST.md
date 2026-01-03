# Deployment Checklist - Staging con Yubikey

Guía completa para re-desplegar staging con SSH keys residentes (-sk) y Yubikey OATH-TOTP.

---

## 📋 Fase 1: Preparación Local (Antes del Deployment)

### 1.1 Generar API Keys de Hetzner

**En Hetzner Cloud Console:**

1. Ve a: https://console.hetzner.cloud/
2. Selecciona proyecto **Staging**
3. Ve a `Security` → `API Tokens`
4. Click `Generate API Token`
   - Name: `Terraform Staging`
   - Permissions: `Read & Write`
   - Copy token (solo se muestra una vez!)
5. Repite para proyecto **Production**
   - Name: `Terraform Production`

**Guarda los tokens de forma segura** (password manager).

---

### 1.2 Actualizar Terraform Variables

```bash
# Copiar template
cp terraform/terraform.tfvars.example terraform/terraform.staging.tfvars

# Editar con tus valores
nano terraform/terraform.staging.tfvars
```

**Contenido de `terraform.staging.tfvars`:**

```hcl
# Hetzner API Token (nuevo)
hcloud_token = "TU_NUEVO_TOKEN_STAGING_AQUI"

# Project settings
environment = "staging"
server_name = "staging-wordpress"

# Server configuration
# Opción A: ARM64 (Recomendado para staging - 40% ahorro)
server_type    = "cax21"    # 4 vCPUs ARM, 8GB RAM, €8.30/mes
server_location = "fsn1"    # Falkenstein (ARM disponible)

# Opción B: x86_64 (Si prefieres compatibilidad total)
# server_type    = "cpx31"  # 4 vCPUs x86, 8GB RAM, €13.90/mes
# server_location = "nbg1"  # Nuremberg

server_image    = "debian-13"

# Cloudflare (completar después de migrar DNS)
cloudflare_api_token = ""  # Dejar vacío por ahora
cloudflare_zone_id   = ""

# Domain
domain = "staging.twomindstrading.com"

# SSH Keys (usar key regular por WSL2)
ssh_public_key_path = "~/.ssh/id_ed25519.pub"  # Regular key (funciona en WSL2)
# ssh_public_key_path = "~/.ssh/id_ed25519_sk.pub"  # Solo si lograste crear -sk

# Backups
enable_backups = true

# Tags
tags = {
  Environment = "staging"
  Project     = "WordPress-Trading-Academy"
  ManagedBy   = "Terraform"
}
```

---

### 1.3 Generar Secrets de WordPress

**Opción 1: Usar el generador oficial de WordPress**

```bash
# En tu navegador, ve a:
https://api.wordpress.org/secret-key/1.1/salt/

# Copia TODO el output y guárdalo en un archivo temporal
# Lo necesitarás para configurar Ansible después
```

**Opción 2: Usar script automatizado (crear uno)**

```bash
# Crear script generador
cat > scripts/generate-wp-secrets.sh <<'EOF'
#!/usr/bin/env bash
# Generate WordPress security keys and salts

set -euo pipefail

echo "Fetching WordPress security keys from API..."
echo ""

curl -s https://api.wordpress.org/secret-key/1.1/salt/

echo ""
echo ""
echo "Copy these values to:"
echo "  ansible/group_vars/wordpress/vault.yml"
echo ""
echo "Or store in password manager for later use."
EOF

chmod +x scripts/generate-wp-secrets.sh

# Ejecutar
./scripts/generate-wp-secrets.sh > /tmp/wp-secrets.txt
```

**Guarda el output** en tu password manager.

---

### 1.4 Crear SSH Key Residente (-sk) para Yubikey

**¿Qué es una SSH key residente?**

Una SSH key residente (FIDO2) se almacena **dentro de la Yubikey**, no en tu disco. Ventajas:

- ✅ La clave privada **nunca** sale de la Yubikey
- ✅ Requiere **touch físico** para cada autenticación
- ✅ Protegida por **PIN de Yubikey**
- ✅ Portable (puedes usar en cualquier PC con la Yubikey)

**Limitaciones:**

- ⚠️ Requiere soporte FIDO2 (Yubikey 5+ lo tiene)
- ⚠️ WSL2 tiene problemas con FIDO2 USB forwarding (por eso cambiamos antes)
- ⚠️ GitHub requiere configuración especial

---

### 1.5 Crear SSH Key Residente (2 opciones)

#### Opción A: SSH Key Residente en Yubikey (Ideal, pero WSL2 complicado)

```bash
# Verificar soporte FIDO2 en Yubikey
ykman fido info

# Generar SSH key residente
ssh-keygen -t ed25519-sk -O resident -O verify-required -C "malpanez@yubikey-staging"

# Opciones:
# -t ed25519-sk     : Tipo FIDO2/ECDSA
# -O resident       : Almacena en Yubikey (no en disco)
# -O verify-required: Requiere touch para CADA uso
# -C                : Comentario

# Cuando pida ubicación:
Enter file in which to save the key: /home/malpanez/.ssh/id_ed25519_sk

# PIN de Yubikey: (configura uno si no tienes)
Enter PIN for security key: ******

# Touch Yubikey cuando parpadee

# Se crean:
# ~/.ssh/id_ed25519_sk      (handle público, NO es la clave privada)
# ~/.ssh/id_ed25519_sk.pub  (clave pública)
```

**Problema en WSL2:**

```bash
# Si falla con error: "invalid format" o "no FIDO device found"
# WSL2 no soporta bien FIDO2 via USB forwarding

# SOLUCIÓN: Generar en Windows y copiar a WSL2
```

---

#### Opción B: SSH Key Regular + Yubikey OATH-TOTP (Actual, funciona)

Si WSL2 no coopera con `-sk`, **mantén setup actual**:

```bash
# Key actual (ya existe)
~/.ssh/id_ed25519      # Regular key (funciona en WSL2)
~/.ssh/id_ed25519.pub

# 2FA via Yubikey OATH-TOTP (configurarás después)
```

**Recomendación:** Usa Opción B por ahora (menos fricción en WSL2).

---

### 1.6 Agregar SSH Key a GitHub (si usas -sk)

```bash
# Si usaste -sk, agrega la nueva clave pública a GitHub
cat ~/.ssh/id_ed25519_sk.pub

# Ve a: https://github.com/settings/keys
# Click "New SSH Key"
# Title: "Yubikey FIDO2 - Staging"
# Key type: Authentication Key
# Key: pega contenido de id_ed25519_sk.pub
```

---

## 📋 Fase 2: Deployment

### 2.1 Desplegar Staging

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure

# Verificar Terraform
cd terraform
terraform init
terraform validate

# Plan con nueva configuración
terraform plan -var-file=terraform.staging.tfvars

# Revisar output, verificar:
# - Server type: cpx31
# - Location: nbg1
# - SSH key correcta
# - Backups enabled

# Apply
terraform apply -var-file=terraform.staging.tfvars

# Copiar IP del output
# staging_server_ip = "X.X.X.X"
```

---

### 2.2 Configurar con Ansible

```bash
cd ../ansible

# Verificar inventario generado
cat inventory/staging.yml

# Test conexión SSH
ansible staging -m ping

# Desplegar WordPress stack completo
ansible-playbook -i inventory/staging.yml playbooks/wordpress-only.yml

# Esto ejecutará:
# 1. common (timezone, packages)
# 2. security (UFW, Fail2ban, SSH 2FA setup)
# 3. mariadb (database)
# 4. valkey (Redis cache)
# 5. nginx (web server)
# 6. wordpress + learndash
```

---

## 📋 Fase 3: Configurar Yubikey 2FA

### 3.1 Configurar OATH-TOTP en Servidor

```bash
# SSH al servidor (aún sin 2FA)
ssh malpanez@X.X.X.X

# Ejecutar google-authenticator
google-authenticator

# Respuestas:
Do you want authentication tokens to be time-based? YES
Do you want me to update your ~/.google_authenticator file? YES
Do you want to disallow multiple uses of the same token? YES
Do you want to do so? (increase window) NO
Do you want to enable rate-limiting? YES

# IMPORTANTE: Copia estos valores:
# 1. SECRET KEY (base32, ej: JBSWY3DPEHPK3PXP)
# 2. Emergency scratch codes (5 códigos)

# Guarda en password manager
```

---

### 3.2 Agregar TOTP a Yubikey (Local WSL2)

```bash
# En tu máquina local WSL2
cd /home/malpanez/repos/hetzner-secure-infrastructure

# Ejecutar script de configuración
./scripts/yubikey-oath-setup.sh

# Cuando pregunte:
Enter server name: Hetzner-Staging
Paste SECRET KEY here: [pega el secret del paso anterior]
Require touch to generate TOTP codes? Y

# Verificar TOTP agregado
ykman oath accounts list
# Debería aparecer: SSH:Hetzner-Staging
```

---

### 3.3 Test SSH Login con 2FA

```bash
# Abrir NUEVA terminal (NO cerrar la sesión actual)
ssh malpanez@X.X.X.X

# Proceso:
# 1. SSH key authentication (touch Yubikey si usas -sk)
# 2. "Verification code:"
#    - En otra terminal: ykman oath accounts code "SSH:Hetzner-Staging"
#    - O usa alias: yubikey-totp
#    - Touch Yubikey (si configuraste touch)
#    - Copia código de 6 dígitos
# 3. Pega código en prompt SSH
# 4. Login exitoso!
```

---

## 📋 Fase 4: Configurar Yubikey para Sudo (Opcional)

### 4.1 Entender Challenge-Response para Sudo

**¿Qué es Challenge-Response?**

Yubikey puede almacenar un **secret compartido** y generar respuestas HMAC-SHA1 para desafíos. Esto permite:

- ✅ `sudo` requiere Yubikey touch (además de password)
- ✅ No requiere códigos TOTP (automático)
- ✅ Offline (no depende de reloj sincronizado)

**Slots disponibles en Yubikey:**

```
Slot 1: OTP (Yubico OTP) - Usado para servicios Yubico
Slot 2: Challenge-Response - Libre para usar con sudo
```

---

### 4.2 Configurar Challenge-Response (En Servidor)

```bash
# SSH al servidor
ssh malpanez@X.X.X.X

# Instalar pam-u2f (si no está)
sudo apt update
sudo apt install -y libpam-u2f

# Configurar Yubikey para Challenge-Response
ykpamcfg -2 -v

# Esto crea: ~/.yubico/challenge-XXXXXX
# Touch Yubikey cuando parpadee

# Verificar archivo creado
ls -la ~/.yubico/
```

---

### 4.3 Configurar PAM para Sudo

```bash
# Editar configuración PAM de sudo
sudo nano /etc/pam.d/sudo

# Agregar ANTES de la línea @include common-auth:
auth required pam_yubico.so mode=challenge-response chalresp_path=/home/%u/.yubico

# Archivo final debería verse:
#
# auth required pam_yubico.so mode=challenge-response chalresp_path=/home/%u/.yubico
# @include common-auth
# @include common-account
# @include common-session-noninteractive

# Guardar y salir (Ctrl+X, Y, Enter)
```

---

### 4.4 Test Sudo con Yubikey

```bash
# Abrir NUEVA terminal SSH (NO cerrar actual)
ssh malpanez@X.X.X.X

# Intentar sudo
sudo ls

# Proceso:
# 1. Touch Yubikey (parpadea)
# 2. Ingresa password de usuario
# 3. Comando ejecutado

# Si falla, revisa logs:
sudo journalctl -u ssh -f
```

---

## 📋 Fase 5: DNS y SSL

### 5.1 Migrar DNS a Cloudflare

**En GoDaddy:**

1. Ve a: https://dcc.godaddy.com/domains
2. Selecciona `twomindstrading.com`
3. Ve a `DNS` → `Nameservers`
4. Cambia a `Custom Nameservers`
5. **NO cambies aún**, primero configura Cloudflare

**En Cloudflare:**

1. Ve a: https://dash.cloudflare.com/
2. Click `Add a Site`
3. Ingresa: `twomindstrading.com`
4. Plan: `Free` (suficiente para staging)
5. Cloudflare detecta registros DNS existentes
6. Revisa registros, agregar:
   ```
   Type: A
   Name: staging
   Content: [IP del servidor staging]
   Proxy: Enabled (naranja)
   TTL: Auto
   ```
7. Cloudflare muestra nameservers:
   ```
   vera.ns.cloudflare.com
   walt.ns.cloudflare.com
   ```

**Volver a GoDaddy:**

8. Cambia nameservers a los de Cloudflare
9. Guarda cambios
10. **Propagación**: 24-48 horas (típicamente < 1 hora)

---

### 5.2 Crear Cloudflare API Token

```bash
# En Cloudflare Dashboard:
# Profile → API Tokens → Create Token

# Template: Edit zone DNS
# Permissions:
#   Zone - DNS - Edit
#   Zone - Zone - Read
# Zone Resources:
#   Include - Specific zone - twomindstrading.com

# Copy token (solo se muestra una vez)
```

**Actualizar Terraform:**

```bash
nano terraform/terraform.staging.tfvars

# Agregar:
cloudflare_api_token = "TU_TOKEN_CLOUDFLARE_AQUI"
cloudflare_zone_id   = "ZONE_ID_DE_CLOUDFLARE"  # Lo encuentras en Cloudflare dashboard

# Re-apply Terraform
terraform apply -var-file=terraform.staging.tfvars
```

---

### 5.3 Configurar SSL/TLS con Let's Encrypt

```bash
# SSH al servidor
ssh malpanez@staging.twomindstrading.com

# Instalar Certbot
sudo apt update
sudo apt install -y certbot python3-certbot-nginx

# Obtener certificado SSL
sudo certbot --nginx -d staging.twomindstrading.com

# Respuestas:
Email: alpanez.alcalde@gmail.com
Terms: Agree (A)
Share email: No (N)
Redirect HTTP to HTTPS: Yes (2)

# Certbot configura Nginx automáticamente

# Verificar renovación automática
sudo certbot renew --dry-run

# Test SSL
curl -I https://staging.twomindstrading.com
```

---

## 📋 Fase 6: Configuración Cloudflare

### 6.1 Configurar SSL/TLS en Cloudflare

```
Cloudflare Dashboard → SSL/TLS:

Overview:
- Mode: Full (strict)  # Requiere certificado válido en servidor

Edge Certificates:
- Always Use HTTPS: ON
- Minimum TLS Version: TLS 1.2
- Opportunistic Encryption: ON
- TLS 1.3: ON
- Automatic HTTPS Rewrites: ON
- Certificate Transparency Monitoring: ON
```

---

### 6.2 Configurar WAF y Security

```
Security → WAF:
- Managed rules: Cloudflare Managed Ruleset (Enabled)
- OWASP ModSecurity Core Rule Set (Enabled)

Security → Settings:
- Security Level: Medium
- Challenge Passage: 30 minutes
- Browser Integrity Check: ON

Security → Bots:
- Bot Fight Mode: ON (Free plan)
```

---

### 6.3 Configurar Rate Limiting

```
Security → WAF → Rate limiting rules:

Create rule:
- Name: WordPress Login Protection
- If incoming requests match:
  - Field: URI Path
  - Operator: equals
  - Value: /wp-login.php
- Then:
  - Action: Block
  - Duration: 1 hour
  - Requests: 10 per minute
```

---

## 📋 Resumen de Credenciales a Guardar

**Password Manager entries:**

```
Hetzner Cloud - Staging
- Username: (account email)
- Password: (Hetzner password)
- API Token: [token generado]
- Server IP: [IP del servidor]

WordPress - Staging
- URL: https://staging.twomindstrading.com/wp-admin
- Username: admin
- Password: [generado con wp-secrets]
- DB Name: wordpress_db
- DB User: wordpress_user
- DB Password: [en vault.yml]

SSH - Staging Server
- Host: staging.twomindstrading.com
- User: malpanez
- SSH Key: ~/.ssh/id_ed25519 (o id_ed25519_sk)
- 2FA: Yubikey OATH "SSH:Hetzner-Staging"
- Emergency codes: [5 scratch codes]

Yubikey OATH Accounts
- SSH:Hetzner-Staging (secret key guardado)

Cloudflare
- Email: alpanez.alcalde@gmail.com
- Password: (Cloudflare password)
- API Token: [token generado]
- Zone ID: [zone id]
```

---

## 🔍 Troubleshooting

### SSH 2FA no funciona

```bash
# Verificar PAM config
cat /etc/pam.d/sshd | grep google_authenticator

# Verificar archivo .google_authenticator existe
ls -la ~/.google_authenticator

# Verificar permisos
chmod 400 ~/.google_authenticator

# Ver logs SSH
sudo tail -f /var/log/auth.log
```

---

### Yubikey OATH no genera códigos

```bash
# Verificar Yubikey detectada
ykman info

# Listar cuentas
ykman oath accounts list

# Generar código manualmente
ykman oath accounts code "SSH:Hetzner-Staging"

# Si requiere touch, toca la Yubikey
```

---

### Sudo con Yubikey no funciona

```bash
# Verificar archivo challenge
ls -la ~/.yubico/

# Reconfigurar
ykpamcfg -2 -v

# Verificar PAM config
cat /etc/pam.d/sudo | grep yubico

# Test modo debug
sudo PAM_DEBUG=1 sudo ls
```

---

## 📚 Referencias

- [Yubikey Manager CLI](https://developers.yubico.com/yubikey-manager/)
- [SSH 2FA Guide](docs/security/SSH-2FA.md)
- [Yubikey Setup](docs/security/YUBIKEY_SETUP.md)
- [WordPress Post-Install](guides/WORDPRESS-POST-INSTALL.md)
- [Cloudflare SSL Modes](https://developers.cloudflare.com/ssl/origin-configuration/ssl-modes/)

---

## ✅ Checklist Final

```
Preparación:
☐ Generar Hetzner API tokens (Staging + Production)
☐ Generar WordPress secrets
☐ Decidir: SSH key regular o -sk (recomendado: regular por WSL2)
☐ Actualizar terraform.staging.tfvars

Deployment:
☐ terraform apply staging
☐ ansible-playbook wordpress-only.yml
☐ Verificar WordPress accesible via IP

Yubikey 2FA:
☐ google-authenticator en servidor
☐ Agregar OATH a Yubikey (yubikey-oath-setup.sh)
☐ Test SSH login con 2FA
☐ (Opcional) Configurar Challenge-Response para sudo

DNS & SSL:
☐ Migrar nameservers a Cloudflare
☐ Esperar propagación DNS (verificar con: dig staging.twomindstrading.com)
☐ Configurar SSL con certbot
☐ Configurar Cloudflare SSL mode: Full (strict)

Cloudflare Security:
☐ Habilitar WAF managed rules
☐ Configurar rate limiting para wp-login.php
☐ Habilitar Bot Fight Mode

WordPress Config:
☐ Cambiar admin password
☐ Instalar tema (Astra recomendado)
☐ Configurar plugins de seguridad (Wordfence, WP 2FA)
☐ Verificar Redis cache funcionando

Backup & Monitoring:
☐ Verificar Hetzner backups habilitados
☐ Configurar UpdraftPlus (backup a S3/Google Drive)
☐ Configurar alertas Fail2ban (opcional)

Testing:
☐ Test login SSH con Yubikey TOTP
☐ Test sudo con Yubikey (si configurado)
☐ Test WordPress admin access
☐ Test SSL (https://www.ssllabs.com/ssltest/)
☐ Test performance (GTmetrix/PageSpeed Insights)
```

---

## 🚀 Próximos Pasos (Post-Staging)

1. **Replicar para Production**: Mismo proceso con `terraform.production.tfvars`
2. **Configurar CI/CD**: Deploy automático con Woodpecker CI
3. **Configurar LearnDash**: Crear primer curso
4. **Diseñar sitio web**: Usar v0.dev + Elementor (ver WORDPRESS-POST-INSTALL.md)
5. **SEO**: Configurar Yoast SEO, sitemap XML
6. **Analytics**: Google Analytics + Search Console
7. **Email**: Configurar SMTP (SendGrid/Mailgun)

---

¡Buena suerte con el deployment! 🎉
