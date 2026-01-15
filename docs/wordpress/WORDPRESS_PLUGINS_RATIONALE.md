# WordPress Plugins - Technical Rationale

**Purpose**: Document why each auto-installed plugin was selected for the LearnDash LMS stack
**Last Updated**: 2026-01-14
**Total Auto-Installed Plugins**: 9 (all FREE)

---

## Table of Contents

1. [Plugin Categories](#plugin-categories)
2. [Critical Infrastructure Integration (4 plugins)](#critical-infrastructure-integration)
3. [Critical LMS Operations (3 plugins)](#critical-lms-operations)
4. [Important Content & Compliance (2 plugins)](#important-content--compliance)
5. [What We DON'T Install (and why)](#what-we-dont-install)
6. [Cost Analysis](#cost-analysis)

---

## Plugin Categories

Plugins are organized by priority and purpose:

| Priority | Count | Purpose |
|----------|-------|---------|
| **CRITICAL Infrastructure** | 4 | Connect WordPress to infrastructure (Valkey, Nginx, security) |
| **CRITICAL LMS Operations** | 3 | Essential for LearnDash LMS to function properly |
| **IMPORTANT Content & Compliance** | 2 | Landing pages and legal compliance |
| **Total** | **9** | All 100% FREE from WordPress.org |

---

## Critical Infrastructure Integration

### 1. redis-cache (CRITICAL)

**Slug**: `redis-cache`
**Purpose**: Valkey (Redis fork) object cache integration
**Price**: FREE
**Why Essential**:

- **Problem**: WordPress queries database for every request (slow, expensive)
- **Solution**: Stores query results in Valkey (in-memory cache)
- **Performance Impact**:
  - Reduces database load by 90%+
  - Speeds up page generation by 3-5x
  - Essential for handling concurrent students

**Infrastructure Dependency**:
```yaml
# Requires Valkey role to be deployed
- Valkey runs on port 6379 (default)
- Plugin connects WordPress → Valkey automatically
- Ansible auto-configures via WP-CLI: `wp redis enable`
```

**Without this plugin**: Valkey infrastructure is useless for WordPress

**References**:
- WordPress.org: https://wordpress.org/plugins/redis-cache/
- Valkey role: `ansible/roles/valkey/`

---

### 2. nginx-helper (CRITICAL)

**Slug**: `nginx-helper`
**Purpose**: Nginx FastCGI cache purging on content updates
**Price**: FREE
**Why Essential**:

- **Problem**: Nginx FastCGI caches entire pages → updates don't show until cache expires
- **Solution**: Auto-purges cache when you edit posts/pages/courses
- **How it works**:
  1. User edits course in WordPress
  2. Plugin detects change
  3. Sends purge request to Nginx
  4. Nginx deletes cached version
  5. Next visitor gets fresh content

**Infrastructure Dependency**:
```yaml
# Requires Nginx FastCGI cache (already configured)
- Cache path: /var/cache/nginx/fastcgi
- Purge method: DELETE request to localhost
- Ansible auto-configures: wp option update rt_wp_nginx_helper_options
```

**Without this plugin**: Students see outdated course content until cache expires (hours)

**References**:
- WordPress.org: https://wordpress.org/plugins/nginx-helper/
- Nginx config: `ansible/roles/nginx_wordpress/templates/conf.d/fastcgi-cache.conf.j2`

---

### 3. wordfence-login-security (CRITICAL)

**Slug**: `wordfence-login-security`
**Purpose**: Two-Factor Authentication (2FA/MFA) for admin logins
**Price**: FREE (lightweight version, NOT full Wordfence)
**Why Essential**:

- **Problem**: Password-only login is vulnerable to credential stuffing
- **Solution**: Requires TOTP code (Google Authenticator, Authy) after password
- **Security Layer**:
  - Layer 1: Password (something you know)
  - Layer 2: TOTP app (something you have)

**Why NOT full Wordfence**:
```yaml
# Full Wordfence duplicates infrastructure features:
❌ Wordfence WAF      → Cloudflare WAF (better, at edge)
❌ Wordfence Firewall → UFW + Fail2ban (server-level)
❌ Malware scanning   → AppArmor + AIDE (system-level)

# We ONLY need:
✅ Login Security module → 2FA/MFA for WordPress admin
```

**Infrastructure Coverage**:
- ✅ Cloudflare WAF: DDoS, bot blocking, rate limiting
- ✅ Fail2ban: Brute force protection at server level
- ✅ AppArmor: Process isolation and mandatory access control
- ✅ UFW: Firewall rules (only Cloudflare IPs allowed)

**Without this plugin**: Admin accounts vulnerable to credential theft

**References**:
- WordPress.org: https://wordpress.org/plugins/wordfence-login-security/
- Infrastructure security: `docs/infrastructure/CLOUDFLARE_SETUP.md`

---

### 4. limit-login-attempts-reloaded (CRITICAL)

**Slug**: `limit-login-attempts-reloaded`
**Purpose**: WordPress-level login attempt limiting with user-friendly lockouts
**Price**: FREE
**Why Essential**:

- **Problem**: Complements Fail2ban but at application level
- **Solution**: Locks WordPress accounts after N failed attempts (not just IP blocks)

**How it differs from Fail2ban**:

| Feature | Fail2ban (Server) | This Plugin (WordPress) |
|---------|-------------------|------------------------|
| Scope | System-wide, all services | WordPress only |
| Action | Blocks IP via iptables | Locks WordPress account |
| Bypass | Hard (requires UFW/iptables) | Easy (admin can unlock) |
| User-friendly | No (SSH/root access) | Yes (admin panel) |
| Whitelist | IP-based only | Username + IP |

**Why both are needed**:
```yaml
# Fail2ban: Protects infrastructure
- Blocks IPs after 3 SSH failures
- Blocks IPs after 5 wp-login.php attempts
- No easy unlock (requires SSH)

# limit-login-attempts: Protects WordPress accounts
- Locks accounts after 3 login failures
- Easy unlock: WordPress admin can reset
- User sees clear message: "Account locked for 60 minutes"
```

**Configuration**:
- Max attempts: 3
- Lockout duration: 60 minutes
- Can whitelist trusted IPs (office, admin home)

**Without this plugin**: Only hard IP blocks, no granular account protection

**References**:
- WordPress.org: https://wordpress.org/plugins/limit-login-attempts-reloaded/
- Fail2ban config: `ansible/roles/security_hardening/templates/jail.local.j2`

---

## Critical LMS Operations

### 5. updraftplus (CRITICAL)

**Slug**: `updraftplus`
**Purpose**: Automated WordPress backups to cloud storage
**Price**: FREE
**Why Critical**:

**Current Situation**:
```yaml
❌ NO automated backups currently deployed
❌ Restic documented but NOT implemented
❌ Only infrastructure code in Git (not data)
❌ Database loss = ALL courses, students, progress GONE
```

**What gets backed up**:
1. **Database**:
   - All courses, lessons, quizzes
   - Student progress and grades
   - User accounts and enrollments
   - Plugin settings
2. **Files**:
   - Uploaded videos/PDFs
   - Student assignments
   - Certificates
   - Theme customizations

**Backup destinations (all FREE)**:
- Google Drive: 15GB free
- Dropbox: 2GB free
- Microsoft OneDrive: 5GB free
- Email (small backups only)

**Recommended Schedule**:
```yaml
Database: Daily (small, critical)
Files: Weekly (larger, changes less)
Retention: 30 days
```

**Alternative (future)**:
```bash
# Restic (not yet implemented)
# Pros: Encrypted, incremental, deduplicated
# Cons: Requires Ansible role development
# Status: Documented at docs/security/BACKUP_RECOVERY.md
# Timeline: To be implemented later
```

**Without this plugin**:
- NO backups = catastrophic data loss risk
- Hardware failure = lose all courses and students
- Ransomware/hack = no recovery

**References**:
- WordPress.org: https://wordpress.org/plugins/updraftplus/
- Backup strategy: `docs/security/BACKUP_RECOVERY.md` (Restic planned, not implemented)

---

### 6. wp-mail-smtp (CRITICAL)

**Slug**: `wp-mail-smtp`
**Purpose**: Send WordPress emails via SMTP instead of PHP mail()
**Price**: FREE
**Why Critical for LMS**:

**Problem with PHP mail()**:
```yaml
# WordPress default email method:
PHP mail() function → sendmail → Internet

Issues:
❌ Goes to SPAM (no SPF/DKIM/DMARC)
❌ Unreliable delivery
❌ No tracking/logging
❌ Shared server IP reputation issues
```

**LearnDash Email Volume**:
```yaml
High-frequency emails:
- New student registration confirmation
- Course enrollment confirmation
- Lesson completion notifications
- Quiz results
- Certificate delivery
- Course progress reminders
- Instructor notifications
- Password resets
- Comment notifications

Estimated: 10-50 emails/day initially
Peak: 100-300 emails/day with active courses
```

**SMTP Provider Comparison**:

| Provider | Free Tier | Best For | Setup Difficulty |
|----------|-----------|----------|------------------|
| **Brevo (ex-Sendinblue)** ⭐ | 300/day | **RECOMMENDED** - Perfect for LMS | Easy |
| SendGrid | 100/day | Alternative if Brevo full | Medium |
| Mailgun | 5,000/month (3 months) | High volume, limited time | Medium |
| Amazon SES | 62,000/month (first year) | Advanced users, requires AWS | Hard |

**Why Brevo Free is Recommended**:
- ✅ 300 emails/day (enough for 50-100 active students)
- ✅ Easy setup (API key only)
- ✅ Email analytics dashboard
- ✅ SPF/DKIM configured automatically
- ✅ No credit card required

**Zoho Mail Clarification**:
```yaml
# User mentioned having "Zoho Mail Free"
Zoho Mail Free:
  Purpose: Email hosting (receive & read emails)
  SMTP sending: NOT included in free tier
  Use case: Webmail access only

WP Mail SMTP + Brevo:
  Purpose: Transactional emails FROM WordPress
  Different service: Not a replacement for Zoho
  Use case: Course notifications, registrations
```

**Configuration Steps**:
1. Sign up: https://app.brevo.com (free)
2. Get API key: Settings → SMTP & API → API Keys
3. WordPress: WP Mail SMTP → Settings → Brevo
4. Paste API key
5. Send test email
6. Verify: Check spam folder, move to inbox

**Without this plugin**:
- Students don't receive course emails
- Certificates never arrive
- Password resets fail
- Poor user experience = bad reviews

**References**:
- WordPress.org: https://wordpress.org/plugins/wp-mail-smtp/
- Brevo signup: https://app.brevo.com/account/register
- Email deliverability best practices: https://www.brevo.com/blog/email-deliverability/

---

### 7. seo-by-rank-math (ESSENTIAL)

**Slug**: `seo-by-rank-math`
**Purpose**: Search Engine Optimization for course pages
**Price**: FREE
**Why Essential for LMS**:

**Business Impact**:
```yaml
# Course discovery funnel:
Google Search → Course Page → Enrollment → Revenue

Without SEO:
❌ Courses invisible in Google
❌ No organic traffic
❌ 100% reliance on paid ads
❌ High customer acquisition cost

With SEO:
✅ Courses rank for relevant keywords
✅ Organic traffic (free)
✅ Lower CAC (customer acquisition cost)
✅ Passive student enrollment
```

**Rank Math FREE vs Yoast FREE**:

Comparison (2026 data):

| Feature | Rank Math FREE | Yoast FREE |
|---------|----------------|------------|
| **Keywords per post** | 5 | 1 |
| **Schema markup types** | 20+ (Course, FAQ, Review, etc.) | 2 (FAQ, HowTo) |
| **Redirect Manager** | ✅ Included | ❌ Premium only ($119/year) |
| **404 Monitoring** | ✅ Included | ❌ Premium only |
| **Internal Link Suggestions** | ✅ Included | ❌ Premium only |
| **Social Media Previews** | ✅ Facebook + Twitter | ❌ Premium only |
| **XML Sitemap** | ✅ Advanced | ✅ Basic |
| **Google Search Console Integration** | ✅ Included | ❌ Premium only |
| **Plugin Size** | 51.3k lines | 87.2k lines |
| **Performance** | Faster | Slower |

**Sources**:
- [Rank Math vs. Yoast 2026: 10 Reasons to Switch](https://onlinemediamasters.com/rank-math-vs-yoast/)
- [Kinsta: Rank Math vs Yoast SEO](https://kinsta.com/blog/rank-math-vs-yoast/)
- [Zapier: Which plugin is best? [2025]](https://zapier.com/blog/rank-math-vs-yoast/)

**Why Rank Math Wins**:
```yaml
1. Schema Markup for Courses:
   - LearnDash courses = "Course" schema
   - Google shows rich results (rating, price, provider)
   - Higher click-through rate

2. Multiple Keywords:
   - Course: "day trading course"
   - Keywords: "forex", "technical analysis", "beginners", "online", "certification"
   - Rank for 5 related terms vs 1

3. Built-in Redirects:
   - Change course URL without breaking links
   - Yoast requires $119/year Premium for this

4. Internal Linking:
   - Suggests linking related courses
   - Improves site structure and SEO

5. Social Preview:
   - See how course looks when shared on Facebook/Twitter
   - Optimize thumbnails and descriptions
```

**Without this plugin**:
- Courses hard to find in Google
- Lower enrollment from organic search
- Higher reliance on paid advertising

**References**:
- WordPress.org: https://wordpress.org/plugins/seo-by-rank-math/
- Schema markup docs: https://rankmath.com/kb/rich-snippets/
- Course schema: https://schema.org/Course

---

## Important Content & Compliance

### 8. kadence-blocks (IMPORTANT)

**Slug**: `kadence-blocks`
**Purpose**: Advanced Gutenberg blocks for content creation
**Price**: FREE
**Why Important**:

**Relationship to Kadence Theme**:
```yaml
Kadence Theme (already installed):
  - Base theme framework
  - Header/footer builder
  - Design system (colors, typography)
  - LearnDash integration

Kadence Blocks (this plugin):
  - Advanced content blocks
  - Extends Gutenberg editor
  - Designed to work with theme
  - Optional but powerful
```

**Key Blocks for LMS**:

1. **Advanced Heading**:
   - Custom typography per block
   - Gradients, animations
   - Perfect for course landing page headers

2. **Icon List**:
   - "What you'll learn" sections
   - Course features/benefits
   - Testimonial highlights

3. **Testimonials**:
   - Student reviews with photos
   - Star ratings
   - Carousel layout

4. **Pricing Tables**:
   - Compare course tiers (Basic, Pro, Premium)
   - Highlight features
   - Call-to-action buttons

5. **Accordion/Tabs**:
   - Course curriculum preview
   - FAQ sections
   - Collapsible content

6. **Advanced Button**:
   - "Enroll Now" CTAs
   - Hover effects
   - Icon support

7. **Row Layout**:
   - Complex page layouts
   - Responsive columns
   - No page builder needed

**Why NOT a Page Builder**:
```yaml
Page Builders (Elementor, Divi, etc.):
❌ Heavy (500KB+ JavaScript)
❌ Vendor lock-in (can't switch themes easily)
❌ Slower performance
❌ Conflicts with caching

Kadence Blocks + Gutenberg:
✅ Native WordPress (built-in editor)
✅ Lightweight (~100KB)
✅ Works with any theme
✅ Cache-friendly
✅ Future-proof (WordPress default)
```

**Use Cases**:
- Course landing pages
- Instructor bio pages
- About page
- Pricing page
- Testimonials page

**Without this plugin**:
- Limited to basic Gutenberg blocks
- Need page builder (heavy, slow)
- Or hire developer for custom blocks

**References**:
- WordPress.org: https://wordpress.org/plugins/kadence-blocks/
- Block library: https://www.kadencewp.com/kadence-blocks/
- Kadence theme integration: `ansible/roles/nginx_wordpress/tasks/wordpress-themes.yml`

---

### 9. cookie-notice (IMPORTANT)

**Slug**: `cookie-notice`
**Purpose**: GDPR/CCPA cookie consent compliance
**Price**: FREE
**Why Important**:

**Legal Requirement**:
```yaml
# GDPR (EU Law) - May 2018
Applies if:
  ✅ You have EU visitors (even if not targeting them)
  ✅ You use cookies (WordPress uses cookies)
  ✅ You sell to EU residents

Penalty for non-compliance:
  - Up to €20 million OR
  - 4% of global annual revenue
  - Whichever is higher

# CCPA (California Law) - January 2020
Applies if:
  ✅ California residents visit your site
  ✅ You collect personal data

Penalty:
  - $7,500 per intentional violation
```

**What Cookies WordPress Uses**:

1. **Essential (always set)**:
   ```
   wordpress_test_cookie - Check if cookies enabled
   wordpress_logged_in_* - Keep user logged in
   wp-settings-* - User preferences
   ```

2. **LearnDash (course progress)**:
   ```
   learndash_* - Track course progress
   ```

3. **Third-party (if used)**:
   ```
   Google Analytics - _ga, _gid
   Facebook Pixel - _fbp
   Cloudflare - __cfduid (if using certain features)
   ```

**Plugin Features (FREE)**:

- ✅ Cookie consent banner
- ✅ Customizable text and colors
- ✅ Accept/Reject buttons
- ✅ Cookie policy page link
- ✅ EU-only targeting (show only to EU visitors)
- ✅ Script blocking (block Google Analytics until consent)

**Configuration**:
```yaml
Banner position: Bottom bar (less intrusive)
Button text: "Accept" / "Reject"
Cookie policy page: Link to /privacy-policy
Blocking: Block Google Analytics until accept
EU only: Show only to EU visitors (saves bandwidth)
```

**Without this plugin**:
- ❌ GDPR violation (if selling to EU)
- ❌ Legal liability
- ❌ Cannot use Google Analytics legally in EU
- ❌ Fines risk

**References**:
- WordPress.org: https://wordpress.org/plugins/cookie-notice/
- GDPR official: https://gdpr.eu/cookies/
- CCPA compliance: https://oag.ca.gov/privacy/ccpa

---

## What We DON'T Install

### ❌ Caching Plugins

**NOT needed**:
- WP Super Cache
- W3 Total Cache
- WP Rocket ($59/year)
- LiteSpeed Cache
- Swift Performance

**Why NOT**:
```yaml
Infrastructure already provides:

1. Nginx FastCGI Cache:
   - Full page caching at web server level
   - Faster than any WordPress plugin
   - Cache hit = no PHP execution
   - Purged by nginx-helper plugin

2. Valkey (Redis) Object Cache:
   - Database query caching
   - Stores query results in RAM
   - Connected via redis-cache plugin
   - 90%+ database load reduction

3. Cloudflare CDN:
   - Edge caching at 300+ locations worldwide
   - Static assets (images, CSS, JS)
   - Automatic minification
   - DDoS protection included
```

**Installing caching plugins would**:
- ❌ Duplicate functionality
- ❌ Slow down site (plugin overhead)
- ❌ Cause cache conflicts
- ❌ Make debugging harder

---

### ❌ Full Security Suites

**NOT needed**:
- Wordfence (full version)
- Sucuri Security
- iThemes Security
- All In One WP Security

**Why NOT**:
```yaml
Infrastructure provides better security:

1. Cloudflare WAF (at edge):
   - Blocks attacks before hitting server
   - DDoS protection up to 1 Tbps
   - Bot Fight Mode (free)
   - Rate limiting
   - Geo-blocking

2. Server Firewall:
   - UFW: Only ports 22, 80, 443 open
   - Only Cloudflare IPs allowed
   - Fail2ban: Brute force protection
   - AppArmor: Process isolation

3. Application Security:
   - Wordfence Login Security: 2FA (lightweight module only)
   - Limit Login Attempts: Account protection
   - Strong password policy
```

**Full security plugins would**:
- ❌ Duplicate WAF (Cloudflare better)
- ❌ Duplicate firewall (UFW + Fail2ban better)
- ❌ Slow down WordPress (resource intensive)
- ❌ Cost money (Sucuri $200/year, Wordfence Premium $119/year)

---

### ❌ CDN Plugins

**NOT needed**:
- Jetpack CDN
- BunnyCDN plugin
- Any CDN integration plugin

**Why NOT**:
```yaml
Cloudflare is already configured:

1. DNS Level:
   - Domain points to Cloudflare nameservers
   - Cloudflare proxies all traffic (orange cloud)
   - Configured via Terraform

2. What Cloudflare provides:
   - 300+ edge locations worldwide
   - Automatic asset caching
   - Image optimization (paid, but HTML/CSS/JS minification free)
   - DDoS protection
   - SSL/TLS termination

3. Integration:
   - No plugin needed
   - Works at DNS/HTTP level
   - Transparent to WordPress
   - nginx-helper purges cache when content changes
```

**CDN plugins would**:
- ❌ Add unnecessary complexity
- ❌ Potential cache conflicts
- ❌ No benefit (Cloudflare already active)

**Reference**: `docs/infrastructure/CLOUDFLARE_SETUP.md`

---

### ❌ Image Optimization Plugins

**MAYBE needed** (situational):
- Smush
- ShortPixel
- Imagify

**Why NOT included**:
```yaml
Cloudflare FREE does NOT include:
  ❌ Polish (image compression)
  ❌ Mirage (lazy loading)
  ❌ WebP conversion

  Note: These are Cloudflare PRO features ($20/month)

Current recommendation:
  1. Optimize images BEFORE uploading:
     - TinyPNG.com (free, web-based)
     - Squoosh.app (free, Google tool)
     - ImageOptim (free, Mac app)

  2. Use WebP format:
     - 30% smaller than JPEG
     - Supported by all modern browsers
     - Convert before upload

  3. IF you upload many images without optimizing:
     - Then install Smush (free) or ShortPixel
     - But NOT needed if you pre-optimize
```

**Verdict**: ⚠️ **Optional** - only if uploading many unoptimized images

---

### ❌ Database Optimization

**NOT needed**:
- WP-Optimize
- Advanced Database Cleaner
- WP-Sweep

**Why NOT**:
```yaml
Valkey (Redis) handles query caching:
  - Stores frequent queries in memory
  - 90%+ reduction in database load
  - Automatic cache invalidation
  - No manual optimization needed

Database optimization plugins:
  ❌ Risky (can corrupt database if buggy)
  ❌ Not needed (Valkey solves performance issues)
  ❌ Better done manually if needed:
     wp db optimize (via WP-CLI, safer)
```

**When to manually optimize**:
- Database > 1GB (rarely happens)
- After 6+ months of use
- Only if performance issues observed

---

## Cost Analysis

### Total Cost: $0/year

| Plugin | Price | Savings vs Premium |
|--------|-------|-------------------|
| redis-cache | FREE | N/A (no premium) |
| nginx-helper | FREE | N/A (no premium) |
| wordfence-login-security | FREE | $119/year (vs Wordfence Premium) |
| limit-login-attempts-reloaded | FREE | N/A |
| **updraftplus** | FREE | $70/year (vs Premium) |
| **wp-mail-smtp** | FREE | $49/year (vs Pro) |
| **seo-by-rank-math** | FREE | $59/year (vs Pro) |
| **kadence-blocks** | FREE | $99/year (vs Pro) |
| **cookie-notice** | FREE | $29/year (vs Pro) |
| **TOTAL** | **$0** | **$425/year saved** |

### NOT Installed Savings

| NOT Installed | Reason | Savings |
|---------------|--------|---------|
| WP Rocket | Nginx FastCGI + Valkey | $59/year |
| Wordfence Premium | Cloudflare WAF | $119/year |
| Sucuri Security | Infrastructure security | $200/year |
| Jetpack Premium | Cloudflare CDN | $120/year |
| **TOTAL AVOIDED** | | **$498/year** |

### Grand Total Savings: $923/year

```yaml
Plugins installed for free: $425/year value
Avoided premium plugins: $498/year
Total: $923/year saved

Infrastructure cost: ~€4/month (Hetzner CAX11)
WordPress plugin cost: $0/month

ROI: Infinite (free plugins on cheap infrastructure)
```

---

## Summary

**9 Plugins Auto-Installed (All FREE)**:

1. ✅ redis-cache - Valkey object cache
2. ✅ nginx-helper - FastCGI cache purging
3. ✅ wordfence-login-security - 2FA
4. ✅ limit-login-attempts-reloaded - Login protection
5. ✅ updraftplus - Backups (CRITICAL - no other backup currently)
6. ✅ wp-mail-smtp - Email delivery (CRITICAL for LMS)
7. ✅ seo-by-rank-math - SEO (better than Yoast Free)
8. ✅ kadence-blocks - Content blocks
9. ✅ cookie-notice - GDPR compliance

**What Makes This Stack Optimal**:

```yaml
✅ Zero redundancy - Each plugin serves unique purpose
✅ Infrastructure integration - Leverages Nginx, Valkey, Cloudflare
✅ LMS-specific - Selected for LearnDash needs (email, SEO, backups)
✅ Performance-first - No heavy plugins (caching, security suites)
✅ Cost-optimized - $0 spent, $923/year value
✅ Future-proof - All from WordPress.org, actively maintained
```

**Post-Installation Requirements**:

User must configure (5-10 minutes):
1. UpdraftPlus → Connect Google Drive/Dropbox
2. WP Mail SMTP → Add Brevo API key
3. Rank Math → Run setup wizard
4. Cookie Notice → Enable GDPR banner
5. Wordfence Login Security → Enable 2FA for admins

**References**:
- WordPress plugin installation: `ansible/roles/nginx_wordpress/tasks/wordpress-plugins.yml`
- Infrastructure security: `docs/infrastructure/CLOUDFLARE_SETUP.md`
- Backup strategy: `docs/security/BACKUP_RECOVERY.md`

---

**Last Updated**: 2026-01-14
**Maintained By**: Infrastructure Team
**Review Frequency**: Quarterly (or when WordPress/LearnDash major updates)
