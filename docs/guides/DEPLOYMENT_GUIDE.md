# Deployment Guide - WordPress + LearnDash Trading Course Platform

**Stack**: Nginx + WordPress + MariaDB + Valkey + LearnDash
**Topology**: Single server (All-in-one) - Scenario 1
**Cost**: €9.40/month + €180/year (LearnDash)
**Timeline**: 2-3 hours setup + 1-2 days content

---

## 📋 Pre-Deployment Checklist

```yaml
✅ Hetzner Cloud account created
✅ Domain purchased (en GoDaddy)
✅ Cloudflare account created
✅ SSH key generated (~/.ssh/id_ed25519)
✅ LearnDash Pro license purchased ($199/year)
✅ Budget confirmed: €189.40 first month
```

---

## 🚀 Deployment Steps

### Step 1: Provision Hetzner Server (15 minutes)

#### 1.1 Create Server

```bash
# Via Hetzner Cloud Console:
https://console.hetzner.cloud/

1. Projects → Default Project → Servers → Add Server

2. Location: Falkenstein, Germany

3. Image: Debian 13 (Trixie)

4. Type: cx21
   - 2 vCPU
   - 4 GB RAM
   - 40 GB NVMe SSD
   - 20 TB traffic
   - Price: €9.40/month

5. Networking:
   ✅ Public IPv4
   ❌ Private network (not needed)

6. SSH Keys:
   - Add your public key (~/.ssh/id_ed25519.pub)

7. Name: wordpress-trading-prod

8. Labels (optional):
   - environment: production
   - project: trading-course

9. Click "Create & Buy Now"

10. ⚠️  IMPORTANT: Note the public IP address
    Example: 65.108.123.456
```

#### 1.2 Test SSH Connection

```bash
# Test connection (replace with your IP)
ssh root@65.108.123.456

# If successful, you'll see:
# root@wordpress-trading-prod:~#

# Exit
exit
```

---

### Step 2: Configure Cloudflare (20 minutes)

#### 2.1 Add Site to Cloudflare

```bash
1. Login: https://dash.cloudflare.com
2. Click "Add a Site"
3. Enter your domain: tudominio.com
4. Select plan: FREE (upgrade to Pro later)
5. Click "Add Site"
```

#### 2.2 Cloudflare Scans DNS

```
Cloudflare will import existing DNS records from GoDaddy
Review them, but we'll change them next
Click "Continue"
```

#### 2.3 Get Cloudflare Nameservers

```
Cloudflare provides 2 nameservers:
Example:
- alex.ns.cloudflare.com
- maya.ns.cloudflare.com

⚠️  COPY THESE - you'll need them for GoDaddy
```

#### 2.4 Configure DNS in Cloudflare

```yaml
# Delete old records, add these:

Record 1:
  Type: A
  Name: @
  Content: 65.108.123.456 (YOUR Hetzner IP)
  Proxy: ON (orange cloud) ✅
  TTL: Auto

Record 2:
  Type: A
  Name: www
  Content: 65.108.123.456 (YOUR Hetzner IP)
  Proxy: ON (orange cloud) ✅
  TTL: Auto

Click "Save"
```

#### 2.5 Update Nameservers in GoDaddy

```bash
1. Login: https://account.godaddy.com
2. My Products → Domains
3. Click on tudominio.com → Manage
4. Scroll to "Additional Settings"
5. Click "Manage" next to Nameservers
6. Select "I'll use my own nameservers"
7. Enter Cloudflare nameservers:
   - Nameserver 1: alex.ns.cloudflare.com
   - Nameserver 2: maya.ns.cloudflare.com
8. Click "Save"

⚠️  Propagation time: 2-24 hours (usually 2-4 hours)
```

#### 2.6 Configure Cloudflare Settings

While DNS propagates, configure Cloudflare:

