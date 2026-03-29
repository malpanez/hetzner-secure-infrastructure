# Technology Stack Research: Two Minds Trading — WordPress + LearnDash

**Project:** twomindstrading.com + academy.twomindstrading.com
**Researched:** 2026-03-28
**Confidence note:** WebSearch and WebFetch unavailable in this session. All findings are from
training data (cutoff Aug 2025). Items marked LOW confidence need manual verification before
committing to implementation.

---

## 1. LearnDash + WooCommerce Integration Stack

### Recommended Plugin Stack (MEDIUM confidence)

| Plugin | Role | Notes |
|--------|------|-------|
| LearnDash LMS Pro | Core LMS | Already licensed |
| WooCommerce 8.x / 9.x | Payments + checkout | See version note below |
| LearnDash WooCommerce Integration | Bridge: purchase → enrollment | Official add-on, free |
| WooCommerce Stripe Gateway | Payment processor | Preferred over PayPal for EU/UK |
| LearnDash Course Grid | Course catalog display | Gutenberg blocks |

### WooCommerce Version Compatibility (MEDIUM confidence)

As of mid-2025, WooCommerce 9.x was stable. LearnDash officially tested against WooCommerce 8.x
and generally kept pace with minor version increments.

**Recommendation:** Use the latest WooCommerce 9.x release at time of deploy. Do not pin to
a specific minor version — the LearnDash WooCommerce Integration plugin tracks compatibility
and will flag issues in WP admin if a mismatch is detected.

**GOTCHA — HIGH PRIORITY:** WooCommerce introduced High-Performance Order Storage (HPOS) as
default in WooCommerce 8.2+. The LearnDash WooCommerce Integration plugin had partial HPOS
support as of late 2024. Verify HPOS compatibility before going live:

