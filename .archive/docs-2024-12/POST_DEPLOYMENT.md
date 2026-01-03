# Guía Post-Deployment - Primeros Pasos

Esta guía te dice **QUÉ HACER DESPUÉS** de completar `terraform apply` + `ansible-playbook`.

## ✅ Checklist Post-Deployment (60 minutos)

### 1. Verificar que todos los servicios están corriendo (5 min)

```bash
# Conectar al servidor
ssh malpanez@tudominio.com

# Verificar servicios críticos
sudo systemctl status nginx
sudo systemctl status mariadb
sudo systemctl status php8.2-fpm
sudo systemctl status prometheus
sudo systemctl status grafana-server

# Todos deben mostrar: active (running)
```

**Si algún servicio falla:**
```bash
# Ver logs del servicio
sudo journalctl -u nginx -n 50

# Reintentar
sudo systemctl restart nginx
```

---

### 2. Acceder a WordPress por primera vez (10 min)

WordPress NO está configurado automáticamente - tienes que hacer la instalación inicial.

**Paso 1: Instalación de WordPress**

1. Abrir en navegador: `https://tudominio.com/wp-admin/install.php`
2. Seleccionar idioma: **Español**
3. Completar formulario:
   - **Título del sitio:** Mi Plataforma LMS
   - **Nombre de usuario:** admin (o personalizado)
   - **Contraseña:** (generar strong password)
   - **Tu correo electrónico:** admin@tudominio.com
   - ✅ **Desmarcar:** "Disuadir a los motores de búsqueda de indexar este sitio"
4. Click **"Instalar WordPress"**
5. **Login** con las credenciales creadas

**⚠️ CRÍTICO: Guardar las credenciales en tu gestor de contraseñas**

---

### 3. Instalar LearnDash (15 min)

LearnDash NO se instala automáticamente - es un plugin de pago que debes subir manualmente.

**Prerequisito:** Haber comprado LearnDash en https://learndash.com/pricing/ ($199/año)

**Paso 1: Subir plugin**

1. En WordPress Admin: **Plugins** → **Añadir nuevo**
2. Click **"Subir plugin"**
3. Click **"Seleccionar archivo"**
4. Buscar tu archivo `learndash-xxx.zip` (descargado desde learndash.com)
5. Click **"Instalar ahora"**
6. Esperar a que termine la instalación
7. Click **"Activar plugin"**

**Paso 2: Introducir license key**

1. En el menú lateral: **LearnDash LMS** → **Settings**
2. Tab: **LMS License**
3. Pegar tu **License Email** y **License Key** (de tu compra)
4. Click **"Update License"**
5. Debe mostrar: ✅ **"Active"**

**Paso 3: Configuración básica de LearnDash**

1. **LearnDash LMS** → **Settings** → **General**
   - Course Builder: **Gutenberg (recomendado)**
   - Default Course/Lesson/Topic/Quiz Builder: **Gutenberg**
2. **Settings** → **PayPal**
   - Si vas a vender cursos, configurar PayPal/Stripe
   - Si son gratis, dejar en blanco
3. **Settings** → **Emails**
   - Configurar plantillas de email (opcional)

**Paso 4: Crear tu primer curso de prueba**

1. **LearnDash LMS** → **Courses** → **Add New**
2. Título: "Curso de Prueba"
3. Configurar:
   - **Settings** (sidebar derecho):
     - Course Access Mode: **Open** (para testing)
   - **Course Builder:**
     - Añadir 1-2 lecciones de prueba
     - Añadir 1 quiz opcional
4. **Publish**
5. **Ver curso** en frontend para verificar que funciona

---

### 4. Configurar SMTP para envío de emails (10 min - OPCIONAL)

WordPress necesita SMTP configurado para enviar emails (registro de usuarios, recuperación de contraseña, notificaciones de cursos).

**Opciones de SMTP gratis:**
- **SendGrid:** 100 emails/día gratis
- **Mailgun:** 5,000 emails/mes gratis (primeros 3 meses)
- **Amazon SES:** ~$0.10 por 1,000 emails

**Paso 1: Obtener credenciales SMTP**

**Ejemplo con SendGrid (recomendado):**

1. Ir a https://sendgrid.com
2. Crear cuenta gratuita
3. Settings → API Keys → Create API Key
4. Nombre: "WordPress SMTP"
5. Permissions: **Full Access**
6. **Copy API Key** (se muestra UNA sola vez)