```yaml
# SSL/TLS Settings
SSL/TLS → Overview:
  ✅ Full (strict) ← IMPORTANT!

SSL/TLS → Edge Certificates:
  ✅ Always Use HTTPS: ON
  ✅ HSTS: Enable (Max-Age: 6 months, Subdomains, Preload)
  ✅ Minimum TLS: 1.2
  ✅ TLS 1.3: ON
  ✅ Automatic HTTPS Rewrites: ON
  ✅ Certificate Transparency Monitoring: ON

# Speed → Optimization
Speed → Optimization:
  ✅ Auto Minify: JavaScript, CSS, HTML
  ✅ Brotli: ON
  ✅ Early Hints: ON
  ❌ Rocket Loader: OFF (conflicts with LearnDash)

# Caching
Caching → Configuration:
  ✅ Caching Level: Standard
  ✅ Browser Cache TTL: 4 hours
  ✅ Always Online: ON
  ❌ Development Mode: OFF

# Security
Security → Settings:
  ✅ Security Level: Medium
  ✅ Bot Fight Mode: ON (if available in FREE)
```

#### 2.7 Verify DNS Propagation

```bash
# Check if DNS has propagated
dig tudominio.com

# You should see your Hetzner IP in the answer section
# If you see Cloudflare IPs, that's correct (proxied)

# Also check:
dig www.tudominio.com

# Test with ping (might not work if ICMP blocked)
ping tudominio.com
```

---

### Step 3: Prepare Ansible Configuration (10 minutes)

#### 3.1 Navigate to Ansible Directory

```bash
cd ~/repos/hetzner-secure-infrastructure/ansible
```

#### 3.2 Create Secrets File

```bash
# Create secrets file
cat > inventory/group_vars/all/secrets.yml <<'EOF'
---
# Production Deployment Secrets
# ⚠️  IMPORTANT: This file will be encrypted with ansible-vault

# Server IPs
wordpress_server_ip: "65.108.123.456"  # ← REPLACE with YOUR IP
openbao_server_ip: ""  # Empty = same server
monitoring_server_ip: ""  # Empty = same server

# Domain
domain_name: "tudominio.com"  # ← REPLACE with YOUR domain

# Database Passwords (CHANGE these to strong passwords)
vault_mysql_root_password: "CHANGE_TO_STRONG_PASSWORD_32_CHARS"
vault_wordpress_db_password: "CHANGE_TO_STRONG_PASSWORD_32_CHARS"

# Grafana Admin Password
vault_grafana_admin_password: "CHANGE_TO_STRONG_PASSWORD_16_CHARS"

# WordPress Database
wordpress_db_name: "wordpress"
wordpress_db_user: "wordpress"
EOF

# Generate strong passwords (optional helper)
# Run this 3 times to get 3 different passwords:
openssl rand -base64 32

# Replace the passwords in secrets.yml with generated ones
nano inventory/group_vars/all/secrets.yml
```

#### 3.3 Encrypt Secrets File

```bash
# Encrypt with ansible-vault
ansible-vault encrypt inventory/group_vars/all/secrets.yml

# You'll be prompted for a vault password
# ⚠️  SAVE THIS PASSWORD - you'll need it for all deployments
# Suggestion: Save in password manager (1Password, Bitwarden, etc.)

# Verify encryption
cat inventory/group_vars/all/secrets.yml
# Should see: $ANSIBLE_VAULT;1.1;AES256...
```

---

### Step 4: Deploy Infrastructure (20-30 minutes)

#### 4.1 Test Ansible Connection

```bash
# Test connection to server
ansible -i inventory/production.yml wordpress_servers -m ping \
  --ask-vault-pass \
  -e "@inventory/group_vars/all/secrets.yml"

# Enter vault password when prompted
# You should see: SUCCESS
```

#### 4.2 Run Full Deployment

