# System Architecture Overview

**Last Updated**: 2024-12-31
**Status**: Production-Ready (95% complete)
**Target Deployment**: 2 Enero 2025

---

## 🎯 Purpose

This document provides a complete architectural overview of the Hetzner-based WordPress LMS infrastructure, including all components, data flows, security layers, and operational considerations.

---

## 📊 High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        CLOUDFLARE (CDN)                         │
│  ✓ WAF & DDoS Protection    ✓ Edge Caching    ✓ SSL/TLS        │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTPS (443)
                      ↓
┌─────────────────────────────────────────────────────────────────┐
│                    HETZNER CLOUD SERVER                         │
│                 (CX23 x86 or CAX11 ARM64)                       │
│                                                                 │
│  ┌────────────────────────────────────────────────────────┐   │
│  │                    NGINX (Web Server)                   │   │
│  │  ✓ Reverse Proxy    ✓ FastCGI Cache    ✓ Rate Limiting │   │
│  └──────┬──────────────────────────┬──────────────────────┘   │
│         │                          │                            │
│         ↓                          ↓                            │
│  ┌─────────────┐          ┌──────────────────┐                │
│  │  PHP-FPM    │          │   Monitoring     │                │
│  │  (8.4)      │          │   Endpoints      │                │
│  └──────┬──────┘          │ • Grafana :3000  │                │
│         │                 │ • Prometheus     │                │
│         ↓                 │ • Loki           │                │
│  ┌─────────────┐          └──────────────────┘                │
│  │ WordPress   │                                                │
│  │   + LMS     │                                                │
│  └──────┬──────┘                                                │
│         │                                                       │
│    ┌────┴────┐                                                 │
│    ↓         ↓                                                 │
│ ┌────────┐ ┌──────┐                                           │
│ │MariaDB │ │Valkey│                                           │
│ │(11.4)  │ │(8.0) │                                           │
│ └────────┘ └──────┘                                           │
│                                                                 │
│  ┌──────────────────────────────────────────────────────┐    │
│  │           Security & Monitoring Layer                 │    │
│  │  • UFW Firewall  • Fail2ban  • AppArmor              │    │
│  │  • Prometheus    • Loki      • Node Exporter         │    │
│  └──────────────────────────────────────────────────────┘    │
└─────────────────────────────────────────────────────────────────┘
```

---

## 🏗️ Component Stack

### Application Layer

| Component | Version | Purpose | Port |
|-----------|---------|---------|------|
| **Nginx** | 1.27.3 | Web server, reverse proxy, FastCGI cache | 80, 443 |
| **PHP-FPM** | 8.4 | WordPress application runtime | Unix socket |
| **WordPress** | Latest | CMS + LearnDash LMS | - |
| **MariaDB** | 11.4 | Relational database (WordPress data) | 3306 (localhost) |
| **Valkey** | 8.0 | Object cache (Redis fork) | 6379 (localhost) |

### Monitoring Layer

| Component | Version | Purpose | Port |
|-----------|---------|---------|------|
| **Prometheus** | 3.8+ | Metrics collection & storage | 9090 |
| **Grafana** | Latest | Metrics visualization & dashboards | 3000 |
| **Loki** | Latest | Log aggregation & storage | 3100 |
| **Promtail** | Latest | Log shipping agent | 9080 |
| **Node Exporter** | Latest | System metrics exporter | 9100 |

### Security Layer

| Component | Purpose | Status |
|-----------|---------|--------|
| **UFW** | Firewall (ports 22, 80, 443 only) | ✅ Active |
| **Fail2ban** | Brute force protection | ✅ Active |
| **AppArmor** | Mandatory access control | ✅ Enforcing |
| **Cloudflare WAF** | Web application firewall | ✅ Enabled |
| **Nginx Rate Limiting** | Login/API abuse prevention | ✅ Configured |

---

## 🔄 Data Flow

### 1. User Request Flow (WordPress Page)

```
User Browser
    ↓ HTTPS Request