**Paso 2: Instalar plugin WP Mail SMTP**

1. WordPress Admin: **Plugins** → **Añadir nuevo**
2. Buscar: **"WP Mail SMTP"**
3. Instalar plugin **"WP Mail SMTP by WPForms"**
4. **Activar**

**Paso 3: Configurar SMTP**

1. **Settings** → **WP Mail SMTP**
2. **From Email:** noreply@tudominio.com
3. **From Name:** Mi Plataforma LMS
4. **Mailer:** SendGrid
5. **SendGrid API Key:** (pegar tu API key)
6. **Save Settings**

**Paso 4: Probar envío**

1. Tab: **Email Test**
2. **Send To:** tu-email-personal@gmail.com
3. Click **"Send Email"**
4. Verificar que recibes el email

---

### 5. Configurar SSH 2FA - TOTP (20 min)

Configurar 2FA SSH con Google Authenticator para mayor seguridad.

**Paso 1: Generar código QR TOTP**

```bash
# Conectar al servidor
ssh malpanez@tudominio.com

# Ejecutar google-authenticator
google-authenticator
```

**Responder a las preguntas:**

```
Do you want authentication tokens to be time-based? (y/n)
→ y

[Se muestra código QR y códigos de emergencia]

Do you want me to update your "/home/malpanez/.google_authenticator" file? (y/n)
→ y

Do you want to disallow multiple uses of the same token? (y/n)
→ y

By default, a new token is generated every 30 seconds... (y/n)
→ n

Do you want to enable rate-limiting? (y/n)
→ y
```

**Paso 2: Escanear código QR**

Con app móvil:
- **Google Authenticator** (iOS/Android)
- **Authy** (iOS/Android/Desktop)
- **1Password** (con soporte TOTP)
- **Bitwarden** (con soporte TOTP)

**Paso 3: Guardar códigos de emergencia**

```
Your emergency scratch codes are:
  12345678
  87654321
  ...
```

**⚠️ CRÍTICO: Guardar estos códigos en tu gestor de contraseñas**

Son códigos de un solo uso para acceder si pierdes el móvil.

**Paso 4: Probar 2FA**

1. Abrir nueva terminal (NO cerrar la actual todavía)
2. Intentar conectar:
   ```bash
   ssh malpanez@tudominio.com
   ```
3. Debe pedir:
   - **Passphrase de SSH key** (si tu clave tiene passphrase)
   - **Verification code:** (código TOTP de 6 dígitos)
4. Introducir código de Google Authenticator
5. Debe conectar

**Si falla el 2FA:**
- Usar uno de los códigos de emergencia
- Conectar con la terminal original (que sigue abierta)
- Revisar configuración de google-authenticator

---

### 6. Primer backup manual (5 min)

Hacer un backup manual inmediato para asegurar que los scripts funcionan.

```bash
# Conectar al servidor
ssh malpanez@tudominio.com

# Backup de Grafana
sudo /usr/local/bin/backup-grafana.sh

# Backup de Prometheus
sudo /usr/local/bin/backup-prometheus.sh

# Verificar que se crearon
ls -lh /var/backups/grafana/
ls -lh /var/backups/prometheus/
```

**⚠️ IMPORTANTE: Configurar backup de WordPress/MariaDB**

**PENDIENTE:** Los backups de WordPress y MariaDB NO están configurados por defecto.

**Backup manual de MariaDB mientras tanto:**

```bash
# Backup de base de datos WordPress
sudo mysqldump -u root wordpress_prod | gzip > /tmp/wordpress_$(date +%Y%m%d).sql.gz

# Copiar a tu máquina local
scp malpanez@tudominio.com:/tmp/wordpress_$(date +%Y%m%d).sql.gz ~/backups/
```

**Backup manual de WordPress files:**

```bash
# Comprimir /var/www/html
sudo tar czf /tmp/wordpress_files_$(date +%Y%m%d).tar.gz /var/www/html

# Copiar a tu máquina local
scp malpanez@tudominio.com:/tmp/wordpress_files_$(date +%Y%m%d).tar.gz ~/backups/
```

---

### 7. Verificar Monitoring (5 min)

Asegurar que Grafana y Prometheus están funcionando.

**Paso 1: Acceder a Grafana**

1. Abrir: `https://monitoring.tudominio.com`
2. **Login:**
   - Username: `admin`
   - Password: (vault_grafana_admin_password de secrets.yml)