```bash
# Full deployment (20-30 minutes)
ansible-playbook -i inventory/production.yml playbooks/site.yml \
  --ask-vault-pass \
  -e "@inventory/group_vars/all/secrets.yml"

# Enter vault password when prompted

# The playbook will deploy:
# ✅ System hardening (firewall, fail2ban, apparmor)
# ✅ Nginx + FastCGI cache
# ✅ MariaDB 10.11
# ✅ PHP 8.3 + OpCache
# ✅ Valkey 8.0 (object cache)
# ✅ OpenBao (secrets management)
# ✅ Prometheus + Grafana (monitoring)
# ✅ SSL (Let's Encrypt via Certbot)
# ✅ Automated backups
# ✅ WordPress core

# Progress indicators:
# - [common] System updates...
# - [security-hardening] Configuring firewall...
# - [nginx-wordpress] Installing Nginx...
# - [mariadb] Installing MariaDB...
# - [valkey] Installing Valkey...
# - [openbao] Installing OpenBao...
# - [monitoring] Installing Prometheus...

# Expected output at end:
# PLAY RECAP *****
# wordpress-prod: ok=127 changed=89 unreachable=0 failed=0
```

#### 4.3 Verify Deployment

```bash
# Check all services are running
ansible -i inventory/production.yml wordpress_servers \
  -m shell -a "systemctl status nginx php8.3-fpm mariadb valkey-server" \
  --ask-vault-pass \
  -e "@inventory/group_vars/all/secrets.yml"

# All should show: active (running)
```

---

### Step 5: WordPress Setup (15 minutes)

#### 5.1 Access WordPress Installation

```bash
# Open browser to:
https://tudominio.com/wp-admin/install.php

# ⚠️  If you see SSL error, wait 5-10 minutes for Let's Encrypt
# ⚠️  If you see "Can't connect", DNS may still be propagating
```

#### 5.2 WordPress Installation Wizard

```yaml
Step 1: Select Language
  English (United States)

Step 2: Site Information
  Site Title: "Trading Academy Pro"
  Username: admin  # ⚠️  Change this to something unique!
  Password: (use strong password generator)
  Email: tu-email@ejemplo.com
  ✅ Discourage search engines (until launch)

Step 3: Install WordPress
  Click "Install WordPress"

Step 4: Login
  https://tudominio.com/wp-login.php
  Enter your credentials
```

---

### Step 6: Install Plugins (20 minutes)

#### 6.1 Install via WP-CLI (Faster)

```bash
# SSH to server
ssh admin@65.108.123.456  # Ansible created 'admin' user

# Switch to WordPress directory
cd /var/www/tudominio.com

# Install LearnDash Pro (manual - requires license)
# Download from LearnDash.com → Account → Downloads
# Upload via WordPress admin: Plugins → Add New → Upload Plugin

# Install Free Plugins via WP-CLI
sudo -u www-data wp plugin install --activate \
  woocommerce \
  redis-cache \
  wordfence \
  yoast-seo-premium \
  elementor

# Verify installations
sudo -u www-data wp plugin list
```

#### 6.2 Configure Redis Object Cache

```bash
# Enable Redis cache
sudo -u www-data wp redis enable

# Verify it's working
sudo -u www-data wp redis status

# Should see:
# Status: Connected
# Client: phpredis
# Scheme: unix
```

#### 6.3 Install LearnDash Pro (Manual)

```yaml
1. Download LearnDash from your account:
   https://www.learndash.com/your-account/

2. WordPress Admin: Plugins → Add New → Upload Plugin

3. Choose learndash-X.X.X.zip

4. Click "Install Now"

5. Activate plugin

6. LearnDash → Settings → LMS License
   Enter your license key

7. Verify activation
```

---

### Step 7: Install Theme (15 minutes)

#### 7.1 Install Astra Theme

```bash
# Via WP-CLI
ssh admin@65.108.123.456
cd /var/www/tudominio.com

sudo -u www-data wp theme install astra --activate

# Or via WordPress Admin:
# Appearance → Themes → Add New → Search "Astra" → Install → Activate
```

#### 7.2 Import Starter Template (Optional)