Cloudflare CDN
    ├─ Cache HIT? → Serve from edge (fast!)
    └─ Cache MISS? ↓
Nginx (Hetzner Server)
    ├─ Static file? → Serve directly (images, CSS, JS)
    ├─ FastCGI Cache HIT? → Serve cached HTML
    └─ FastCGI Cache MISS? ↓
PHP-FPM
    ├─ Execute WordPress PHP
    ├─ Query Valkey (object cache)
    │   ├─ Cache HIT? → Return cached data
    │   └─ Cache MISS? ↓
    └─ Query MariaDB → Generate HTML → Cache in FastCGI
Nginx
    ↓ Return HTML to user
Cloudflare
    ↓ Cache at edge for next user
User Browser
```

**Latency Breakdown** (CX23 x86 tested):
- Cloudflare edge cache HIT: **~10-20ms** (global)
- Nginx FastCGI cache HIT: **~10ms** (server)
- Full PHP execution: **~100-300ms** (first request)

### 2. Monitoring Data Flow

```
System Services (Nginx, PHP, MariaDB, Valkey)
    ↓ /metrics endpoint
Node Exporter (port 9100)
    ↓ Scrape every 15s
Prometheus (port 9090)
    ├─ Store metrics (15-day retention)
    └─ Provide PromQL API
Grafana (port 3000)
    ↓ Query Prometheus
User Dashboard (Browser)

