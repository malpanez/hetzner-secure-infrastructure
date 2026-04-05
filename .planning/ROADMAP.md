# Roadmap: Two Minds Trading — Dual WordPress Infrastructure Rebuild

## Overview

Rebuild of a Hetzner CAX11 ARM64 VPS from a single compromised WordPress install into two
independent, isolated sites: twomindstrading.com (marketing, Kadence) and
academy.twomindstrading.com (LMS, LearnDash + WooCommerce + Kadence). Work starts with IaC
refactoring and Terraform DNS changes on the current server, validates through Molecule/lint,
then executes a clean terraform destroy + apply, applies all Ansible automation, and finishes
with content and plugin configuration on each site.

Phase 0 (content backup, XML export, screenshots) is already complete and is not included.

## Phases

**Phase Numbering:**

- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

- [x] **Phase 1: IaC Refactor** - Refactor nginx_wordpress role and playbook for dual-site support + Terraform DNS
- [x] **Phase 2: Testing & Validation** - Molecule tests + lint clean on feature/dual-wordpress branch
- [ ] **Phase 3: Server Rebuild** - terraform destroy + apply, full Ansible deploy, OpenBao + OPS hardening
- [ ] **Phase 3.5: Backup Infrastructure** (INSERTED) - Hetzner Object Storage bucket + encrypted automated backups for MariaDB and WordPress media
- [ ] **Phase 4: Main Site** - twomindstrading.com content, plugins, performance, backups
- [ ] **Phase 5: Academy Site** - academy.twomindstrading.com LMS, WooCommerce, course setup, backups

## Phase Details

### Phase 1: IaC Refactor

**Goal**: The nginx_wordpress role and dual-wordpress.yml playbook are ready to deploy two independent WordPress sites, with correct cache isolation, per-site PHP-FPM pools, Valkey DB separation, and academy-specific bypass rules.
**Depends on**: Nothing (first phase)
**Requirements**: ROLE-01, ROLE-02, ROLE-03, ROLE-04, ROLE-05, ROLE-06, ROLE-07, PLAY-01, PLAY-02, PLAY-03, PLAY-04, PLAY-05, WP-01, WP-02, WP-03, TF-01
**Success Criteria** (what must be TRUE):

  1. `dual-wordpress.yml` runs with `--check` against the current server without errors
  2. Each vhost template has its own `fastcgi_cache_path` and zone name parametrized with `nginx_wordpress_site_name` — no shared global cache path in `conf.d/`
  3. `wp-config.php.j2` renders distinct `WP_REDIS_DATABASE` and `WP_REDIS_PREFIX` for main vs academy invocations
  4. Academy vhost includes WooCommerce bypass cookie/path rules and `/ld-focus-mode/` bypass
  5. Terraform plan shows `academy.twomindstrading.com` DNS A record as a new resource with no unintended changes
**Plans**: 4 plans

Plans:

- [x] 01-01: Refactor nginx_wordpress role — variables, PHP-FPM pool template, vhost template (ROLE-01 to ROLE-07)
- [x] 01-02: Build dual-wordpress.yml playbook — MariaDB setup, two include_role invocations, vault vars (PLAY-01 to PLAY-05)
- [x] 01-03: Update wp-config.php.j2 template for per-site Valkey DB and prefix (WP-01, WP-02, WP-03)
- [x] 01-04: Add academy DNS A record to Terraform cloudflare-config/dns.tf (TF-01)

### Phase 2: Testing & Validation

**Goal**: The refactored role passes Molecule tests and the entire codebase is lint-clean on the feature branch, confirming the IaC changes are safe to run against a real server.
**Depends on**: Phase 1
**Requirements**: TEST-01, TEST-02
**Success Criteria** (what must be TRUE):

  1. `molecule test` completes successfully in the `nginx_wordpress` role with no task failures
  2. `ansible-lint` exits 0 with production profile on the full playbook tree
  3. `pre-commit run --all-files` exits 0 on the feature/dual-wordpress branch (yamllint, gitleaks)
  4. `terraform validate && terraform fmt -check -recursive` exits 0
**Plans**: 2 plans

Plans:

- [x] 02-01: Run and fix Molecule tests for refactored nginx_wordpress role (TEST-01)
- [x] 02-02: Run and fix ansible-lint, pre-commit, and terraform validate (TEST-02)

### Phase 3: Server Rebuild

