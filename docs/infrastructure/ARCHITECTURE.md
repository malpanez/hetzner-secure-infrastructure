# Arquitectura de Infraestructura - Two Minds Trading

## Visión General

Infraestructura WordPress en Hetzner Cloud para sitio educativo con LearnDash LMS.

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLOUDFLARE (CDN + DNS)                   │
│                    - DNS Management                              │
│                    - SSL/TLS Termination                         │
│                    - DDoS Protection                             │
│                    - WAF Rules                                   │
│                    - Rate Limiting                               │
└────────────────────┬────────────────────────────────────────────┘
                     │ HTTPS
                     ▼
┌─────────────────────────────────────────────────────────────────┐
│                    HETZNER CLOUD SERVER                         │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                      NGINX                                │  │
│  │  - Web Server                                            │  │
│  │  - Reverse Proxy                                         │  │
│  │  - FastCGI Cache                                         │  │
│  │  - Gzip/Brotli Compression                              │  │
│  └─────────────┬────────────────────────────────────────────┘  │
│                │                                                │
│                ▼                                                │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   PHP 8.4-FPM                            │  │
│  │  - WordPress Core                                        │  │
│  │  - LearnDash LMS                                         │  │
│  │  - Security Plugins (Wordfence, Sucuri)                 │  │
│  └─────────────┬────────────────────────────────────────────┘  │
│                │                                                │
│     ┌──────────┴──────────┬──────────────────┐                │
│     ▼                     ▼                  ▼                 │
│  ┌──────────┐      ┌──────────┐      ┌──────────┐            │
│  │ MariaDB  │      │  Valkey  │      │   Fail2  │            │
│  │          │      │  (Redis) │      │   ban    │            │
│  │ Database │      │  Cache   │      │   IDS    │            │
│  └──────────┘      └──────────┘      └──────────┘            │
│                                                                │
│  Security Layer:                                              │
│  - UFW Firewall (ports 22, 80, 443)                          │
│  - SSH 2FA (Yubikey + PAM Google Authenticator)              │
│  - AppArmor profiles                                          │
│  - Kernel hardening (sysctl)                                  │
│  - Auto security updates                                      │
└─────────────────────────────────────────────────────────────────┘
```

---

## Componentes del Stack

### 1. Frontend Layer

#### **Cloudflare** (DNS + CDN + Security)
- **Plan**: Free
- **Funciones**:
  - DNS management (nameservers apuntan a Cloudflare)
  - SSL/TLS termination (modo "Full (strict)" recomendado)
  - DDoS protection automático
  - WAF (Web Application Firewall)
  - Rate limiting para wp-login.php
  - Page Rules para caché estático
  - Analytics básico

#### **Nginx** (Web Server)
- **Versión**: Latest stable (Debian 13 repos)
- **Configuración**:
  - FastCGI cache para WordPress
  - Gzip compression (nivel 6)
  - Security headers (X-Frame-Options, CSP, etc.)
  - Rate limiting para login/admin
  - Cloudflare real IP restoration
  - HTTPS redirect (cuando SSL esté configurado)

### 2. Application Layer

#### **PHP 8.4-FPM**
- **Versión**: 8.4 (latest en Debian 13)
- **Pool configuration**:
  - Dedicated pool para WordPress
  - PM: dynamic (based on server resources)
  - Max children: auto-tuned
  - Request terminate timeout: 300s
  - OPcache habilitado

#### **WordPress**
- **Versión**: Latest (via WP-CLI)
- **Plugins instalados automáticamente**:
  1. **Wordfence Security** - WAF + 2FA + Scanning
  2. **Sucuri Security** - Auditoría + Monitoreo
  3. **WP 2FA** - Two-factor authentication
  4. **UpdraftPlus** - Backups
  5. **Redis Object Cache** - Caché de objetos (Valkey backend)
  6. **Yoast SEO** - SEO optimization
  7. **Enable Media Replace** - Media management
  8. **WP Mail SMTP** - Email delivery
  9. **Health Check** - Site monitoring

- **Plugin manual**: LearnDash Pro (requiere licencia)

### 3. Data Layer

#### **MariaDB 10.11**
- **Rol**: geerlingguy.mysql
- **Database**: `wordpress`
- **Usuario**: `wordpress` (privilegios restringidos)
- **Configuración**:
  - InnoDB storage engine
  - UTF8MB4 charset
  - Backups automáticos (UpdraftPlus)

#### **Valkey 8.0** (Redis fork)
- **Función**: Object cache para WordPress
- **Configuración**:
  - Socket Unix (/run/valkey/valkey.sock)
  - No expuesto a red (solo local)
  - Maxmemory policy: allkeys-lru
  - Persistence: RDB snapshots

### 4. Security Layer

#### **UFW Firewall**
- **Puertos abiertos**:
  - 22/tcp (SSH - solo IPs autorizadas)
  - 80/tcp (HTTP - Cloudflare IPs)
  - 443/tcp (HTTPS - Cloudflare IPs)
- **Default**: deny incoming, allow outgoing

#### **Fail2ban**
- **Jails activos**:
  - sshd (max 5 attempts)
  - nginx-limit-req (rate limiting)
  - wordpress (wp-login.php brute force)
- **Ban time**: 3600s (1 hora)
- **Find time**: 600s (10 minutos)

#### **SSH Hardening**
- **Autenticación**:
  - SSH key required (Yubikey ED25519-SK)
  - Password authentication disabled
  - Root login disabled
  - 2FA con Google Authenticator PAM (ver docs/security/SSH-2FA.md)
- **Configuración**:
  - Port: 22 (cambiar a custom en producción)
  - Protocol: 2 only
  - Ciphers: strong only

#### **AppArmor**
- **Perfiles habilitados**:
  - php-fpm
  - nginx
  - sshd
  - fail2ban

#### **Kernel Hardening**
- **Sysctl settings**:
  - IP forwarding disabled
  - SYN cookies enabled
  - ICMP redirects ignored
  - Source routing disabled
  - Secure redirects enabled

---

## Entornos

### **Staging**
- **Servidor**: Hetzner CX22
- **Coste**: ~€5.83/mes
- **Recursos**:
  - 2 vCPU
  - 4 GB RAM
  - 40 GB NVMe SSD
  - 20 TB traffic
- **Ubicación**: Falkenstein, Germany (fsn1)
- **Uso**: Testing y validación pre-producción

### **Production**
- **Servidor**: Hetzner CPX31 (recomendado)
- **Coste**: ~€13.90/mes
- **Recursos**:
  - 4 vCPU AMD
  - 8 GB RAM
  - 160 GB NVMe SSD
  - 20 TB traffic
- **Ubicación**: Falkenstein, Germany (fsn1)
- **Backup**: Backups de Hetzner (20% coste adicional = €2.78/mes)

---

## Costes Mensuales Estimados

### Opción 1: Staging + Production Separados
```
Staging (CX22):               €5.83
Production (CPX31):          €13.90
Production Backups (20%):     €2.78
Cloudflare Free:              €0.00
──────────────────────────────────
TOTAL:                       €22.51/mes
```

### Opción 2: Solo Production
```
Production (CPX31):          €13.90
Production Backups (20%):     €2.78
Cloudflare Free:              €0.00
──────────────────────────────────
TOTAL:                       €16.68/mes
```

**Notas**:
- Precios incluyen IVA (23% Portugal)
- Hetzner factura por hora (€0.008/hora CX22)
- Staging se puede destruir cuando no se usa
- No hay costes de transferencia (20TB incluidos)

---

## Flujo de Deployment

```
┌─────────────────┐
│  1. Terraform   │  Provisiona servidor en Hetzner
│                 │  - Crea servidor + firewall
│                 │  - Configura cloud-init
│                 │  - Genera inventory para Ansible
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  2. Cloud-Init  │  Configuración inicial del SO
│                 │  - Crea usuario malpanez
│                 │  - Instala SSH key
│                 │  - Configura sudo
│                 │  - Actualiza packages
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  3. Ansible     │  Configura stack completo
│                 │  - Common (timezone, locales, tools)
│                 │  - Security (UFW, Fail2ban, SSH, AppArmor)
│                 │  - MariaDB database
│                 │  - Valkey cache
│                 │  - Nginx web server
│                 │  - WordPress + plugins
└────────┬────────┘
         │
         ▼