```yaml
# For faster setup, import a pre-built template

1. Install: Astra Sites (plugin for templates)
   Plugins → Add New → Search "Starter Templates" → Install

2. Appearance → Starter Templates

3. Select: "Online Course" or "eLearning" template

4. Import:
   ✅ Import content
   ✅ Import widgets
   ✅ Import settings
   ❌ Import forms (not needed)

5. Wait 5-10 minutes for import

6. Result: Professional site structure ready to customize
```

---

### Step 8: Configure LearnDash (30 minutes)

#### 8.1 LearnDash Settings

```yaml
LearnDash → Settings:

General:
  ✅ Course Builder: Block-based (modern)
  ✅ Focus Mode: Enabled
  ✅ Course Navigation: Previous/Next buttons

Courses:
  ✅ Course Archive: Show all courses
  ✅ Course Sorting: Custom order
  ✅ Course Access: Open (or Closed - requires enrollment)

Lessons:
  ✅ Lesson Progression: Linear
  ✅ Sample Lesson: Disabled
  ✅ Video Progression: Enabled (students must watch video)

Quizzes:
  ✅ Quiz Builder: Block-based
  ✅ Quiz Time Limit: Optional per quiz
  ✅ Quiz Attempts: Limit to 3 attempts
  ✅ Passing Score: 80%
  ✅ Show Correct Answers: After quiz completion

Certificates:
  ✅ Enable certificates
  ✅ Design custom certificate (logo, signature)
```

#### 8.2 Create First Course

```yaml
LearnDash → Courses → Add New:

Title: "Trading Profesional - De Cero a Experto"

Course Builder:
  ├── Section 1: Fundamentos del Trading
  │   ├── Lección 1.1: Introducción a los Mercados
  │   ├── Lección 1.2: Tipos de Análisis
  │   └── Quiz 1: Fundamentos
  │
  ├── Section 2: Análisis Técnico
  │   ├── Lección 2.1: Velas Japonesas
  │   ├── Lección 2.2: Soportes y Resistencias
  │   └── Quiz 2: Análisis Técnico
  │
  └── ... (continuar estructura)

Course Settings:
  ├── Price: $3,000
  ├── Access Mode: Closed (requires purchase)
  ├── Certificate: Trading Pro Certificate
  └── Drip Content:
      ├── Section 1: Available immediately
      ├── Section 2: 7 days after Section 1 completion
      └── Section 3: 14 days after Section 2 completion
```

---

### Step 9: Configure WooCommerce (20 minutes)

#### 9.1 WooCommerce Setup Wizard

```yaml
WooCommerce → Home → Setup Wizard:

Store Details:
  Country: España (or your country)
  Currency: USD ($)
  ✅ I am selling products or services

Industry:
  Select: Education & Training

Product Types:
  ✅ Courses / Bookings / Subscriptions

Business Details:
  ✅ I'm just starting
  Products: 1-10
  Selling online: Yes

Theme:
  ✅ Continue with active theme (Astra)

Extensions:
  ❌ Skip all (not needed for MVP)
```

#### 9.2 Payment Gateways

```yaml
WooCommerce → Settings → Payments:

Enable:
  ✅ Stripe: (requires Stripe account)
  ✅ PayPal: (requires PayPal Business account)

Stripe Setup:
  1. Get Stripe account: https://stripe.com
  2. Install: WooCommerce Stripe Payment Gateway
  3. WooCommerce → Settings → Payments → Stripe
  4. Enter API keys from Stripe Dashboard

PayPal Setup:
  1. Get PayPal Business: https://paypal.com/business
  2. WooCommerce → Settings → Payments → PayPal
  3. Enter PayPal email address
```

#### 9.3 Create Course Product

```yaml
Products → Add New:

Title: "Curso Trading Profesional - $3,000"
Price: 3000 (USD)
Type: Simple product

Product Data:
  General:
    Regular price: $3,000
    Sale price: $2,500 (early bird - optional)

  Inventory:
    Stock: 10 (first cohort limit)
    ✅ Allow backorders: Do not allow

  Linked Products:
    ❌ Upsells (not needed yet)

  Advanced:
    Purchase Note: "Gracias por tu compra! Recibirás acceso al curso en 5 minutos."

LearnDash Integration:
  ✅ Associate with course: "Trading Profesional"
  ✅ Auto-enroll after purchase

Publish
```