- In WP Admin → WooCommerce → Settings → Advanced → Features → "Order data storage"
- If the LearnDash bridge plugin shows a compatibility warning, disable HPOS (keep legacy
  post-ba<https://github.com/LearnDash/learndash-woocommerce/issues>ort.
- Track: <https://github.com/LearnDash/learndash-woocommerce/issues>

### Is LearnDash WooCommerce Integration still the right bridge? (HIGH confidence)

Yes. There is no better alternative for native LearnDash enrollment from WooCommerce purchase.

The plugin:

- Maps WooCommerce products to LearnDash courses (1:1 or 1:many)
- Triggers enrollment on order completion
- Handles refund → unenrollment
- Supports WooCommerce Subscriptions for recurring enrollment

Third-party bridges (e.g. via Zapier or custom webhooks) add failure modes and are not worth
the complexity on a single-server setup.

---

## 2. Cross-Site Enrollment Flow: Buy on Site A, Access on Site B

### The Core Problem (HIGH confidence)

WooCommerce enrollment only works within the same WordPress install. When the shop and the LMS
are on separate WordPress installs, you cannot use the standard LearnDash WooCommerce Integration
plugin natively across domains.

### Real-World Patterns

#### Pattern A: Consolidate shop onto academy.twomindstrading.com (RECOMMENDED)

Put WooCommerce AND LearnDash on the academy site only. The marketing site (twomindstrading.com)
links directly to course sales pages on academy.twomindstrading.com.

- Pros: simple, no sync complexity, official plugin works natively, all user accounts in one place
- Cons: requires user to leave twomindstrading.com for checkout

**This is the cleanest pattern for a single-operator LMS business.** The CTA on the marketing
site becomes a link to `academy.twomindstrading.com/courses/[course-name]` or a dedicated
sales/checkout page on the academy. This is already aligned with the stated enrollment flow.

Confidence: HIGH — this is what the project description already implies. WooCommerce lives on

academy only.

#### Pattern B: WooCommerce on main site, sync enrollment via webhook/API (LOW confidence)

WooCommerce on twomindstrading.com triggers a webhook on order completion. A custom endpoint on
academy.twomindstrading.com calls `ld_update_course_access()` to enroll the user.

- Requires: shared user accounts (same user_login / email across both WP installs) OR a
  user-creation step on the academy side
- Failure modes: webhook delivery failure = no enrollment. Needs retry logic.
- The "Uncanny Automator" plugin can partially automate cross-site flows but requires its own
  licensing and adds significant complexity.

This pattern is not recommended for a two-person operation or MVP. It is viable at scale if
the marketing funnel requires full checkout on the main domain, but the added operational

overhead (two user tables to sync, webhook monitoring, token-based auth between sites) is
not worth it here.

#### Pattern C: WordPress Multisite (REJECTED)

Explicitly out of scope per project brief. Listed only to close the option.

### Verdict

Use Pattern A. WooCommerce and LearnDash both on academy.twomindstrading.com. The marketing
site is Kadence + content only — no WooCommerce, no user accounts. CTA buttons are plain links.

**GOTCHA:** Because users have accounts only on academy.twomindstrading.com, the main site
should not present any "My Account" or "Dashboard" links. Keep the two sites conceptually
separate in the user's mind: twomindstrading.com = content/brand, academy.twomindstrading.com = product.

---

## 3. Minimum Plugin Set for Kadence + Gutenberg Marketing Site

### Recommended (HIGH confidence)

| Plugin | Purpose | Notes |
|--------|---------|-------|
| Kadence Theme | Theme | Already in use |
| Kadence Blocks | Gutenberg block library | Core companion to the theme |
| Kadence Starter Templates | One-time use for import, then deactivate | Deactivate after setup |
| Yoast SEO or Rank Math | SEO meta, sitemap | Pick one, not both |
| WP 2FA | Admin account security | Already in use |
| Nginx Helper | FastCGI cache purge | Already in use — keep |
| Redis Object Cache | Valkey object caching | Keep, required for Valkey |
| UpdraftPlus | Backups | See section 4 |

### What to NOT install on the marketing site (HIGH confidence)

- WooCommerce: not needed, adds 50+ DB tables and significant overhead
- Contact Form 7 / WPForms: use a simple mailto link or Tally.so embed instead (no DB writes,
  no plugin to maintain, no spam handling). If a form is truly needed, WPForms Lite is lighter
  than CF7 but still adds overhead.
- Jetpack: bloated, requires WordPress.com account, conflicts with many caching setups
- Page builders (Elementor, Divi): Kadence Blocks is already a block builder. Do not mix.

### Plugins to explicitly avoid with Kadence Blocks (MEDIUM confidence)

**Elementor / Elementor Pro:** Creates parallel CSS/JS output. Even when inactive on a page,
the plugin registers scripts globally. If installed alongside Kadence Blocks it will fire
`wp_enqueue_scripts` hooks that conflict with Kadence's asset loading. Do not install.

**Beaver Builder:** Same class of conflict as Elementor. Not compatible as a co-active builder.

**WP Rocket (if using Nginx FastCGI cache):** WP Rocket's page cache and Nginx FastCGI cache
will double-cache and create purge conflicts. You already have FastCGI cache + Nginx Helper.
Do not add WP Rocket. Use Nginx Helper for cache purge only.

**LiteSpeed Cache:** Only relevant on LiteSpeed servers. On Nginx it is a no-op for page cache
but still loads and registers hooks. Do not install.

**GOTCHA — Kadence Blocks + Redis Object Cache:** Kadence Blocks stores compiled CSS for
individual posts in the database (post meta). If object caching is aggressive, stale CSS
can be served after a theme change. After any Kadence global style update, run:
`wp cache flush` or clear the object cache from WP Admin → Settings → Redis (or Valkey).
This is a known pattern, not a conflict, but it surprises people during theme development.

---

## 4. Backup Solution Comparison for VPS

### Options Evaluated

| Plugin | Self-hosted storage | Performance impact | DB backup | Incremental | Verdict |
|--------|--------------------|--------------------|-----------|-------------|---------|
| UpdraftPlus Free | Yes (local + remote) | Low (scheduled, offpeak) | Yes | No (full) | Good for MVP |
| UpdraftPlus Premium | Yes + more remotes | Low | Yes | Yes (Premium) | Best if paying |
| WPvivid | Yes | Low-medium | Yes | Yes (on paid) | Solid alternative |
| All-in-One WP Migration | Primarily for migrations | Medium during export | Yes | No | Wrong tool |
| BackWPup Free | Yes | Low | Yes | No | Adequate, less polished |
| Duplicator Pro | Primarily migrations + staging | Medium | Yes | Yes (Pro) | Wrong tool |

### Recommendation: UpdraftPlus (MEDIUM-HIGH confidence)

UpdraftPlus Free is sufficient for this setup at MVP stage. Reasons:

1. Sends backups to remote storage (Hetzner Object Storage, Backblaze B2, S3) — critical because
   a backup stored only on the same server is not a backup.
2. Schedules independent DB and files backups. For WordPress, the DB is the crown jewel;

   files (themes/plugins) are reproducible. Run DB backup more frequently than files.
3. Low overhead: runs during off-peak, does not hold page cache during backup.
4. Mature codebase, widely documented troubleshooting.

**Recommended schedule:**

- DB backup: daily, retain 7 copies → remote storage
- Files backup: weekly, retain 4 copies → remote storage

**For remote storage target:** Hetzner Object Storage (S3-compatible) is the natural fit given
the existing Hetzner infrastructure. UpdraftPlus Free supports S3-compatible endpoints.

**GOTCHA:** UpdraftPlus requires WP-cron to fire for scheduled backups. On a Nginx + PHP-FPM
setup with low traffic, WP-cron may not fire reliably (it's triggered by page visits).

Fix: disable WP-cron from HTTP trigger and add a real cron job:

```
# /etc/cron.d/wp-cron-academy
*/15 * * * * www-data /usr/bin/wp --path=/var/www/academy cron event run --due-now --quiet
*/15 * * * * www-data /usr/bin/wp --path=/var/www/wordpress cron event run --due-now --quiet
```

Add `define('DISABLE_WP_CRON', true);` to each wp-config.php.

### WPvivid as alternative (MEDIUM confidence)

WPvivid Free includes incremental file backups on the free tier (as of 2024), which UpdraftPlus
does not. If storage cost is a concern and site files are large (many media uploads), WPvivid
Free is a reasonable alternative. It has less community documentation than UpdraftPlus.

---

## 5. Known Conflicts: LearnDash Pro + WooCommerce + Kadence + Redis Object Cache

### LearnDash + Redis Object Cache (MEDIUM confidence)

**Known issue:** LearnDash stores course progress, quiz results, and user meta in wp_usermeta
and custom tables. The Redis Object Cache plugin caches wp_usermeta reads. If a quiz result
is written and the cache is not invalidated, users can see stale progress data (e.g., showing
a quiz as "not attempted" immediately after completion).

**Mitigation:**

- Use Redis Object Cache's "selective cache groups" feature to exclude LearnDash user meta keys.
- Alternatively, add to wp-config.php on the academy site:

  ```php
  // Exclude LearnDash user meta from object cache
  // Key groups: 'user_meta', 'sfwd-*'
  ```

- Check the Redis Object Cache plugin settings for group exclusions.
- This is documented in LearnDash community forums but not in official docs as of 2024.

**GOTCHA — HIGH PRIORITY:** Test quiz completion and progress tracking with Redis/Valkey active.
If a user completes a lesson and the progress does not update immediately, object cache is the
first suspect.

### LearnDash + WooCommerce + HPOS (MEDIUM confidence — see Section 1)

Already flagged above. This is the highest-risk compatibility issue in this stack.

### LearnDash + Kadence (LOW conflict risk — HIGH confidence)

No known conflicts. LearnDash uses its own shortcodes and Gutenberg blocks. Kadence Blocks
does not intercept LearnDash's template overrides. Kadence theme's page templates are
compatible with LearnDash's course, lesson, and quiz templates.

**Minor UX note:** LearnDash renders its own navigation (Previous/Next lesson buttons) inside
its template. Kadence's full-width or contained layout settings affect the wrapper, not the
LearnDash content area. Set LearnDash course pages to use a layout without a sidebar for
the cleanest rendering.

### WooCommerce + Kadence (LOW conflict risk — HIGH confidence)

Kadence includes built-in WooCommerce compatibility (shop, cart, checkout, account page
templates). No extra plugin needed. Do not install "Storefront" or other WooCommerce themes
alongside Kadence.

**GOTCHA:** Kadence's WooCommerce compatibility is included in the Kadence theme, not Kadence
Blocks. If only Kadence Blocks is active without the Kadence theme (e.g., using a different

base theme), the WooCommerce templates fall back to WooCommerce defaults which may be unstyled.

### Redis + WooCommerce (MEDIUM confidence)

WooCommerce explicitly excludes cart and session data from object cache (it uses its own
WooCommerce session handler). The Redis Object Cache plugin respects this. No conflicts expected.

**GOTCHA:** WooCommerce sessions are stored in wp_woocommerce_sessions table (or in DB-based
sessions). Do not cache this table. Redis Object Cache does not cache DB tables directly, so
this is only relevant if you add a full-page cache layer that might cache checkout pages.
Nginx FastCGI cache must exclude:

- `/cart/`, `/checkout/`, `/my-account/`, `/wp-admin/`
- Cookies: `woocommerce_*`, `wordpress_logged_in_*`

This is standard FastCGI cache configuration — verify your Nginx config has these exclusions.

### Full Stack Interaction Summary

```
twomindstrading.com (marketing):
  Kadence Theme + Kadence Blocks + Valkey/Redis → No material conflicts

academy.twomindstrading.com (LMS):
  Kadence Theme + LearnDash Pro + WooCommerce + LearnDash WC Integration
  + Valkey/Redis → TWO risk areas:
    1. HPOS compatibility (verify explicitly before launch)
    2. Redis object cache + LearnDash user meta (test quiz progress flow)
```

---

## Sources and Confidence Summary

| Claim | Confidence | Needs Verification |
|-------|------------|-------------------|
| LearnDash WC Integration plugin is correct bridge | HIGH | No |
| WooCommerce HPOS conflict with LearnDash | MEDIUM | YES — check learndash-woocommerce GitHub issues |
| Pattern A (shop on academy only) is cleanest | HIGH | No |
| Kadence Blocks + Elementor conflict | HIGH | No |
| Redis + LearnDash user meta staleness | MEDIUM | YES — test in staging |
| UpdraftPlus free + S3-compatible storage | MEDIUM-HIGH | Verify Hetzner Object Storage endpoint works with UpdraftPlus |
| WP-cron must be replaced with real cron | HIGH | No |
| WooCommerce cart/checkout FastCGI exclusions | HIGH | Verify current nginx.conf has these |

**All findings are from training data (cutoff Aug 2025). No live web search was available.**
**Flag LOW/MEDIUM confidence items for manual verification before implementation.**