3. Debe mostrar el dashboard de Grafana

**Paso 2: Verificar dashboards**

1. Click icono **"Dashboards"** (4 cuadrados) en sidebar
2. Debe haber 2 dashboards pre-instalados:
   - ✅ **Node Exporter Full**
   - ✅ **Prometheus Stats**
3. Click en **"Node Exporter Full"**
4. Debe mostrar:
   - ✅ Gráficas de CPU, RAM, Disk
   - ✅ Métricas actualizándose en tiempo real
   - ✅ Sin errores "No data"

**Si no aparecen datos:**

```bash
# Verificar Prometheus
sudo systemctl status prometheus

# Verificar Node Exporter
sudo systemctl status node-exporter

# Ver logs
sudo journalctl -u prometheus -n 50
```

**Paso 3: Cambiar password de Grafana (RECOMENDADO)**

1. Click icono perfil (abajo izquierda)
2. **Preferences** → **Change Password**
3. Old password: (vault_grafana_admin_password)
4. New password: (generar nuevo con `openssl rand -base64 32`)
5. **Save**
6. **Actualizar password en secrets.yml**

---

### 8. Configurar Permalinks de WordPress (2 min)

WordPress usa permalinks feos por defecto (`?p=123`). Cambiar a URLs amigables.

1. WordPress Admin: **Ajustes** → **Enlaces permanentes**
2. Seleccionar: **Nombre de la entrada**
   - URL ejemplo: `https://tudominio.com/nombre-del-curso/`
3. **Guardar cambios**

---

### 9. Plugins WordPress recomendados (10 min - OPCIONAL)

Instalar plugins adicionales útiles:

| Plugin | Propósito | Gratis/Pago |
|--------|-----------|-------------|
| **Wordfence Security** | Firewall + Malware scanner | Gratis |
| **UpdraftPlus** | Backups a Google Drive/Dropbox | Gratis |
| **Imagify** | Optimización de imágenes | Gratis (hasta 20MB/mes) |
| **WP Rocket** | Caché avanzado (opcional - Nginx ya cachea) | $59/año |

**Instalar Wordfence (RECOMENDADO):**

1. **Plugins** → **Añadir nuevo**
2. Buscar: **"Wordfence Security"**
3. **Instalar** → **Activar**
4. Completar setup wizard:
   - Email para alertas: admin@tudominio.com
   - Get free Wordfence license
5. **Run Scan** para verificar que no hay problemas

---

### 10. Verificar Stack de Caché (5 min)

Asegurar que el stack de caché funciona correctamente.

**Verificar Cloudflare CDN:**

```bash
# Hacer request y ver headers
curl -I https://tudominio.com

# Debe mostrar:
# cf-cache-status: HIT (segunda vez que accedes)
# server: cloudflare
```

**Verificar Nginx caché:**

```bash
ssh malpanez@tudominio.com

# Ver configuración de caché
sudo nginx -T | grep cache

# Ver si hay archivos cacheados
ls -lh /var/cache/nginx/ 2>/dev/null || echo "Cache vacío (normal al inicio)"
```

**Verificar Valkey (Redis):**

```bash
ssh malpanez@tudominio.com

# Conectar a Valkey
redis-cli ping
# Debe retornar: PONG

# Ver info
redis-cli INFO | grep connected_clients
# Debe mostrar: connected_clients:1 (o más)
```

**Verificar PHP OPcache:**

```bash
# Crear archivo PHP de prueba
echo '<?php phpinfo(); ?>' | sudo tee /var/www/html/info.php

# Visitar en navegador
https://tudominio.com/info.php

# Buscar sección "Zend OPcache"
# Debe mostrar: opcache.enable = On

# BORRAR archivo después (seguridad)
sudo rm /var/www/html/info.php
```

---

### 11. Verificar Sistema de Logs Loki + Promtail (5 min)

Asegurar que la centralización de logs funciona.

**Verificar Loki:**

```bash
ssh malpanez@tudominio.com

# Ver status
sudo systemctl status loki
# Debe mostrar: active (running)

# Probar API
curl http://localhost:3100/ready
# Debe retornar: ready

# Ver métricas
curl http://localhost:3100/metrics | head -20
```

**Verificar Promtail:**