---

### Step 10: Create Landing Page (60 minutes)

#### 10.1 With Elementor (if installed)

```yaml
Pages → Add New:

Title: Home

Click "Edit with Elementor"

Sections to create:
1. Hero Section:
   - Headline: "Domina el Trading Profesional"
   - Subheadline: "De principiante a trader rentable en 8 semanas"
   - CTA Button: "Reserva tu Plaza - $3,000"
   - Background: Trading charts image (Unsplash)

2. Problem/Solution:
   - "¿Estás perdiendo dinero en trading?"
   - 3 pain points
   - "Este curso te da el sistema completo"

3. What's Included:
   - ✅ 30+ horas de video
   - ✅ Estrategias probadas
   - ✅ Análisis en tiempo real
   - ✅ Certificado profesional

4. Course Modules:
   - List 4 modules with brief descriptions

5. Instructor Bio:
   - Tu foto
   - Credenciales
   - Track record (if shareable)

6. Pricing:
   - ~~$4,000~~ (original price, crossed out)
   - $3,000 (current price)
   - "Solo 10 plazas disponibles"
   - CTA: "Inscribirme Ahora"

7. FAQ:
   - 5-8 common questions

8. Final CTA:
   - "Empieza Tu Viaje de Trading Hoy"
   - Button to checkout

Publish
```

#### 10.2 Set as Homepage

```yaml
Settings → Reading:
  ✅ Your homepage displays: A static page
  Homepage: Home
  Posts page: Blog (create blank page first)

Save Changes
```

---

### Step 11: SSL Certificate (Automatic)

```bash
# Certbot should have run automatically during Ansible deployment
# Verify SSL certificate:

ssh admin@65.108.123.456

# Check certificate
sudo certbot certificates

# Should see:
# Found the following certs:
#   Certificate Name: tudominio.com
#     Domains: tudominio.com www.tudominio.com
#     Expiry Date: 2025-03-26 (89 days)
#     Certificate Path: /etc/letsencrypt/live/tudominio.com/fullchain.pem
#     Private Key Path: /etc/letsencrypt/live/tudominio.com/privkey.pem

# Auto-renewal is configured (systemd timer)
sudo systemctl status certbot.timer
# Should show: active (waiting)
```

---

### Step 12: Monitoring Setup (10 minutes)

#### 12.1 Access Grafana

```bash
# Open browser:
http://65.108.123.456:3000

# Or if DNS propagated:
http://tudominio.com:3000

# ⚠️  Note: Grafana is on port 3000, not standard HTTP

Login:
  Username: admin
  Password: (from secrets.yml - vault_grafana_admin_password)
```

#### 12.2 Add Dashboards

```yaml
# Dashboard 1: Node Exporter Full
1. Click "+" → Import
2. Enter dashboard ID: 1860
3. Select datasource: Prometheus
4. Click "Import"

# Dashboard 2: Redis/Valkey Stats
1. Click "+" → Import
2. Enter dashboard ID: 7362
3. Select datasource: Prometheus
4. Click "Import"

# You now have:
├── CPU, RAM, Disk, Network metrics
├── Valkey cache hit/miss ratio
└── System health overview
```

---

## ✅ Post-Deployment Checklist

