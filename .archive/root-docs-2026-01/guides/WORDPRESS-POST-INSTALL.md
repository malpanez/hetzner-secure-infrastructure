# WordPress Post-Installation Guide
## Configuración Completa para Sitio Educativo con LearnDash

Esta guía cubre la configuración completa de WordPress después del deployment automático, optimizada para un sitio educativo/cursos con LearnDash LMS.

---

## 📋 Tabla de Contenidos

1. [Temas Recomendados](#temas-recomendados)
2. [Configuración Inicial WordPress](#configuración-inicial-wordpress)
3. [Configuración de Plugins de Seguridad](#configuración-de-plugins-de-seguridad)
4. [LearnDash LMS Setup](#learndash-lms-setup)
5. [Optimización de Performance](#optimización-de-performance)
6. [SEO y Analytics](#seo-y-analytics)
7. [Backups y Testing](#backups-y-testing)

---

## 🎨 Temas Recomendados

### Opción 1: **Astra** (Recomendado - Free/Pro)

**Por qué Astra**:
- ✅ Optimizado para LearnDash (integración oficial)
- ✅ Extremadamente rápido (< 50KB)
- ✅ Totalmente responsive
- ✅ Compatible con cualquier page builder
- ✅ Personalización avanzada sin código
- ✅ SEO optimizado out-of-the-box

**Versiones**:
- **Free**: Suficiente para empezar
- **Pro** (~$59/año): Layouts pre-diseñados para cursos, header/footer builder, typography avanzada

**Instalación**:
```
WordPress Admin → Appearance → Themes → Add New → Search "Astra"
```

**Configuración recomendada**:
```
Customize → Global:
- Container: Full Width (mejor para LearnDash)
- Typography: System fonts o Google Fonts
- Colors: Define tu paleta de marca

Customize → LearnDash:
- Enable LearnDash compatibility
- Course layout: Grid (más moderno)
- Sidebar: Right sidebar
```

---

### Opción 2: **Kadence** (Free/Pro)

**Por qué Kadence**:
- ✅ Gutenberg-first (page builder integrado)
- ✅ Excelente para LearnDash
- ✅ Header/Footer builder incluido (gratis)
- ✅ Performance excepcional
- ✅ Diseños modernos

**Mejor si**: Prefieres usar Gutenberg en lugar de un page builder externo

---

### Opción 3: **GeneratePress** (Free/Pro)

**Por qué GeneratePress**:
- ✅ El más ligero (< 30KB)
- ✅ Código limpio y seguro
- ✅ Accesibilidad (WCAG 2.0 AAA)
- ✅ Compatible con LearnDash

**Mejor si**: Prioridad absoluta en performance y accesibilidad

---

### Opción 4: **LearnDash Official Theme** (Incluido con LearnDash Pro)

**Pros**:
- ✅ Diseñado específicamente para LearnDash
- ✅ Integración perfecta
- ✅ Templates listos para cursos

**Contras**:
- ❌ Menos flexible para otras páginas
- ❌ Personalización limitada

---

## ⚙️ Configuración Inicial WordPress

### 1. Settings → General

```
Site Title: Two Minds Trading Academy (o tu nombre)
Tagline: Master Trading & Investment Skills

WordPress Address (URL): https://twomindstrading.com
Site Address (URL): https://twomindstrading.com

Email Address: admin@twomindstrading.com (cambiar de admin@example.com)
Timezone: Europe/Lisbon (UTC+0 / UTC+1 DST)
Date Format: d/m/Y (31/12/2025)
Time Format: H:i (23:59)
Week Starts On: Monday
```

### 2. Settings → Reading

```
Your homepage displays: A static page
Homepage: [Crear página "Home"]
Posts page: [Crear página "Blog"]

Search Engine Visibility: ☐ Unchecked (permitir indexación)
```

### 3. Settings → Permalinks

```
Permalink Structure: Post name
   ✅ https://twomindstrading.com/curso-forex-basico/

Category base: cursos
Tag base: temas
```

### 4. Settings → Discussion

```
Default article settings:
☐ Attempt to notify any blogs linked from the article
☑ Allow link notifications from other blogs (pingbacks and trackbacks)
☐ Allow people to submit comments on new posts

Email me whenever:
☑ Anyone posts a comment
☑ A comment is held for moderation

Before a comment appears:
☑ Comment must be manually approved
☐ Comment author must have a previously approved comment

Comment Moderation: Hold comments with 2+ links
Comment Blocklist: [Lista de spam words]
```

---

## 🔐 Configuración de Plugins de Seguridad

### Wordfence Security

**Dashboard → Wordfence → Scan**:
1. Ejecutar primer scan completo
2. Revisar y resolver cualquier issue

**Dashboard → Wordfence → Firewall**:
```
Firewall Status: Enabled
Protection Level: Extended Protection
   (Requiere .htaccess write - ya configurado por Ansible)

Firewall Rules:
☑ Block IPs who send POST requests with blank User-Agent
☑ Block fake Google crawlers
☑ Block access to debug.log
☑ Immediately block fake Googlebots
```

**Dashboard → Wordfence → Login Security**:
```
Enable 2FA: Yes
2FA Required for: Administrators
Grace Period: 7 days

CAPTCHA:
☑ Enable for login page
☑ Enable for registration
☑ Enable for lost password
```

**Rate Limiting** (ya configurado en Nginx, pero doble capa):
```
wp-login.php: 10 attempts / 5 minutes
XML-RPC: Disabled (no needed)
```

---

### WP 2FA (Two-Factor Authentication)

**Dashboard → WP 2FA → Settings**:
```
Enforcement Policy:
- Administrators: Required
- Editors: Required
- Authors: Optional
- Subscribers: Disabled

Allowed Methods:
☑ TOTP (Time-based One-Time Password)
☑ Email codes
☐ Backup codes

Grace Period: 7 days
```

**Setup personal 2FA**:
1. User → Your Profile → Two-Factor Authentication
2. Scan QR code con Google Authenticator / Authy
3. Guardar backup codes en password manager

---

### Sucuri Security

**Dashboard → Sucuri → Settings**:

**Hardening**:
```
☑ Verify WordPress Version
☑ Verify Plugin Versions
☑ Block PHP Execution in uploads
☑ Block access to wp-includes
☑ Disable File Editor (elimina Editor en Appearance)
☑ Protect wp-config.php
☑ Change Security Keys
```

**Post-Hack**:
```
☑ Reset all passwords (si hay breach)
☑ Update all security keys
```

**Alerts**:
```
Email alerts: admin@twomindstrading.com
Alert on:
  ☑ File changes
  ☑ Failed logins
  ☑ Plugin changes
  ☑ Theme changes
  ☑ User changes
```

---

### Redis Object Cache

**Settings → Redis**:

```
Status: Connected ✅
   (Debería mostrar "Status: Connected" si Valkey está corriendo)

Configuration:
- Client: PhpRedis
- Connection: Unix socket (/run/valkey/valkey.sock)
- Database: 0
- Maxmemory Policy: allkeys-lru

Enable Object Cache: Click "Enable"
```

**Verificar funcionamiento**:
```
Settings → Redis → Diagnostics:
- Hits: Debería aumentar con uso
- Misses: Normal al inicio
- Hit Ratio: > 80% después de unas horas
```

**Performance**:
```
Cache Groups:
☑ Posts, pages
☑ Terms
☑ Users
☑ Options
☐ Transients (opcional - ya cacheados en DB)
```

---

## 📚 LearnDash LMS Setup

### Instalación LearnDash Pro

**IMPORTANTE**: LearnDash Pro NO se instala automáticamente (requiere licencia).

1. **Comprar licencia**: https://www.learndash.com/pricing/
   - Basic: $199/año (1 sitio)
   - Plus Package: $229/año (incluye ProPanel + Notifications)

2. **Descargar plugin**:
   ```
   Login en learndash.com → My Account → Downloads
   ```

3. **Instalar**:
   ```
   WordPress Admin → Plugins → Add New → Upload Plugin
   → learndash-x.x.x.zip → Install Now → Activate
   ```

4. **Activar licencia**:
   ```
   LearnDash LMS → Settings → LMS License
   Email: tu_email@learndash.com
   License Key: xxxx-xxxx-xxxx-xxxx
   → Update License
   ```

---

### Configuración LearnDash

**LearnDash LMS → Settings → General**:

```
Course Structure:
☑ Courses → Lessons → Topics → Quizzes

Progress Bar: Show
Course Prerequisite: Enable (permite cursos en secuencia)
Course Points: Enable (gamificación)
```

**LearnDash LMS → Settings → Courses**:

```
Course Builder:
- Default Layout: Grid
- Courses per page: 12
- Course Grid Columns: 3

Course Access:
- Default: Open (o Buy Now / Recurring / Closed)
- Course Price Type Closed Button URL: /contacto/
```

**LearnDash LMS → Settings → Lessons**:

```
Lesson Progression:
☑ Force lesson completion before next
Video Progression: Optional (tracking con Vimeo/YouTube)
Auto-Complete: No (requiere acción del usuario)
```

**LearnDash LMS → Settings → Quizzes**:

```
Quiz Progress:
☑ Show quiz statistics
☑ Show quiz timer
Results Display: Immediately after completion

Certificates:
☑ Auto-award on course completion
PDF Engine: mPDF (mejor soporte Unicode)
```

**LearnDash LMS → Settings → Payments**:

```
Payment Gateway: PayPal / Stripe (configurar después)

Currency:
- Currency: Euro (EUR)
- Position: Left (€100)
- Thousands Separator: . (punto)
- Decimal Separator: , (coma)
```

---

### Crear Primer Curso (Ejemplo)

**LearnDash LMS → Courses → Add New**:

```
Title: Forex Trading para Principiantes

Course Builder:
└─ Lesson 1: Introducción al Forex
   ├─ Topic 1.1: ¿Qué es el Forex?
   ├─ Topic 1.2: Principales pares de divisas
   └─ Quiz: Conceptos básicos

└─ Lesson 2: Análisis Técnico
   ├─ Topic 2.1: Soportes y resistencias
   ├─ Topic 2.2: Indicadores básicos
   └─ Quiz: Análisis técnico

Course Settings:
- Access Mode: Buy Now
- Course Price: €199
- Course Prerequisite: Ninguno
- Certificate: Auto-award on completion
```

**Sidebar (Course Settings)**:
```
Featured Image: 1200x630px (16:9)
Course Categories: Forex, Trading
Course Tags: principiante, forex, análisis-técnico

Materials: [Subir PDF, hojas de cálculo, etc.]
```

---

### Plugins Adicionales para LearnDash (Opcionales)

**Gratuitos**:
- **Uncanny Toolkit** (Free): Añade features útiles (front-end login, certificados mejorados)
- **BuddyBoss Platform** (Free): Comunidad + foro integrado con LearnDash

**Premium** (considerar más adelante):
- **LearnDash ProPanel** ($99/año): Dashboard avanzado para instructores
- **Uncanny Automator** ($149/año): Automatizaciones (integra con Zapier, email, etc.)
- **GrassBlade xAPI** ($147/año): Tracking avanzado + SCORM support

---

## 🚀 Optimización de Performance

### WP Rocket (Opcional - $59/año)

Si quieres máximo performance, considera **WP Rocket**:

```
Cache → Enable caching for logged-in users: No (LearnDash requiere contenido dinámico)

File Optimization:
☑ Minify CSS
☑ Combine CSS (test primero)
☑ Minify JavaScript
☐ Combine JavaScript (puede romper cosas - test)
☑ Load JavaScript deferred

Media:
☑ Enable LazyLoad for images
☑ Enable LazyLoad for iframes/videos

CDN: [Configurar Cloudflare después]
```

**IMPORTANTE**: WP Rocket puede conflictuar con LearnDash. Excluir:
```
Never cache URL(s):
/courses/
/lessons/
/topic/
/my-courses/
/course-progress/

Never cache cookies:
learndash_*
ld_*
```

---

### Sin WP Rocket (usar caché existente)

Ya tienes configurado:
- ✅ **Nginx FastCGI Cache** (servidor)
- ✅ **Redis Object Cache** (WordPress objects)

**Optimizar imágenes**:

Plugin recomendado: **ShortPixel** (Free/Premium)
```
Plugins → Add New → ShortPixel Image Optimizer

Settings:
- Compression: Lossy (mejor balance)
- Optimize PDFs: Yes
- Backup: Yes (primeros 100 gratis)
- Auto-optimize on upload: Yes
```

**Lazy Load** (si no usas WP Rocket):

Plugin: **a3 Lazy Load** (Free)
```
Settings:
☑ Images
☑ Iframes (videos)
☐ Widgets (puede romper sidebar)
```

---

## 📊 SEO y Analytics

### Yoast SEO (Ya instalado)

**SEO → General**:
```
Features:
☑ XML sitemaps
☑ Advanced settings pages
☐ Admin bar menu (opcional)
```

**SEO → Search Appearance**:

**Global**:
```
Title Separator: | (pipe)
Homepage:
- SEO Title: Two Minds Trading Academy | Cursos de Trading e Inversión
- Meta Description: Aprende trading profesional con nuestros cursos de Forex, Criptomonedas y Análisis Técnico. Formación práctica desde nivel principiante hasta avanzado.
```

**Content Types**:
```
Posts:
- SEO Title: %%title%% %%page%% %%sep%% %%sitename%%
- Show in search: Yes

Pages:
- Same as Posts

LearnDash Courses:
- SEO Title: %%title%% %%sep%% Curso Online %%sep%% %%sitename%%
- Show in search: Yes
- Schema: Course

LearnDash Lessons:
- Show in search: No (evitar contenido duplicado)
```

**SEO → Integrations**:
```
Zapier: No (a menos que uses Automator)
Semrush: No (opcional - requiere cuenta)
```

---

### Google Analytics 4

**Opción 1: Plugin Site Kit by Google** (Recomendado)
```
Plugins → Add New → Site Kit by Google

Connect Google Account
→ Autorizar permisos
→ Setup Analytics 4
→ Verificar Search Console
```

**Opción 2: Manual (código en tema)**
```
Appearance → Customize → Additional CSS
→ (No, mejor usar plugin para evitar editar código)
```

**GA4 Setup**:
```
Google Analytics → Admin → Data Streams → Web

Enhanced Measurement:
☑ Page views
☑ Scrolls
☑ Outbound clicks
☑ Site search
☑ Video engagement (YouTube/Vimeo embeds)
☑ File downloads
```

**Events personalizados** (configurar después):
- Course enrollment
- Lesson completion
- Quiz completion
- Certificate download

---

### Google Search Console

**Verificación**:
```
Site Kit (si instalaste) → Search Console
   → Auto-verified via Analytics

O manual:
Search Console → Add Property → twomindstrading.com
→ Verification → HTML tag (copiar a theme header)
```

**Enviar Sitemap**:
```
Search Console → Sitemaps → Add new sitemap
URL: https://twomindstrading.com/sitemap_index.xml
   (Yoast genera esto automáticamente)
```

---

## 💾 Backups y Testing

### UpdraftPlus (Ya instalado)

**Settings → UpdraftPlus Backups**:

**Files backup schedule**:
```
Schedule: Weekly
Retain: 4 backups (1 mes)
Include: Plugins, Themes, Uploads, Others
```

**Database backup schedule**:
```
Schedule: Daily
Retain: 14 backups (2 semanas)
```

**Remote Storage** (Elige uno):

**Opción 1: Amazon S3** (Recomendado)
```
AWS Console → S3 → Create Bucket
   Name: twomindstrading-backups
   Region: eu-west-1 (Irlanda - más cerca)
   Versioning: Disabled
   Encryption: AES-256

IAM → Create User → updraftplus-backup
   Permissions: AmazonS3FullAccess (o custom policy)
   → Create Access Key

UpdraftPlus → Amazon S3:
   Access Key: AKIA...
   Secret Key: ****
   Bucket: twomindstrading-backups
   → Test Settings → Save
```

**Opción 2: Google Drive** (Más fácil)
```
UpdraftPlus → Google Drive
→ Authenticate
→ Select Folder: WordPress Backups
→ Save
```

**Opción 3: Dropbox**
```
Similar a Google Drive
```

---

### Hacer Primer Backup Manual

```
Settings → UpdraftPlus Backups → Backup Now

Include:
☑ Database
☑ Plugins
☑ Themes
☑ Uploads
☑ Others

→ Backup Now
```

**Verificar backup**:
```
Settings → UpdraftPlus Backups → Existing Backups
→ Ver última backup
→ Download to computer (test)
```

---

### Test de Restauración (CRÍTICO)

**EN STAGING** (no en producción):
```
1. Hacer backup completo
2. Settings → UpdraftPlus → Restore
3. Select backup → Click Restore
4. Wait for completion
5. Verificar que sitio funciona
6. Verificar curso de prueba
7. Login como admin
8. Check database

Si todo OK → Backup strategy validada ✅
```

---

## 🔍 Testing Post-Configuración

### Checklist de Testing

**Seguridad**:
```
☐ Login con 2FA funciona (WordPress + SSH)
☐ Wordfence scan completo sin errores
☐ Sucuri hardening aplicado
☐ File editor deshabilitado (Appearance → Theme Editor no existe)
☐ wp-config.php no accesible vía web
☐ .htaccess tiene protecciones
```

**Performance**:
```
☐ Redis conectado (Settings → Redis muestra hit ratio)
☐ GTMetrix score > B (https://gtmetrix.com/)
☐ Google PageSpeed > 80 mobile, > 90 desktop
☐ Imágenes lazy loading
☐ TTFB < 500ms (Time To First Byte)
```

**LearnDash**:
```
☐ Curso de prueba creado
☐ Lección con video funciona
☐ Quiz funciona y asigna puntos
☐ Certificado se genera en PDF
☐ Progreso se guarda correctamente
☐ Email de bienvenida se envía (SMTP configurado)
```

**SEO**:
```
☐ Sitemap generado (/sitemap_index.xml)
☐ Robots.txt accesible (/robots.txt)
☐ Google Analytics tracking funciona
☐ Search Console recibiendo datos
☐ Schema.org markup en cursos (test con Google Rich Results)
```

**Backups**:
```
☐ Backup manual completado
☐ Backup automático programado
☐ Remote storage conectado
☐ Test de restauración exitoso (en staging)
☐ Backup emails llegando
```

---

## 📧 SMTP Configuration (Envío de Emails)

**Problema**: Por defecto, WordPress usa `mail()` de PHP, que Cloudflare/spam filters bloquean.

**Solución**: WP Mail SMTP (ya instalado)

### Opción 1: SendGrid (Recomendado - Free 100 emails/día)

```
1. Signup en SendGrid: https://signup.sendgrid.com/
2. Verify email
3. Create API Key:
   Settings → API Keys → Create API Key
   Name: wordpress-smtp
   Permissions: Full Access (Mail Send)
   → Create & View

4. WP Mail SMTP → Settings:
   From Email: noreply@twomindstrading.com
   From Name: Two Minds Trading Academy
   Mailer: SendGrid
   API Key: SG.xxxx
   → Save Settings

5. Test:
   Email Test → Send to: tu_email@gmail.com
   → Send Email
```

**SendGrid Free limits**:
- 100 emails/día (suficiente para empezar)
- Upgrade: $15/mes = 40,000 emails/mes

---

### Opción 2: Gmail SMTP (Gratis, menos fiable)

```
WP Mail SMTP → Settings:
   From Email: tuemail@gmail.com
   Mailer: Gmail / Google Workspace

   → Connect to Google
   → Authorize WordPress

IMPORTANTE: Gmail limita a 500 emails/día
```

---

### Opción 3: Amazon SES (Más barato para volumen)

```
Coste: $0.10 por 1,000 emails
Setup más complejo (requiere AWS)

Solo considerar si > 5,000 emails/mes
```

---

## 🤖 Herramientas de IA para Diseño Web

### Para Generar Diseño y Estructura

**1. v0.dev by Vercel** (Recomendado para prototipos)
- **URL**: https://v0.dev/
- **Qué hace**: Genera componentes web completos desde prompts en lenguaje natural
- **Output**: React/HTML + Tailwind CSS (puedes adaptar a WordPress)
- **Uso**: Diseña secciones (hero, pricing tables, course grids, testimonials)
- **Ejemplo prompt**:
  ```
  "Create a modern hero section for an online trading academy.
  Include a bold headline, subheadline, CTA button, and 3-column
  feature grid showcasing course benefits. Dark theme, professional
  financial aesthetic."
  ```
- **Coste**: Free con límites, Pro $20/mes

**2. Galileo AI** (Diseño UI completo)
- **URL**: https://www.usegalileo.ai/
- **Qué hace**: Genera designs completos de páginas web desde texto
- **Output**: Figma designs (exportables a código)
- **Mejor para**: Landing pages completas, onboarding flows
- **Coste**: Beta (lista de espera)

**3. Durable AI** (Website builder con IA)
- **URL**: https://durable.co/
- **Qué hace**: Genera sitio web completo en 30 segundos
- **Output**: Sitio web live (no WordPress, pero puedes replicar diseño)
- **Uso**: Inspiración rápida, luego replicas en WordPress
- **Coste**: Free trial, $15/mes

**4. Relume** (Sitemap + Wireframes con IA)
- **URL**: https://www.relume.io/ai-site-builder
- **Qué hace**: Genera sitemap + wireframes desde descripción del negocio
- **Output**: Estructura completa del sitio en Figma/Webflow
- **Mejor para**: Planificar arquitectura del sitio
- **Coste**: Free tier limitado, Pro $32/mes

---

### Para Generar Contenido

**5. ChatGPT / Claude** (Copywriting)
- **Uso**: Escribir textos de landing pages, descripciones de cursos, FAQs
- **Ejemplo prompts**:
  ```
  "Write a compelling course description for 'Forex Trading for
  Beginners'. Target audience: 25-45 year olds interested in financial
  independence. Highlight: practical approach, real-world examples,
  step-by-step guidance. Max 150 words."
  ```

**6. Midjourney / DALL-E 3** (Imágenes)
- **Uso**: Generar imágenes hero, fondos, ilustraciones conceptuales
- **No usar para**: Gráficos técnicos (mejor Unsplash/Pexels o crear propios)
- **Ejemplo prompt**:
  ```
  "Professional trading desk setup, modern monitors showing forex
  charts, clean aesthetic, blue and white color scheme, 4k,
  photorealistic, wide angle"
  ```

---

### Para Adaptar Diseños a WordPress

**7. Elementor AI** (Integrado en Elementor Pro)
- **URL**: https://elementor.com/features/ai/
- **Qué hace**: Genera layouts, textos, códigos CSS dentro de WordPress
- **Mejor para**: Diseñar páginas directamente en WordPress
- **Coste**: Incluido con Elementor Pro ($59/año)

**8. 10Web AI Builder** (WordPress específico)
- **URL**: https://10web.io/ai-website-builder/
- **Qué hace**: Genera sitio WordPress completo con IA
- **Output**: WordPress instalado con diseño personalizado
- **Nota**: Vendor lock-in (hosting incluido), mejor usar solo para inspiración
- **Coste**: $10/mes

---

## 🏗️ Estructura de Sitio Recomendada

Basándome en un sitio educativo de trading típico:

### Sitemap Completo

```
twomindstrading.com/
│
├── 🏠 Home (/)
│   ├── Hero section (valor principal)
│   ├── Featured courses (3-4 cursos destacados)
│   ├── Why choose us (3 columnas)
│   ├── Student testimonials
│   ├── Stats/Achievements
│   └── CTA (Start Learning)
│
├── 📚 Courses (/cursos/)
│   ├── All courses grid (LearnDash course grid)
│   ├── Filter by level (Beginner / Intermediate / Advanced)
│   ├── Filter by topic (Forex / Crypto / Stocks / Technical Analysis)
│   └── Individual course pages:
│       ├── /cursos/forex-para-principiantes/
│       ├── /cursos/analisis-tecnico-avanzado/
│       ├── /cursos/trading-de-criptomonedas/
│       └── /cursos/psicologia-del-trading/
│
├── 🎓 About (/sobre-nosotros/)
│   ├── Mission & Vision
│   ├── Instructor bio (tu background)
│   ├── Teaching methodology
│   ├── Success stories
│   └── Certifications/Credentials
│
├── 💰 Pricing (/precios/)
│   ├── Pricing tiers:
│       ├── Free (1 curso intro)
│       ├── Individual Courses (€99-€299 c/u)
│       ├── All Access Pass (€499/año)
│       └── 1-on-1 Mentoring (€999 custom)
│   ├── Comparison table
│   └── FAQ pricing
│
├── 📖 Blog (/blog/)
│   ├── Trading tips
│   ├── Market analysis
│   ├── Student case studies
│   └── Platform tutorials
│
├── 👤 My Account (/mi-cuenta/)
│   ├── Login/Register (LearnDash)
│   ├── My Courses (progress tracking)
│   ├── Certificates
│   ├── Profile settings
│   └── Billing history
│
├── 📧 Contact (/contacto/)
│   ├── Contact form
│   ├── Email: support@twomindstrading.com
│   ├── FAQ link
│   └── Social media links
│
├── ❓ FAQ (/preguntas-frecuentes/)
│   ├── General questions
│   ├── Course access
│   ├── Payments & refunds
│   ├── Certificates
│   └── Technical support
│
├── ⚖️ Legal
│   ├── Terms & Conditions (/terminos/)
│   ├── Privacy Policy (/privacidad/)
│   ├── Cookie Policy (/cookies/)
│   └── Disclaimer (/aviso-legal/)
│
└── 🎯 Landing Pages (marketing)
    ├── /empieza-aqui/ (lead magnet - free intro course)
    ├── /masterclass-gratuita/ (webinar signup)
    └── /promo-black-friday/ (seasonal promos)
```

---

### Páginas Prioritarias (MVP)

Para lanzamiento inicial, crea SOLO estas:

**Must-have (Semana 1-2)**:
```
1. Home
2. 1 Curso completo (Forex Básico)
3. About
4. Contact
5. My Account (login/register - LearnDash lo crea)
6. Privacy Policy (generador: https://www.privacypolicygenerator.info/)
```

**Nice-to-have (Semana 3-4)**:
```
7. Courses grid page
8. Pricing page
9. 2-3 posts en Blog
10. FAQ
```

**Later (Post-launch)**:
```
11. Más cursos
12. Landing pages específicas
13. Blog activo
14. Testimonials page
```

---

### Diseño de Página Home (Recomendación)

Usando **v0.dev** o **Elementor**, crea estas secciones:

**1. Hero Section**
```
Layout: Full-width, background image/video
Content:
- H1: "Domina el Trading Profesional"
- Subheadline: "Aprende Forex, Criptomonedas y Análisis Técnico
               con cursos prácticos y mentorías personalizadas"
- CTA Primary: [Ver Cursos]
- CTA Secondary: [Prueba Gratis]
- Trust indicator: "500+ estudiantes, 4.8★ valoración"

Design:
- Dark overlay sobre imagen de trading desk
- Text: White
- CTA: Blue (#0066CC) + White outline
- Font: Sans-serif moderna (Inter, Poppins)
```

**Prompt para v0.dev**:
```
"Create a hero section for an online trading academy. Dark overlay
on trading background image. White bold headline 'Master Professional
Trading', smaller subheadline about forex and crypto courses. Two CTA
buttons (solid blue 'View Courses' and outline white 'Try Free').
Trust badge showing 500+ students and 4.8 stars. Professional, modern,
financial aesthetic."
```

---

**2. Featured Courses** (3 tarjetas)
```
Layout: 3-column grid (responsive: 1 column mobile)

Card components:
- Course thumbnail (16:9)
- Course title
- Short description (2 lines)
- Level badge (Beginner/Intermediate/Advanced)
- Price
- [Learn More] button

Courses destacar:
1. Forex para Principiantes (€149)
2. Análisis Técnico Avanzado (€199)
3. Trading de Criptomonedas (€179)
```

**Prompt para v0.dev**:
```
"Create a 3-column course card grid. Each card has: course image (16:9),
title, 2-line description, difficulty badge (colored pill: green=beginner,
orange=intermediate, red=advanced), price tag, and 'Learn More' button.
Cards have subtle shadow and hover effect. Professional design, blue accent
color (#0066CC)."
```

---

**3. Why Choose Us** (3 columnas con iconos)
```
Features:
1. 📊 Contenido Práctico
   "Aprende haciendo. Cada curso incluye ejercicios reales
    y análisis de mercado en tiempo real."

2. 🎓 Instructores Expertos
   "Aprende de traders profesionales con años de experiencia
    en mercados financieros."

3. 📜 Certificados Oficiales
   "Recibe certificados al completar cada curso, validando
    tus nuevas habilidades."

Design:
- Icon (60px) centrado arriba
- Title (H3)
- Description (p)
- Background: Light gray (#F8F9FA)
```

---

**4. Student Testimonials** (carrusel o grid)
```
Layout: 2-3 testimonial cards, carrusel si > 3

Card:
- Quote: "Contenido muy claro y práctico. Pasé de cero
          a hacer mi primer trade en 3 semanas."
- Name: João Silva
- Role: Estudiante Forex Básico
- Avatar: Foto o inicial
- Stars: ⭐⭐⭐⭐⭐

(Inicialmente usa placeholders, reemplazar con reales después)
```

---

**5. Stats Section** (single row, 4 metrics)
```
Metrics:
- 500+ Estudiantes
- 15+ Cursos
- 4.8★ Valoración
- 95% Tasa de Finalización

Design: Dark background, white text, numbers in large font
```

---

**6. Final CTA**
```
Background: Gradient blue
Text: "¿Listo para empezar tu viaje en el trading?"
CTA: [Ver Todos los Cursos]
Subtext: "Prueba gratis el curso de introducción"
```

---

### Herramienta Recomendada por Tipo

**Si prefieres control total y aprenderás WordPress**:
→ **Elementor Pro** + **Astra Theme** + **v0.dev para inspiración**
- Aprendizaje: 2-3 semanas
- Flexibilidad: ⭐⭐⭐⭐⭐
- Coste: $59/año

**Si quieres velocidad y facilidad**:
→ **Astra Pro Starter Sites** (templates pre-diseñados)
- Aprendizaje: 2-3 días
- Flexibilidad: ⭐⭐⭐
- Coste: $59/año (incluye demos)

**Si quieres IA que haga todo** (menos recomendado):
→ **10Web AI Builder**
- Aprendizaje: 1 día
- Flexibilidad: ⭐⭐
- Coste: $10-20/mes (vendor lock-in)

---

### Mi Recomendación Final

**Workflow híbrido** (mejor de ambos mundos):

1. **Planificación**: Usa **Relume AI** o simplemente lista tu sitemap (ya lo hice arriba)

2. **Inspiración visual**:
   - Busca "LMS WordPress themes" en ThemeForest
   - Revisa https://www.learndash.com/showcase/ (sitios reales)
   - Usa **v0.dev** para generar secciones específicas

3. **Implementación**:
   - Instala **Astra Theme** (free o pro)
   - Usa **Elementor** (free o pro) para diseñar páginas
   - Copia estructura de componentes de v0.dev (adapta CSS)
   - LearnDash maneja cursos automáticamente

4. **Contenido**:
   - Usa **ChatGPT/Claude** para escribir textos
   - Usa **Unsplash** (free) para imágenes hero
   - Usa **Pexels Videos** (free) para background videos
   - Crea tus propios gráficos técnicos (TradingView screenshots)

5. **Launch**:
   - MVP en 2 semanas (Home + 1 curso)
   - Itera basándote en feedback estudiantes

---

## 🎨 Paleta de Colores Recomendada

Para sitio de trading (transmite: profesionalismo, confianza, crecimiento):

```css
/* Primary - Trustworthy Blue */
--primary: #0066CC;      /* Botones, links, accents */
--primary-dark: #004C99; /* Hover states */

/* Secondary - Success Green */
--secondary: #00D084;    /* Positive stats, badges */
--secondary-dark: #00A66C;

/* Neutral - Professional Grays */
--gray-50: #F8F9FA;      /* Backgrounds */
--gray-100: #E9ECEF;     /* Borders */
--gray-600: #6C757D;     /* Secondary text */
--gray-900: #212529;     /* Headings */

/* Accent - Warning/Alert */
--warning: #FFB020;      /* Intermediate level */
--danger: #DC3545;       /* Advanced level, alerts */
--success: #28A745;      /* Beginner level, success messages */

/* Text */
--text-primary: #212529;
--text-secondary: #6C757D;
--text-white: #FFFFFF;
```

**Aplicar en Astra**:
```
Customize → Global → Colors:
- Link Color: #0066CC
- Button Color: #0066CC
- Heading Color: #212529
- Text Color: #6C757D
```

---

## 📝 Checklist de Diseño Web

```
Setup técnico:
☐ Tema instalado (Astra/GeneratePress/Kadence)
☐ Page builder instalado (Elementor/Gutenberg)
☐ Fonts configurados (Google Fonts: Inter para body, Poppins para headings)
☐ Paleta de colores aplicada

Páginas creadas:
☐ Home (con secciones completas)
☐ About
☐ Contact (con formulario funcional)
☐ Privacy Policy
☐ 1 Curso completo con 3+ lecciones

Componentes:
☐ Navigation menu (Home, Courses, About, Contact, Login)
☐ Footer (links, social media, copyright)
☐ 404 page customizada
☐ Search page

Responsiveness:
☐ Mobile (< 768px) - layout 1 columna
☐ Tablet (768-1024px) - layout 2 columnas
☐ Desktop (> 1024px) - layout full

Performance:
☐ Imágenes optimizadas (< 200KB cada una)
☐ Lazy loading habilitado
☐ Cache funcionando (Redis + Nginx)
```

---

¿Quieres que te genere prompts específicos para v0.dev/ChatGPT para alguna sección en particular? O prefieres un walkthrough de cómo usar Elementor para crear la Home page?

---

## 🎯 Próximos Pasos

### Semana 1: Setup Básico
```
☐ Instalar tema (Astra recomendado)
☐ Configurar ajustes generales WordPress
☐ Configurar Wordfence + WP 2FA
☐ Verificar Redis cache funcionando
☐ Configurar SMTP (SendGrid)
☐ Test de envío de email
```

### Semana 2: LearnDash
```
☐ Comprar e instalar LearnDash Pro
☐ Configurar ajustes LearnDash
☐ Crear curso de prueba (3 lecciones, 1 quiz)
☐ Test de flujo completo (enrollment → completion)
☐ Configurar certificado PDF
```

### Semana 3: Contenido
```
☐ Crear páginas principales (Home, Sobre, Contacto)
☐ Crear primer curso real
☐ Subir videos (YouTube o Vimeo privado)
☐ Configurar precios
☐ Setup payment gateway (Stripe/PayPal)
```

### Semana 4: Launch
```
☐ Migrar DNS a Cloudflare
☐ Configurar SSL/TLS
☐ SEO optimization (meta descriptions, sitemaps)
☐ Google Analytics + Search Console
☐ Test completo en staging
☐ Deploy a producción
☐ Anunciar lanzamiento
```

---

## 📚 Recursos Útiles

**LearnDash**:
- Documentación oficial: https://www.learndash.com/support/docs/
- Forum: https://www.learndash.com/support/
- Showcase: https://www.learndash.com/showcase/ (inspiración)

**Themes**:
- Astra demos: https://wpastra.com/ready-websites/
- Kadence demos: https://www.kadencewp.com/kadence-blocks/starter-templates/

**Performance**:
- GTMetrix: https://gtmetrix.com/
- Google PageSpeed: https://pagespeed.web.dev/
- WebPageTest: https://www.webpagetest.org/

**SEO**:
- Google Search Console: https://search.google.com/search-console/
- Yoast Academy: https://yoast.com/academy/

**Security**:
- Wordfence blog: https://www.wordfence.com/blog/
- Sucuri blog: https://blog.sucuri.net/

---

## ❓ FAQ

**Q: ¿Necesito comprar LearnDash ya o puedo probarlo?**
A: LearnDash NO tiene versión free. Debes comprar desde el inicio ($199/año). Sí ofrece 30-day money-back guarantee.

**Q: ¿Qué theme usar si tengo presupuesto limitado?**
A: Astra Free + Elementor Free es excelente combinación sin coste.

**Q: ¿WP Rocket es necesario?**
A: No. Ya tienes Nginx FastCGI cache + Redis. WP Rocket es opcional (ayuda con lazy load y minificación).

**Q: ¿Cuántos emails necesito enviar?**
A: Para empezar con < 50 estudiantes: SendGrid Free (100/día) es suficiente. LearnDash envía ~3 emails por estudiante (welcome, lesson progress, completion).

**Q: ¿Cloudflare bloquea LearnDash?**
A: No, pero configura Page Rules para excluir `/courses/*` del caché (contenido dinámico).

**Q: ¿Necesito Vimeo Pro para videos?**
A: No obligatorio. YouTube funciona bien. Vimeo Pro ($20/mes) da privacidad + no ads + mejor player.

---

¡Éxito con tu sitio educativo! 🚀