```bash
# Ver status
sudo systemctl status promtail
# Debe mostrar: active (running)

# Probar API
curl http://localhost:9080/ready

# Ver targets configurados
curl http://localhost:9080/targets | grep -i "last error"
# No debe mostrar errores
```

**Verificar logs en Grafana:**

1. Abrir Grafana: `https://monitoring.tudominio.com`
2. Click **Explore** (icono brújula en sidebar)
3. **Data source:** Seleccionar **Loki**
4. **Label filters:** Seleccionar `job` → `nginx`
5. Click **Run query**
6. Debes ver logs de Nginx en tiempo real

**Ver dashboards de logs:**

1. **Dashboards** → **Browse**
2. Abrir **"Loki Logs Dashboard"**
3. Debe mostrar:
   - ✅ Gráficos de volumen de logs
   - ✅ Logs por job (nginx, php, mariadb, etc.)
   - ✅ Datos actualizándose en tiempo real

4. Abrir **"Nginx Loki Dashboard"**
5. Debe mostrar:
   - ✅ Requests/segundo
   - ✅ Top URLs
   - ✅ Códigos de status (200, 404, 500, etc.)
   - ✅ Top IPs

**Si no aparecen logs:**

```bash
# Verificar que Promtail puede leer archivos
sudo -u promtail cat /var/log/nginx/access.log

# Si falla, añadir al grupo adm
sudo usermod -aG adm promtail
sudo systemctl restart promtail
```

---

## 🎯 Checklist Final

Marca cuando hayas completado:

- [ ] Verificar servicios corriendo (nginx, mariadb, php, prometheus, grafana, loki, promtail)
- [ ] Instalar WordPress (wp-admin/install.php)
- [ ] Instalar LearnDash plugin + license
- [ ] Crear curso de prueba
- [ ] Configurar SMTP (SendGrid/Mailgun)
- [ ] Configurar SSH 2FA (Google Authenticator)
- [ ] Primer backup manual (Grafana + Prometheus + Loki)
- [ ] Acceder a Grafana + verificar dashboards
- [ ] Cambiar password de Grafana
- [ ] Configurar permalinks WordPress
- [ ] Instalar Wordfence Security
- [ ] Verificar stack de caché (Cloudflare, Nginx, Valkey, OPcache)
- [ ] Verificar logs en Grafana (Loki datasource funcionando)

---

## 🚀 Siguiente: Configuración Avanzada (OPCIONAL)

Después de completar estos pasos básicos, puedes:

1. **Configurar alertas por email** - Para recibir notificaciones de Grafana/Prometheus
2. **Implementar backups automáticos** - Restic + Cloudflare R2 / AWS S3
3. **Optimizar rendimiento** - Ajustar caché, lazy loading de imágenes
4. **Configurar dominio de email** - SPF, DKIM, DMARC para evitar spam
5. **Añadir más cursos** - Expandir tu plataforma LMS

Ver docs/ para guías avanzadas.

---

## 🆘 Problemas Comunes

### WordPress muestra "Error estableciendo conexión con la base de datos"

```bash
# Verificar MariaDB
sudo systemctl status mariadb

# Ver logs
sudo journalctl -u mariadb -n 50

# Verificar credenciales en wp-config.php
sudo cat /var/www/html/wp-config.php | grep DB_
```

### Grafana muestra "No data"

```bash
# Verificar Prometheus
sudo systemctl status prometheus

# Verificar que puede alcanzar Node Exporter
curl http://localhost:9100/metrics

# Reiniciar servicios
sudo systemctl restart prometheus grafana-server
```

### SSH 2FA no funciona

- Usa uno de los códigos de emergencia
- Conéctate y revisa: `cat ~/.google_authenticator`
- Verifica que la hora del servidor está sincronizada: `timedatectl`

### LearnDash no aparece después de instalarlo

- Verificar que la license está activa: **LearnDash LMS** → **Settings** → **LMS License**
- Limpiar caché de WordPress: **Tools** → **Clear Cache**
- Verificar que PHP tiene memoria suficiente: `php -i | grep memory_limit` (debe ser ≥256M)

---

## 📞 Contacto / Soporte

Si encuentras problemas no listados aquí:

1. Revisar logs del servidor: `sudo journalctl -xe`
2. Revisar docs/ específicos del componente
3. Abrir issue en el repositorio con logs completos

---

**🎉 ¡Felicidades! Tu plataforma LMS está lista para recibir estudiantes.**

Próximo paso: Crear tus cursos y empezar a enseñar.