```yaml
✅ Server Status:
   - SSH access working: ssh admin@IP
   - Nginx running: systemctl status nginx
   - MariaDB running: systemctl status mariadb
   - PHP-FPM running: systemctl status php8.3-fpm
   - Valkey running: systemctl status valkey-server

✅ SSL/TLS:
   - HTTPS working: https://tudominio.com
   - Certificate valid: Check browser lock icon
   - Cloudflare SSL mode: Full (strict)

✅ WordPress:
   - Admin access: https://tudominio.com/wp-admin
   - Plugins installed: LearnDash, WooCommerce, etc.
   - Theme installed: Astra
   - Valkey enabled: wp redis status

✅ LearnDash:
   - Course created
   - Drip content configured
   - Certificates designed
   - Quiz settings configured

✅ WooCommerce:
   - Payment gateways configured
   - Course product created
   - Test purchase (use Stripe test mode)

✅ Monitoring:
   - Grafana accessible: http://IP:3000
   - Dashboards imported
   - Metrics collecting

✅ Backups:
   - Automated backups configured
   - Check: ls /var/backups/
   - Should see: mysql/, valkey/, wordpress/

✅ Security:
   - Firewall enabled: ufw status
   - Fail2ban running: fail2ban-client status
   - SSH key-only (no passwords)
   - Strong passwords used
```

---

## 🎯 Next Steps

```yaml
Week 1-2: Content Creation
├── Write first 5 lesson texts
├── Create PDF resources
├── Design quiz questions
└── Record first module videos (optional - can do later)

Week 2-3: Video Strategy
├── Option A: Use Bunny.net for MVP (€2.50/mes)
├── Option B: Wait until first sale, use InfoProtector
└── Placeholder text: "Video disponible próximamente"

Week 3-4: Marketing
├── Email sequence for 10 leads
├── Social media teasers
├── Pre-launch offer: $2,500 early bird
└── Launch to first cohort (5-10 students)

Week 5+: Scale
├── After first sales: Upgrade to InfoProtector
├── After first sales: Upgrade Cloudflare to Pro
├── Continue adding content based on student feedback
└── Monitor Grafana metrics for scaling triggers
```

---

## 🆘 Troubleshooting

### Issue: Can't Access Website

```bash
# Check DNS propagation
dig tudominio.com

# Check Nginx
ssh admin@IP
sudo systemctl status nginx

# Check firewall
sudo ufw status
# Should allow: 22/tcp, 80/tcp, 443/tcp

# Check Cloudflare
# Ensure "Proxy" is ON (orange cloud)
```

### Issue: SSL Certificate Error

```bash
# Wait 5-10 minutes after DNS propagation
# Certbot runs automatically

# Manually trigger if needed:
ssh admin@IP
sudo certbot --nginx -d tudominio.com -d www.tudominio.com

# Check Cloudflare SSL mode
# Must be: Full (strict)
```

### Issue: WordPress Database Connection Error

```bash
# Check MariaDB
ssh admin@IP
sudo systemctl status mariadb

# Check database exists
sudo mysql
SHOW DATABASES;
# Should see: wordpress

# Check user permissions
SELECT User, Host FROM mysql.user WHERE User='wordpress';
```

### Issue: Valkey Not Working

```bash
# Check Valkey status
ssh admin@IP
sudo systemctl status valkey-server

# Test connection
redis-cli ping
# Should return: PONG

# Check WordPress integration
sudo -u www-data wp redis status
```

---

## 📞 Support Resources

```yaml
Documentation:
├── Architecture Decisions: docs/ARCHITECTURE_DECISIONS.md
├── Caching Stack: docs/CACHING_STACK.md
├── Why Not Varnish: docs/WHY_NOT_VARNISH.md
└── Inventory README: ansible/inventory/README.md

Community:
├── WordPress: https://wordpress.org/support/
├── LearnDash: https://www.learndash.com/support/
├── WooCommerce: https://woocommerce.com/document/
└── Hetzner: https://docs.hetzner.com/

Emergency:
├── Rollback: ansible-playbook rollback.yml (if created)
├── Restore backup: /var/backups/mysql/latest.sql.gz
└── Contact: tu-email@ejemplo.com
```

---

**Total Deployment Time**: 3-4 hours (active work)
**Total Setup Time**: 1-2 days (including DNS propagation)
**Cost**: €9.40/month + €180/year LearnDash = €24.90/month avg

**You're ready to launch! 🚀**