**Goal**: A clean Hetzner VPS is running with both WordPress installs deployed by Ansible, MariaDB binary logging active, OpenBao operational and rotation configured, fail2ban and AppArmor covering both site paths, and Valkey sized correctly.
**Depends on**: Phase 2
**Requirements**: INFRA-01, INFRA-02, INFRA-03, INFRA-04, OPS-01, OPS-02, OPS-03, OPS-04, OPS-05
**Success Criteria** (what must be TRUE):

  1. Both site document roots exist (`/var/www/twomindstrading.com`, `/var/www/academy.twomindstrading.com`) with WordPress files installed
  2. MariaDB has two databases (`wordpress_main`, `wordpress_academy`) and two users (`wp_main`, `wp_academy`) with no cross-access
  3. `curl -I https://twomindstrading.com` and `curl -I https://academy.twomindstrading.com` both return HTTP 200 or 301 with valid Cloudflare headers
  4. OpenBao primary (8200) is unsealed and `setup-openbao-rotation.yml` has run cleanly with cron entries present
  5. MariaDB binary logs are active (`SHOW MASTER STATUS` returns a log file)
  6. Fail2ban is active and `fail2ban-client status` shows jails watching both nginx log paths
**Plans**: 3 plans

Plans:

- [ ] 03-01: Execute terraform destroy + apply in maintenance window; manually unseal OpenBao transit (8201) then start primary (8200) (INFRA-01, INFRA-02, INFRA-03)
- [ ] 03-02: Run site.yml + dual-wordpress.yml on new server; apply binary logging tag; configure OPS hardening — Valkey maxmemory, fail2ban dual-path, AppArmor wildcard paths (INFRA-04, OPS-01, OPS-02, OPS-04, OPS-05)
- [ ] 03-03: Run setup-openbao-rotation.yml; verify cron entries, token files, and WP_PATH pointing to /var/www/twomindstrading.com (OPS-03)

### Phase 3.5: Backup Infrastructure (INSERTED)

**Goal**: Automated encrypted backups for both MariaDB databases and WordPress media directories are running daily to Hetzner Object Storage, with credentials managed via OpenBao and 7-daily/4-weekly/3-monthly retention enforced via S3 lifecycle policy.
**Depends on**: Phase 3
**Requirements**: BACKUP-01, BACKUP-02, BACKUP-03, BACKUP-04, BACKUP-05, BACKUP-06, BACKUP-07, BACKUP-08, BACKUP-09, BACKUP-10
**Success Criteria** (what must be TRUE):

  1. Hetzner Object Storage bucket `tmt-backups` exists and is accessible from the VPS
  2. `systemctl status backup-wordpress.timer` shows the timer active and next trigger at 02:30
  3. Manual run of backup script completes without errors and lists uploaded objects in S3
  4. Backup files in S3 are non-zero, AES-256 encrypted, and named with date/type prefix
  5. S3 credentials are NOT present in any file on disk — script reads from OpenBao at runtime
  6. `molecule test` passes in the `backup` role
**Plans**: 3 plans

Plans:

- [ ] 03.5-01: Terraform — Hetzner Object Storage bucket + lifecycle policy (BACKUP-01)
- [ ] 03.5-02: Ansible role `backup` — mysqldump + media tar + encrypt + S3 upload + systemd timer (BACKUP-02, BACKUP-03, BACKUP-06, BACKUP-08, BACKUP-09)
- [ ] 03.5-03: OpenBao integration — seed secret/backup, policy backup-reader, token at /root/.openbao-backup-token; update openbao-bootstrap.yml (BACKUP-04, BACKUP-05, BACKUP-07, BACKUP-10)

### Phase 4: Main Site

**Goal**: twomindstrading.com is live with Kadence theme, imported content rebuilt as Kadence Blocks pages, minimum plugin stack active, UpdraftPlus backing up daily to Google Drive, and LCP under 2 seconds on mobile.
**Depends on**: Phase 3
**Requirements**: MAIN-01, MAIN-02, MAIN-04, MAIN-05, MAIN-06, MAIN-07, MAIN-08, MAIN-09, MAIN-10
**Success Criteria** (what must be TRUE):

  1. twomindstrading.com loads with Kadence theme — no Elementor assets, no Hello Elementor theme present
  2. Five pages are live and navigable: home, metodologia, cursos, instructores, contacto
  3. Cursos page has visible CTAs that link to academy.twomindstrading.com
  4. Google PageSpeed Insights mobile score is >90 and LCP is <2s
  5. UpdraftPlus shows a completed backup in Google Drive (DB + files)
  6. WP-cron is disabled in wp-config.php and a system cron entry runs `wp cron event run` for this site
**Plans**: 3 plans

Plans:

- [ ] 04-01: Install Kadence theme + Kadence Blocks; install and activate plugin stack (MAIN-01, MAIN-07, MAIN-09, MAIN-10)
- [ ] 04-02: Import XML from Phase 0 export; reconstruct pages in Kadence Blocks; configure Kadence Google Fonts as Local (MAIN-02, MAIN-04, MAIN-05)
- [ ] 04-03: Configure UpdraftPlus backup to Google Drive; run PageSpeed test and fix LCP issues until >90 (MAIN-06, MAIN-08)
**UI hint**: yes