┌─────────────────┐
│  4. Cloudflare  │  DNS + SSL + WAF
│                 │  - Configurar DNS records
│                 │  - Habilitar SSL/TLS
│                 │  - Configurar WAF rules
│                 │  - Rate limiting
└─────────────────┘
```

---

## Backup Strategy

### 1. **UpdraftPlus** (WordPress automático)
- **Frecuencia recomendada**:
  - Database: Daily
  - Files: Weekly
- **Destinos**:
  - Amazon S3 (recomendado)
  - Google Drive
  - Dropbox
  - FTP/SFTP

### 2. **Hetzner Backups** (servidor completo)
- **Frecuencia**: Automated daily snapshots
- **Retención**: Last 7 backups
- **Coste**: 20% del coste del servidor
- **Restauración**: Full server restore

### 3. **Git** (código + configuración)
- **Repositorio**: Codeberg (privado)
- **Incluye**:
  - Terraform configs
  - Ansible playbooks/roles
  - Scripts de deployment
- **NO incluye**: Secrets (*.tfvars, secrets.yml)

---

## Monitoreo

### Aplicación (WordPress)
- **Health Check plugin**: Status de PHP, MySQL, permisos
- **Wordfence**: Escaneos de seguridad + alertas
- **Redis Object Cache**: Gráficas de hit/miss ratio

### Sistema (Server)
- **Logs centralizados**:
  - `/var/log/nginx/` - Nginx access/error
  - `/var/log/php8.4-fpm/` - PHP-FPM
  - `/var/log/fail2ban.log` - IDS events
  - `/var/log/ufw.log` - Firewall
- **Herramientas**:
  - `htop` - Recursos en tiempo real
  - `netdata` - Dashboard web (opcional)

---

## Referencias

- Documentación Hetzner Cloud: https://docs.hetzner.com/cloud/
- WordPress Hardening: https://wordpress.org/support/article/hardening-wordpress/
- Nginx WordPress: https://www.nginx.com/resources/wiki/start/topics/recipes/wordpress/
- Cloudflare WordPress: https://developers.cloudflare.com/support/third-party-software/others/configuring-cloudflare-with-wordpress/
