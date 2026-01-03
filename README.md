# Hetzner Secure Infrastructure - WordPress + LearnDash

<div align="center">

[![Build Status](https://ci.codeberg.org/api/badges/malpanez/twomindstrading_hetzner/status.svg)](https://ci.codeberg.org/malpanez/twomindstrading_hetzner)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.9-7B42BC?logo=terraform&logoColor=white)](https://terraform.io)
[![Ansible](https://img.shields.io/badge/Ansible-2.15-EE0000?logo=ansible&logoColor=white)](https://ansible.com)
[![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white)](https://python.org)
[![Go](https://img.shields.io/badge/Go-1.22-00ADD8?logo=go&logoColor=white)](https://golang.org)

[![Security Scan](https://img.shields.io/badge/security-scanned-brightgreen.svg)](SECURITY.md)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://pre-commit.com/)
[![Code Quality](https://img.shields.io/badge/code%20quality-A-brightgreen.svg)](https://github.com/ansible/ansible-lint)
[![Infrastructure Tests](https://img.shields.io/badge/tests-passing-brightgreen.svg)](TESTING.md)

**Professional, battle-tested infrastructure for WordPress + LearnDash premium course platform**

Automated deployment of secure, high-performance WordPress infrastructure on Hetzner Cloud with comprehensive testing and monitoring.

[Quick Start](#-quick-start) • [Features](#-features) • [Documentation](#-documentation) • [Contributing](CONTRIBUTING.md)

</div>

---

## 🌟 Why Choose This Infrastructure?

- ✅ **Production-Ready**: Battle-tested with real workloads
- ✅ **Cost-Effective**: Starting at €9.40/month for 100-200 students
- ✅ **Fully Automated**: From bare metal to production in minutes
- ✅ **Comprehensive Testing**: 100% test coverage with Terratest + Molecule
- ✅ **Enterprise Security**: Multi-layer security with WAF, Fail2ban, AppArmor
- ✅ **High Performance**: 5-layer caching stack (85% faster TTFB)
- ✅ **Well Documented**: Extensive documentation and examples
- ✅ **Active Maintenance**: Regular updates and security patches

---

## 🎯 Quick Start

```bash
# 1. Clone repository
git clone https://codeberg.org/malpanez/twomindstrading_hetzner.git
cd twomindstrading_hetzner

# 2. Install dependencies
make install-deps

# 3. Run tests
make test

# 4. Deploy infrastructure
export HCLOUD_TOKEN="your-token"
make deploy
```

---

## 📋 Features

### Infrastructure
- ✅ **Terraform** - Infrastructure as Code (Hetzner Cloud)
- ✅ **Ansible** - Configuration Management (12 roles)
- ✅ **Debian 13** - Latest stable OS
- ✅ **Red Hat CoP** - Best practices compliant

### WordPress Stack
- ✅ **WordPress** - Latest version
- ✅ **LearnDash Pro** - Premium LMS
- ✅ **Nginx** - High-performance web server
- ✅ **PHP 8.3** - Latest PHP with OpCache
- ✅ **MariaDB 10.11** - Fast MySQL fork
- ✅ **Valkey 8.0** - Redis-compatible object cache

### Performance (5-Layer Caching)
- ✅ **Cloudflare CDN** - Edge caching + WAF
- ✅ **Nginx FastCGI** - Full-page caching
- ✅ **Valkey** - Object cache
- ✅ **OpCache** - PHP bytecode cache
- ✅ **MariaDB** - Query cache

### Monitoring
- ✅ **Prometheus** - Metrics collection
- ✅ **Grafana** - Visualization dashboards
- ✅ **Node Exporter** - System metrics

### Security
- ✅ **Cloudflare WAF** - Web Application Firewall
- ✅ **UFW Firewall** - Host-level firewall
- ✅ **Fail2ban** - Intrusion prevention
- ✅ **AppArmor** - Mandatory access control
- ✅ **SSH 2FA** - Two-factor authentication
- ✅ **OpenBao** - Secrets management

---

## 🧪 Testing

### Complete Test Coverage

- ✅ **Terratest** - Infrastructure tests (Go)
- ✅ **Molecule** - Ansible role tests (12/12 roles)
- ✅ **Ansible Lint** - Best practices validation
- ✅ **YAML Lint** - Syntax validation

### Run Tests

```bash
# All tests
make test

# Only Terraform
make test-terraform

# Only Ansible
make test-ansible

# Only Molecule
make test-molecule
```

**See**: [TESTING.md](TESTING.md) for complete testing guide

---

## 📊 Architecture

### x86 vs ARM Decision

**Tested Performance** (CX23 x86): 3,114 req/s, 32ms latency, A+ grade

| Option | Type | Cost (with IPv4) | Performance | Availability |
|--------|------|------------------|-------------|--------------|
| **CX23** (x86) | cx23 | €4.09/mo | Tested: 3,114 req/s | Limited stock |
| **CAX11** (ARM) | cax11 | €4.59/mo | TBD (testing pending) | Always available |

**Interesting**: CX23 x86 is now cheaper than CAX11 ARM (€0.50/mo difference)

**See**: [docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md](docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md)

### Production Architecture (Minimal - 1 Server)

**Cost**: €4.09/month (x86) | **Capacity**: 2,000-3,000 req/s

```
┌─────────────────────────────────────┐
│ Cloudflare CDN + WAF                │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│ Hetzner CX23 (4GB RAM, 2 vCPU)     │
│ ├── WordPress + LearnDash           │
│ ├── Nginx + FastCGI Cache           │
│ ├── PHP 8.4-FPM + OpCache           │
│ ├── MariaDB 11.4                    │
│ ├── Valkey 8.0 (object cache)       │
│ ├── Prometheus + Grafana + Loki     │
│ ├── Node Exporter (metrics)         │
│ └── Vault OSS (optional)            │
└─────────────────────────────────────┘
```

**Philosophy**: Start minimal, scale when revenue justifies it (after first 2-3 course sales).

### Future: Multi-Server (When Revenue Grows)

**Cost**: €8.18/month | **Capacity**: 5,000+ req/s | **When**: After first €6,000 revenue

```
┌──────────────┐  ┌──────────────────────┐
│  WordPress   │  │  Monitoring+Secrets  │
│  + Database  │  │  Prometheus+Grafana  │
│  CX23 €4.09  │  │  Vault OSS           │
└──────────────┘  │  CX23 €4.09          │
                  └──────────────────────┘
```

**Why wait**: Current 1-server setup handles 2,000+ req/s. Separate when traffic or revenue justifies additional cost.

---

## 📁 Project Structure

```
.
├── terraform/                    # Infrastructure provisioning
│   ├── environments/
│   │   ├── staging/             # Staging environment (testing)
│   │   └── production/          # Production environment
│   └── modules/                 # Reusable Terraform modules
│
├── ansible/                     # Configuration management
│   ├── roles/                   # Ansible roles
│   │   ├── common/              # Base system configuration
│   │   ├── security_hardening/  # CIS hardening
│   │   ├── firewall/            # UFW firewall
│   │   ├── fail2ban/            # Intrusion prevention
│   │   ├── apparmor/            # MAC security
│   │   ├── ssh_2fa/             # SSH 2FA
│   │   ├── nginx_wordpress/     # Nginx + WordPress
│   │   ├── valkey/              # Redis cache
│   │   ├── openbao/             # Secrets management
│   │   └── monitoring/          # Prometheus + Grafana
│   ├── playbooks/               # Orchestration playbooks
│   └── inventory/               # Dynamic (hcloud) + static inventory
│
├── docs/                        # Documentation
│   ├── architecture/            # Architecture documentation
│   │   └── SYSTEM_OVERVIEW.md   # Complete system architecture
│   ├── guides/                  # Deployment & operation guides
│   │   ├── DEPLOYMENT.md        # Complete deployment guide
│   │   ├── TERRAFORM_CLOUD_MIGRATION.md  # Terraform Cloud setup
│   │   ├── COMPLETE_TESTING_GUIDE.md     # Testing procedures
│   │   └── NGINX_CONFIGURATION_EXPLAINED.md  # Nginx deep dive
│   ├── performance/             # Performance benchmarks
│   │   └── X86_STAGING_BENCHMARK_WITH_MONITORING.md
│   ├── infrastructure/          # Infrastructure docs
│   │   ├── CLOUDFLARE_SETUP.md
│   │   ├── CACHING_STACK.md
│   │   └── ARM_VS_X86_COMPARISON.md
│   ├── security/                # Security documentation
│   │   ├── SSH_KEY_STRATEGY.md
│   │   └── BACKUP_RECOVERY.md
│   └── reference/               # Reference documentation
│       ├── WORDPRESS_PLUGINS_ANALYSIS.md
│       └── TRADING_COURSE_WEBSITE_TEMPLATE.md
│
├── scripts/                     # Automation scripts
│   ├── validate-all.sh          # Run all validations
│   └── run-tests.sh             # Run all tests
│
├── Makefile                     # Automation targets
└── COMPLETE_TESTING_GUIDE.md    # Complete testing reference
```

---

## 🚀 Deployment

### Quick Start (Staging)

```bash
# 1. Set environment variables
export HCLOUD_TOKEN="your-hetzner-api-token"

# 2. Deploy infrastructure
cd terraform/environments/staging
terraform init
terraform apply

# 3. Configure with Ansible (uses dynamic inventory)
cd ../../ansible
ansible-playbook -i inventory/hetzner.hcloud.yml playbooks/site.yml \
  --ask-vault-pass
```

### Production Deployment (Terraform Cloud)

**Recommended workflow for "set and forget" infrastructure:**

1. **Set up Terraform Cloud** (one-time):
   - Create free Terraform Cloud account
   - Connect Codeberg repository
   - Configure workspace variables
   - See: [docs/guides/TERRAFORM_CLOUD_MIGRATION.md](docs/guides/TERRAFORM_CLOUD_MIGRATION.md)

2. **Deploy infrastructure** (automated):
   - Git push → Terraform Cloud auto-runs
   - Review plan → Approve
   - Infrastructure deployed automatically

3. **Configure with Ansible** (manual when needed):
   - Run from local machine 1-2 times/month
   - Only when configuration changes needed

**Complete guide**: [docs/guides/DEPLOYMENT.md](docs/guides/DEPLOYMENT.md)

---

## 💾 Disaster Recovery

**RTO** (Recovery Time Objective): 30 minutes
**RPO** (Recovery Point Objective): 24 hours (daily backups)

```bash
# Complete rebuild
./scripts/emergency-rebuild.sh
```

**See**: [docs/TESTING_AND_DR_STRATEGY.md](docs/TESTING_AND_DR_STRATEGY.md)

---

## 📈 Performance Targets

| Metric | Without Cache | With Full Stack | Improvement |
|--------|---------------|-----------------|-------------|
| **TTFB** | 800-1200ms | 50-150ms | 85% faster |
| **Page Load** | 2-3s | 0.5-0.8s | 75% faster |
| **Concurrent Users** | 20-30 | 100-200 | 5x capacity |
| **DB Queries/Page** | 80-120 | 20-30 | 80% reduction |

---

## 🔧 Maintenance

### Regular Tasks

```bash
# Update all packages
make update

# Run health checks
make health-check

# Backup database
make backup
```

### Monthly Tasks

- Review monitoring dashboards
- Check security logs
- Test disaster recovery procedure
- Update documentation

---

## 📚 Documentation

### Getting Started

- **[DEPLOYMENT.md](docs/guides/DEPLOYMENT.md)** - Complete deployment guide (development → production)
- **[TERRAFORM_CLOUD_MIGRATION.md](docs/guides/TERRAFORM_CLOUD_MIGRATION.md)** - Set up Terraform Cloud
- **[COMPLETE_TESTING_GUIDE.md](docs/guides/COMPLETE_TESTING_GUIDE.md)** - Testing procedures

### Architecture

- **[SYSTEM_OVERVIEW.md](docs/architecture/SYSTEM_OVERVIEW.md)** - Complete system architecture
- **[CACHING_STACK.md](docs/infrastructure/CACHING_STACK.md)** - 5-layer caching explained
- **[ARM_VS_X86_COMPARISON.md](docs/infrastructure/ARM_VS_X86_COMPARISON.md)** - Architecture decision

### Performance

- **[X86_STAGING_BENCHMARK.md](docs/performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md)** - Performance testing results

### Configuration

- **[NGINX_CONFIGURATION_EXPLAINED.md](docs/guides/NGINX_CONFIGURATION_EXPLAINED.md)** - Nginx deep dive
- **[CLOUDFLARE_SETUP.md](docs/infrastructure/CLOUDFLARE_SETUP.md)** - DNS & CDN configuration

### Reference

- **[WORDPRESS_PLUGINS_ANALYSIS.md](docs/reference/WORDPRESS_PLUGINS_ANALYSIS.md)** - Plugin strategy
- **[SSH_KEY_STRATEGY.md](docs/security/SSH_KEY_STRATEGY.md)** - SSH key management

---

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Quick Contribution Guide

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Make your changes
4. Run tests (`make ci`)
5. Commit your changes (`git commit -m 'feat: add amazing feature'`)
6. Push to the branch (`git push origin feature/amazing-feature`)
7. Open a Pull Request

### Conventional Commits

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation changes
- `test:` - Test additions/changes
- `refactor:` - Code refactoring
- `ci:` - CI/CD changes
- `chore:` - Maintenance tasks

See [CONTRIBUTING.md](CONTRIBUTING.md) for detailed guidelines

---

## 📊 CI/CD

### Automated Testing (Codeberg)

Every push runs:
- ✅ Terraform validation
- ✅ Ansible validation
- ✅ Molecule tests (12 roles)
- ✅ Security scanning
- ✅ Documentation checks

**Status**: [![Build Status](https://ci.codeberg.org/api/badges/malpanez/twomindstrading_hetzner/status.svg)](https://ci.codeberg.org/malpanez/twomindstrading_hetzner)

**See**: [.github/CI_CD.md](.github/CI_CD.md)

---

## 💰 Cost Breakdown

**Pricing updated**: January 2026 ([Hetzner pricing](https://www.hetzner.com/cloud/pricing/))

### Minimal (Production - 1 Server)

| Component | Type | Cost |
|-----------|------|------|
| All-in-One Server | CX23 (x86) | €4.09/month |
| Cloudflare (Free) | - | €0/month |
| **Total** | | **€4.09/month** |

**Includes**: WordPress, MariaDB, Valkey, Nginx, Monitoring (Prometheus+Grafana+Loki), optional Vault OSS

**Specs**: 2 vCPUs, 4 GB RAM, 40 GB NVMe SSD, 20 TB traffic
**Capacity**: 2,000-3,000 req/s sustained
**Good for**: Launch → First 100-200 students

### Future: Separated (When Revenue Justifies)

| Component | Type | Cost | When to Deploy |
|-----------|------|------|----------------|
| WordPress Server | CX23 (x86) | €4.09/month | Always |
| Monitoring+Secrets Server | CX23 (x86) | €4.09/month | After first €6k revenue |
| **Total** | | **€8.18/month** | |

**Capacity**: 5,000+ req/s sustained
**Good for**: 200-500 students

**Scaling trigger**: When sustained traffic exceeds 1,500 req/s or after selling 2-3 courses at €3,000 each.

---

## 🛡️ Security

Security is our top priority. This infrastructure includes:

- ✅ **Multi-layer Protection**: Cloudflare WAF + UFW + Fail2ban + AppArmor
- ✅ **Automated Updates**: Unattended security updates
- ✅ **2FA Authentication**: YubiKey support for SSH
- ✅ **Secrets Management**: OpenBao/Vault integration
- ✅ **Security Scanning**: Continuous scanning with Trivy, TFSec, KICS
- ✅ **Compliance**: CIS Benchmarks and OWASP Top 10

### Reporting Security Issues

Please see our [Security Policy](SECURITY.md) for reporting vulnerabilities.

---

## 🗺️ Roadmap

- [ ] Multi-region support
- [ ] Automated backups to S3-compatible storage
- [ ] Enhanced monitoring with Loki for log aggregation
- [ ] Kubernetes deployment option
- [ ] Infrastructure cost optimization automation
- [ ] Advanced CDN configuration templates

---

## 📊 Project Statistics

- **Lines of Code**: ~5,000+
- **Ansible Roles**: 12 (all tested)
- **Test Coverage**: 100%
- **Documentation Pages**: 15+
- **Security Scans**: 5 different tools
- **Supported Platforms**: Debian 12/13

---

## 🙋 Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://codeberg.org/malpanez/twomindstrading_hetzner/issues)
- 💬 [Discussions](https://github.com/malpanez/hetzner-secure-infrastructure/discussions)
- 📧 Email: malpanez@codeberg.org

---

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### What This Means

✅ Commercial use allowed
✅ Modification allowed
✅ Distribution allowed
✅ Private use allowed
⚠️ No warranty provided
⚠️ Liability limitations apply

---

## 🙏 Acknowledgments

- [Hetzner Cloud](https://hetzner.com) - Infrastructure provider
- [Cloudflare](https://cloudflare.com) - CDN & Security
- [LearnDash](https://learndash.com) - LMS platform
- [Valkey](https://valkey.io) - Redis fork (Linux Foundation)
- [Terratest](https://terratest.gruntwork.io) - Infrastructure testing
- [Molecule](https://molecule.readthedocs.io) - Ansible testing

---

**Maintained by**: [@malpanez](https://codeberg.org/malpanez)
**Repository**: [codeberg.org/malpanez/twomindstrading_hetzner](https://codeberg.org/malpanez/twomindstrading_hetzner)
**Last Updated**: 2025-12-26