### Phase 5: Academy Site

**Goal**: academy.twomindstrading.com is live with LearnDash Pro installed (manually), WooCommerce configured for enrollment and payment, at least one course created end-to-end, UpdraftPlus backing up daily to Google Drive, and Valkey object cache confirmed working without LearnDash user meta staleness.
**Depends on**: Phase 4
**Requirements**: ACAD-01, ACAD-02, ACAD-03, ACAD-04, ACAD-05, ACAD-06, ACAD-07, ACAD-08, ACAD-09
**Success Criteria** (what must be TRUE):

  1. academy.twomindstrading.com loads with Kadence theme and no Elementor assets
  2. LearnDash Pro is installed and the license is active (LD admin menu visible)
  3. WooCommerce checkout completes for a test product and enrolls the user in a LearnDash course
  4. At least one course with one lesson is published and accessible post-purchase
  5. WooCommerce HPOS compatibility check passes or HPOS is explicitly disabled without warnings
  6. UpdraftPlus shows a completed backup in Google Drive (DB + files)
  7. WP-cron is disabled in wp-config.php and a system cron entry runs `wp cron event run` for this site
**Plans**: 4 plans

Plans:

- [ ] 05-01: Install Kadence theme + Kadence Blocks; install plugin stack (no LearnDash yet); configure WP-cron system cron (ACAD-01, ACAD-05, ACAD-07, ACAD-08)
- [ ] 05-02: Manually install LearnDash Pro ZIP via wp-admin; install LearnDash Course Grid + WooCommerce Integration bridge; check HPOS compatibility (ACAD-02, ACAD-09)
- [ ] 05-03: Configure WooCommerce — Stripe or PayPal gateway, enrollment flow; create one complete test course; verify purchase → enrollment works end-to-end (ACAD-03, ACAD-04)
- [ ] 05-04: Configure UpdraftPlus backup to Google Drive; verify Valkey object cache with LearnDash (test for user meta staleness; configure cache group exclusions if needed) (ACAD-06)
**UI hint**: yes

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 3.5 → 4 → 5 → 6 → 7

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. IaC Refactor | 4/4 | Complete | 2026-03-28 |
| 2. Testing & Validation | 2/2 | Complete | 2026-03-29 |
| 3. Server Rebuild | 0/3 | Not started | - |
| 3.5. Backup Infrastructure | 0/3 | Not started | - |
| 4. Main Site | 0/3 | Not started | - |
| 5. Academy Site | 0/4 | Not started | - |
| 6. OpenBao Secret Coverage | 2/2 | Complete   | 2026-04-02 |
| 7. Unified deploy.yml | 3/3 | Complete   | 2026-04-05 |

### Phase 6: Complete OpenBao secret coverage and rotation — academy scripts, Grafana/exporter/SMTP/Stripe in KV, static credentials MOTD

**Goal:** All service credentials are stored in OpenBao KV, both sites have rotation coverage (DB daily + admin monthly), and a static MOTD shows retrieval commands so any operator SSHing into the server can immediately find any credential.
**Requirements**: OPS-03
**Depends on:** Phase 5
**Plans:** 2/2 plans complete

Plans:
- [x] 06-01: Extend openbao-bootstrap.yml with KV seeding for Grafana, MariaDB exporter, SMTP, Stripe, and academy WP admin + update secrets.yml.example (OPS-03)
- [x] 06-02: Add academy rotation scripts (DB daily + WP admin monthly), update monthly service, deploy static credentials MOTD (OPS-03)

### Phase 7: Unified deploy.yml orchestrator — single-command fresh deployment with auto-pause checkpoints for OpenBao transit and primary initialization

**Goal:** A single `ansible-playbook playbooks/deploy.yml` command deploys the entire stack on a fresh server, with automatic pause checkpoints at transit and primary OpenBao initialization for credential saving, and full idempotency on re-runs.
**Requirements**: DEPLOY-01, DEPLOY-02, DEPLOY-03
**Depends on:** Phase 6
**Plans:** 3/3 plans complete

Plans:
- [x] 07-01: Create deploy.yml unified orchestrator with inline OpenBao bootstrap plays and conditional pauses + safe default for transit token (DEPLOY-01, DEPLOY-02)
- [x] 07-02: Rewrite deployment-playbook.md to 3-step workflow with day-2 operations reference (DEPLOY-03)
- [x] 07-03: Gap closure — academy SSL cert, KV seeding parity, MOTD VAULT_ADDR HTTPS (DEPLOY-01, DEPLOY-02)