Logs (/var/log/nginx/*, /var/log/syslog)
    ↓ Tail logs
Promtail
    ↓ Ship to Loki
Loki (port 3100)
    ├─ Store logs (7-day retention)
    └─ Provide LogQL API
Grafana
    ↓ Query Loki
User Dashboard (Browser)
```

---

## 🌐 Network Architecture

### Ports Configuration

| Port | Service | Accessible From | Firewall |
|------|---------|-----------------|----------|
| **22** | SSH | Admin IP only | UFW Allow (restricted) |
| **80** | HTTP | Public (→ 443) | UFW Allow |
| **443** | HTTPS | Public | UFW Allow |
| **3000** | Grafana | Admin IP only | UFW Deny (access via SSH tunnel) |
| **3306** | MariaDB | Localhost only | Not exposed |
| **6379** | Valkey | Localhost only | Not exposed |
| **9090** | Prometheus | Admin IP only | UFW Deny (access via SSH tunnel) |
| **9100** | Node Exporter | Localhost only | Not exposed |

### Cloudflare Integration

**DNS Configuration**:
```
@ (root)       → Hetzner Server IP (Proxied)
www            → Hetzner Server IP (Proxied)
grafana        → Hetzner Server IP (DNS Only - optional)
```

**Cloudflare Features Enabled**:
- ✅ Proxy (orange cloud) - hides real server IP
- ✅ WAF (Web Application Firewall)
- ✅ DDoS protection (automatic)
- ✅ Edge caching (CDN)
- ✅ SSL/TLS (Full Strict mode)
- ✅ Auto-minify (HTML, CSS, JS)
- ✅ Brotli compression

---

## 💾 Data Storage

### Filesystem Layout

```
/var/www/wordpress/               # WordPress installation
├── wp-content/
│   ├── uploads/                  # User-uploaded files (images, PDFs)
│   ├── plugins/                  # WordPress plugins
│   └── themes/                   # WordPress themes
└── wp-config.php                 # WordPress configuration (protected)

/var/cache/nginx/wordpress/       # FastCGI page cache (512MB max)

/var/lib/mysql/                   # MariaDB database files
└── wordpress/                    # WordPress database

/var/lib/prometheus/              # Prometheus metrics (15-day retention)
/var/lib/loki/                    # Loki logs (7-day retention)

/var/log/
├── nginx/                        # Web server logs
├── php8.4-fpm.log               # PHP application logs
├── mysql/                        # Database logs
└── syslog                        # System logs
```

### Backup Strategy (Recommended)

| Data | Backup Frequency | Method | Storage |
|------|------------------|--------|---------|
| **WordPress Files** | Daily | rsync/tar | Hetzner Storage Box |
| **MariaDB Database** | Daily | mysqldump | Hetzner Storage Box |
| **wp-content/uploads** | Daily incremental | rsync | Hetzner Storage Box |
| **Configuration** | On change | Git (this repo) | GitHub |
| **Monitoring Data** | Not backed up | Ephemeral (15 days) | - |

---

## 🔒 Security Architecture

### Multi-Layer Security

```
Layer 1: Cloudflare WAF
    ├─ DDoS mitigation
    ├─ Bot protection
    ├─ Rate limiting (global)
    └─ SSL/TLS termination

Layer 2: Network (UFW Firewall)
    ├─ Only ports 22, 80, 443 exposed
    ├─ SSH restricted to admin IP
    └─ Internal services (MySQL, Valkey) localhost-only

Layer 3: Application (Nginx)
    ├─ Rate limiting (login: 5/min, API: 60/min)
    ├─ Security headers (CSP, X-Frame-Options, etc.)
    ├─ Real IP detection (Cloudflare)
    └─ Block sensitive files (.git, wp-config.php)

Layer 4: Application Runtime
    ├─ Fail2ban (ban after failed login attempts)
    ├─ AppArmor (process isolation)
    └─ WordPress plugins (minimal, infrastructure handles most)

Layer 5: Data
    ├─ Database credentials in wp-config.php (mode 0640)
    ├─ SSH key authentication (no passwords)
    └─ Secrets management (Ansible Vault)
```

### Security Headers

Configured via modular nginx configuration:

```nginx
X-Frame-Options: SAMEORIGIN                    # Prevent clickjacking
X-Content-Type-Options: nosniff                # Prevent MIME sniffing
X-XSS-Protection: 1; mode=block                # Browser XSS filter
Content-Security-Policy: ...                   # Restrict resource loading
Referrer-Policy: strict-origin-when-cross-origin
Permissions-Policy: geolocation=(), microphone=(), camera=()
```

---

## ⚡ Performance Optimizations

### Caching Strategy (Multi-Layer)

```
1. Cloudflare Edge Cache (Global CDN)
   ├─ Static assets: 1 year
   ├─ HTML pages: 4 hours (configurable)
   └─ Purge on WordPress update

2. Nginx FastCGI Cache (Server)
   ├─ HTML pages: 60 minutes
   ├─ Bypass: logged-in users, admin, LMS content
   └─ Purge on post update (Nginx Helper plugin)

3. Valkey Object Cache (Application)
   ├─ Database query results
   ├─ WordPress transients
   └─ Session data

4. MariaDB Query Cache
   ├─ Query result cache
   └─ InnoDB buffer pool
```

### Performance Metrics (CX23 x86 Tested)

| Metric | Value | Grade |
|--------|-------|-------|
| **Requests/sec** | 3,114 | A+ |
| **Mean Latency** | 32ms | A+ |
| **95th Percentile** | 57ms | A+ |
| **99th Percentile** | 76ms | A+ |
| **Error Rate** | 0% | A+ |
| **CPU Load** | 0.66 (33% of 2 vCPUs) | A+ |
| **Memory Usage** | 866 MB / 4 GB (23%) | A+ |

**Throughput Capacity**:
- Light load (< 500 req/s): ✅ Current server perfect
- Medium load (500-2,000 req/s): ✅ Current server sufficient
- Heavy load (2,000-5,000 req/s): ⚠️ Upgrade to CX33 or add server
- Very heavy (> 5,000 req/s): ⚠️ Multi-server + load balancer

---

## 📈 Monitoring & Observability

### Grafana Dashboards

| Dashboard | Purpose | Key Metrics |
|-----------|---------|-------------|
| **Node Exporter Full** | System metrics | CPU, RAM, Disk I/O, Network, Load |
| **Nginx** (custom) | Web server | Requests/sec, Response times, Status codes |
| **WordPress** (custom) | Application | PHP-FPM pool, MySQL queries, Cache hit rate |
| **Logs** (Loki) | Log analysis | Errors, Access patterns, Security events |

### Alerting Rules (Recommended)

| Alert | Condition | Severity |
|-------|-----------|----------|
| High CPU | Load > 1.8 for 5 min | Warning |
| High Memory | RAM > 90% for 5 min | Critical |
| Disk Full | Disk > 85% | Warning |
| Service Down | Nginx/PHP/MySQL down | Critical |
| High Error Rate | 5xx errors > 1% | Warning |
| Slow Response | p95 latency > 500ms | Warning |

### Log Retention

- **Nginx logs**: 30 days (rotating daily)
- **PHP-FPM logs**: 30 days
- **MariaDB logs**: 30 days
- **Syslog**: 30 days
- **Prometheus metrics**: 15 days
- **Loki logs**: 7 days

---

## 🖥️ Server Specifications

### Current Architecture Decision

**Test Results** (as of 2024-12-30):
- ✅ **x86 (CX23)**: Tested, 3,114 req/s, €5.04/mo
- ⏳ **ARM (CAX11)**: Pending test

**Production Recommendation**: **CAX11 (ARM64)**
- **Why**: Always available (no stock issues), modern architecture, €0.59/mo cheaper
- **Note**: Pending performance test confirmation

### Detailed Specifications

#### CX23 (x86) - Intel/AMD

| Spec | Value |
|------|-------|
| **CPUs** | 2 vCPUs (AMD EPYC) |
| **RAM** | 4 GB DDR4 |
| **Disk** | 40 GB NVMe SSD |
| **Network** | 20 TB traffic/mo |
| **Price** | €5.04/month |
| **Availability** | Limited stock |

#### CAX11 (ARM64) - Ampere Altra

| Spec | Value |
|------|-------|
| **CPUs** | 2 vCPUs (Ampere Altra) |
| **RAM** | 4 GB DDR4 |
| **Disk** | 40 GB NVMe SSD |
| **Network** | 20 TB traffic/mo |
| **Price** | €4.45/month |
| **Availability** | Always available |

---

## 🚀 Deployment Architecture

### Infrastructure as Code

```
Terraform (Infrastructure)
    ├─ Hetzner Cloud Server (CX23/CAX11)
    ├─ Firewall rules (UFW via cloud-init)
    ├─ SSH keys configuration
    └─ Cloud-init (OS preparation)

Ansible (Configuration Management)
    ├─ Common (base system, users, SSH)
    ├─ MariaDB (database)
    ├─ Valkey (cache)
    ├─ Nginx + PHP-FPM (web server)
    ├─ WordPress (application)
    ├─ Security (firewall, fail2ban, AppArmor)
    └─ Monitoring (Prometheus, Grafana, Loki)
```

### Environments

| Environment | Purpose | Server | Cost |
|-------------|---------|--------|------|
| **Staging** | Testing & validation | CX23/CAX11 | €5/mo |
| **Production** | Live site | CX23/CAX11 | €5/mo |

**Total Infrastructure Cost**: **€10/month** (2 servers)

---

## 📊 Capacity Planning

### Current Capacity (CX23 tested)

**With current configuration** (WordPress + Monitoring):
- **Max throughput**: ~3,100 req/s
- **Concurrent users**: ~600-800
- **Database connections**: 150 (MariaDB max_connections)
- **PHP-FPM workers**: 30 (max_children)

### Scaling Strategy

**Vertical Scaling** (Upgrade server):
```
CX23 (€5/mo) → CX33 (€11/mo)
    ├─ CPUs: 2 → 4
    ├─ RAM: 4 GB → 8 GB
    └─ Expected throughput: 3,100 → 6,000+ req/s
```

**Horizontal Scaling** (Add servers):
```
1 server → 2 servers + Load Balancer
    ├─ Load Balancer: Hetzner LB (€5/mo)
    ├─ 2x CAX11: €9/mo
    ├─ Total: €14/mo
    └─ Expected throughput: 3,100 → 6,000+ req/s
```

**Recommended approach**:
1. Start with 1 server (current)
2. Add Cloudflare (free) - reduces origin load 80-90%
3. If needed, vertical scale to CX33
4. If needed, horizontal scale with load balancer

---

## 🔧 Technology Decisions

### Why This Stack?

| Technology | Alternative Considered | Why Chosen |
|------------|----------------------|------------|
| **Hetzner Cloud** | AWS, DigitalOcean | 50-70% cheaper, European data residency |
| **ARM (CAX11)** | x86 (CX23) | Always available, modern, €0.59/mo cheaper |
| **Debian 13** | Ubuntu 24.04 | Latest packages, stable, predictable |
| **Nginx** | Apache | Better performance, lower memory |
| **PHP 8.4** | PHP 8.2 | Latest features, performance improvements |
| **MariaDB** | MySQL, PostgreSQL | Drop-in MySQL replacement, better performance |
| **Valkey** | Redis | Open source fork, no licensing concerns |
| **Prometheus** | InfluxDB, Datadog | Industry standard, free, powerful |
| **Grafana** | Kibana | Better UX, more integrations |
| **Cloudflare** | Fastly, CloudFront | Free tier, excellent WAF, DDoS protection |

Detailed rationale in [`docs/decisions/`](../decisions/) directory.

---

## 📚 Related Documentation

### Architecture Details
- [Infrastructure](INFRASTRUCTURE.md) - Terraform, networking, Hetzner details
- [Application Stack](APPLICATION_STACK.md) - WordPress, PHP, Nginx, MariaDB
- [Monitoring Stack](MONITORING_STACK.md) - Prometheus, Grafana, Loki
- [Security](SECURITY.md) - Firewall, fail2ban, AppArmor, headers

### Guides
- [Deployment Guide](../guides/DEPLOYMENT.md) - How to deploy from scratch
- [Testing Guide](../guides/TESTING.md) - x86 vs ARM testing
- [Operations Guide](../guides/OPERATIONS.md) - Day-to-day operations
- [Nginx Explained](../guides/NGINX_CONFIGURATION_EXPLAINED.md) - Educational deep-dive

### Reference
- [Hetzner Pricing](../reference/HETZNER_PRICING.md) - Cost calculations
- [Performance Benchmarks](../reference/BENCHMARKS.md) - Test results
- [Ansible Roles](../reference/ANSIBLE_ROLES.md) - Role documentation
- [Variables Reference](../reference/VARIABLES.md) - Terraform/Ansible vars

### Decisions
- [Why ARM over x86](../decisions/WHY_ARM.md)
- [Why Valkey over Redis](../decisions/WHY_VALKEY.md)
- [Why Modular Nginx](../decisions/WHY_MODULAR_NGINX.md)
- [Why All-in-One Server](../decisions/WHY_ALL_IN_ONE.md)

---

## ✅ Production Readiness

**Current Status**: 95% Complete

### Completed ✅
- ✅ Infrastructure as Code (Terraform + Ansible)
- ✅ Full WordPress stack deployment
- ✅ Complete monitoring stack (Prometheus + Grafana + Loki)
- ✅ Security hardening (firewall, fail2ban, AppArmor)
- ✅ Performance optimization (FastCGI cache, object cache, CDN-ready)
- ✅ Modular Nginx configuration
- ✅ x86 architecture testing (3,114 req/s, A+ grade)
- ✅ Documentation (architecture, guides, reference)

### Pending ⏳
- ⏳ ARM architecture testing (CAX11)
- ⏳ Production deployment
- ⏳ Cloudflare DNS configuration
- ⏳ SSL/TLS certificate (Let's Encrypt)
- ⏳ Grafana alerting setup
- ⏳ Backup automation

### Future Enhancements 🔮
- 🔮 Terraform Cloud migration (state management, CI/CD)
- 🔮 Automated backups (Hetzner Storage Box)
- 🔮 Multi-region failover
- 🔮 Blue-green deployments

---

**Last Updated**: 2024-12-31
**Maintained By**: Infrastructure Team
**Questions**: See [TROUBLESHOOTING.md](../../TROUBLESHOOTING.md)
