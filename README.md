# Hetzner Secure Infrastructure - Production WordPress (ARM64)

<div align="center">

[![Build Status](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/ci.yml/badge.svg)](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.10-7B42BC?logo=terraform&logoColor=white)](https://terraform.io)
[![Ansible](https://img.shields.io/badge/Ansible-2.16-EE0000?logo=ansible&logoColor=white)](https://ansible.com)
[![ARM64](https://img.shields.io/badge/ARM64-Optimized-success)](docs/performance/ARM64_vs_X86_COMPARISON.md)

[![Security Scan](https://img.shields.io/badge/security-scanned-brightgreen.svg)](SECURITY.md)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit&logoColor=white)](https://pre-commit.com/)
[![Infrastructure Tests](https://img.shields.io/badge/tests-10%2F10%20passing-brightgreen.svg)](docs/guides/COMPLETE_TESTING_GUIDE.md)

**Production-ready WordPress infrastructure optimized for ARM64 (2.68x faster than x86)**

Fully automated deployment of secure, high-performance WordPress on Hetzner Cloud ARM64 servers with enterprise-grade monitoring and security.

[Quick Start](#-quick-start) • [Features](#-features) • [Documentation](#-documentation) • [Contributing](CONTRIBUTING.md)

</div>

---

## 🌟 Why This Infrastructure?

- ✅ **ARM64 Optimized**: 2.68x faster than x86 (benchmarked)
- ✅ **Cost-Effective**: €4.66/month (CAX11 ARM64 with IPv4) - Updated Jan 2026
- ✅ **Fully Automated**: Terraform + Ansible with workspaces + dynamic inventory
- ✅ **100% Test Coverage**: 10 Molecule tests + Terratest + CI/CD
- ✅ **Enterprise Security**: WAF, Fail2ban, AppArmor, SSH 2FA
- ✅ **High Performance**: Nginx 1.28.1 + PHP 8.4 + Valkey cache
- ✅ **Complete Monitoring**: Prometheus + Grafana + Loki (logs)
- ✅ **Production-Ready**: Clean code, comprehensive docs

---

## 🎯 Quick Start

```bash
# 1. Clone repository
git clone https://github.com/malpanez/hetzner-secure-infrastructure.git
cd hetzner-secure-infrastructure

# 2. Deploy with Terraform (ARM64)
cd terraform
export HCLOUD_TOKEN="your_token"
terraform workspace select production  # or: staging, default
terraform apply -var-file=production.tfvars

# 3. Configure with Ansible
cd ../ansible
export HCLOUD_TOKEN="your_token"
ansible-playbook playbooks/site.yml --ask-vault-pass

# 4. Complete WordPress setup
# https://YOUR_IP/wp-admin/install.php
```

**Full guide**: [docs/guides/DEPLOYMENT_GUIDE.md](docs/guides/DEPLOYMENT_GUIDE.md)

---

## 📋 Features

### Infrastructure

- ✅ **Hetzner Cloud ARM64** - CAX11 (2 vCPU, 4GB RAM)
- ✅ **Terraform** - Infrastructure as Code with workspaces
- ✅ **Ansible** - 10 production roles + dynamic inventory
- ✅ **Debian 13 (Trixie)** - Latest stable with ARM64 support

### WordPress Stack

- ✅ **WordPress** - Latest version
- ✅ **Nginx 1.28.1** - Official repo + FastCGI cache
- ✅ **PHP 8.4** - Latest with OpCache
- ✅ **MariaDB 10.11** - Production database
- ✅ **Valkey 8.0** - Redis-compatible cache

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

- ✅ **Cloudflare WAF** - Edge protection + DDoS
- ✅ **UFW Firewall** - Host-level rules
- ✅ **Fail2ban** - Auto-ban malicious IPs
- ✅ **AppArmor** - Application sandboxing
- ✅ **SSH Hardening** - Key-only + optional 2FA
- ✅ **Kernel Hardening** - sysctl security settings

---

## 🧪 Testing

### Complete Test Coverage

- ✅ **Molecule** - 10/10 Ansible roles tested with Docker
- ✅ **Testinfra** - 912 lines of infrastructure tests
- ✅ **GitHub Actions CI** - Automated validation on every push
- ✅ **Ansible Lint** - Best practices validation
- ✅ **Security Scans** - Trivy, Checkov, GitLeaks, ShellCheck

### Run Tests Locally

```bash
# Test specific role with Molecule
cd ansible/roles/nginx_wordpress
molecule test

# Validate Ansible syntax
cd ansible
ansible-playbook playbooks/site.yml --syntax-check

# Run all CI checks
cd ..
.github/workflows/ci.yml  # See workflow for commands
```

**See**: [docs/guides/COMPLETE_TESTING_GUIDE.md](docs/guides/COMPLETE_TESTING_GUIDE.md)

---

## 📊 Architecture

### x86 vs ARM Decision

**Tested Performance**: Both architectures tested head-to-head

| Option | Type | Cost (with IPv4) | Performance | Availability |
|--------|------|------------------|-------------|--------------|
| **CAX11** (ARM) | cax11 | €4.66/mo | **8,339 req/s, 12ms latency** | ✅ Always available |
| **CX23** (x86) | cx23 | €3.68/mo | 3,114 req/s, 32ms latency | ⚠️ Limited stock |

**Winner**: ARM64 (CAX11)

- **2.68x faster** throughput (8,339 vs 3,114 req/s)
- **2.7x lower** latency (12ms vs 32ms)
- **19% lower** memory usage
- Always available (no stock issues)

**See**: [ARM64 vs x86 Comparison](docs/performance/ARM64_vs_X86_COMPARISON.md)

### Production Architecture (Minimal - 1 Server)

**Cost**: €4.66/month (ARM64) | **Capacity**: 8,000+ req/s

```
┌─────────────────────────────────────┐
│ Cloudflare CDN + WAF                │
└─────────────────────────────────────┘
                 ↓
┌─────────────────────────────────────┐
│ Hetzner CAX11 ARM64                 │
│ (Ampere Altra, 4GB RAM, 2 vCPU)    │
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

**Cost**: €9.32/month | **Capacity**: 16,000+ req/s | **When**: After first €6,000 revenue

```
┌──────────────┐  ┌──────────────────────┐
│  WordPress   │  │  Monitoring+Secrets  │
│  + Database  │  │  Prometheus+Grafana  │
│  CAX11 €4.66 │  │  Vault OSS           │
│  (ARM64)     │  │  CAX11 €4.66         │
└──────────────┘  │  (ARM64)             │
                  └──────────────────────┘
```

**Why wait**: Current 1-server ARM64 setup handles 8,000+ req/s. Separate when traffic or revenue justifies additional cost.

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

**Status**: [![Build Status](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/ci.yml/badge.svg)](https://github.com/malpanez/hetzner-secure-infrastructure/actions/workflows/ci.yml)

**See**: [.github/CI_CD.md](.github/CI_CD.md)

---

## 💰 Cost Breakdown

**Pricing updated**: January 2026 ([Hetzner pricing](https://www.hetzner.com/cloud/pricing/))

### Minimal (Production - 1 Server)

| Component | Type | Monthly | **Annual** |
|-----------|------|---------|------------|
| All-in-One Server | CAX11 (ARM64) | €4.66 | **€55.92** |
| Cloudflare (Free) | - | €0 | **€0** |
| **Total** | | **€4.66/month** | **€55.92/year** |

**Includes**: WordPress, MariaDB, Valkey, Nginx, Monitoring (Prometheus+Grafana+Loki), optional Vault OSS

**Specs**: 2 vCPU Ampere Altra, 4 GB RAM, 40 GB NVMe SSD, 20 TB traffic
**Capacity**: 8,000+ req/s sustained
**Good for**: Launch → First 500-1,000 students

### Future: Separated (When Revenue Justifies)

| Component | Type | Monthly | **Annual** | When to Deploy |
|-----------|------|---------|------------|----------------|
| WordPress Server | CAX11 (ARM64) | €4.66 | €55.92 | Always |
| Monitoring+Secrets Server | CAX11 (ARM64) | €4.66 | €55.92 | After first €6k revenue |
| **Total** | | **€9.32/month** | **€111.84/year** | |

**Capacity**: 16,000+ req/s sustained
**Good for**: 1,000-2,000 students

**Scaling trigger**: When sustained traffic exceeds 6,000 req/s or after selling 2-3 courses at €3,000 each.

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

### Completed ✅

- [x] ARM64 architecture support (CAX11)
- [x] Cloudflare integration with DNS management
- [x] Comprehensive monitoring (Prometheus + Grafana)
- [x] GitHub Actions CI/CD pipelines
- [x] Terraform + Ansible automation
- [x] SSH 2FA with break-glass account

### In Progress 🚧

- [ ] Production deployment and validation
- [ ] WordPress SSL certificate automation
- [ ] OpenBao secrets rotation

### Future 🔮

- [ ] Multi-region failover support
- [ ] Automated backups to S3-compatible storage (R2)
- [ ] Kubernetes deployment option (k3s)
- [ ] Infrastructure cost optimization automation
- [ ] Advanced CDN configuration templates

---

## 📊 Project Statistics

- **Lines of Code**: 17,584 (Terraform + Ansible + Scripts)
- **Ansible Roles**: 11 custom roles + 1 external (geerlingguy.mysql)
- **Terraform Modules**: 2 (hetzner-server, cloudflare-config)
- **GitHub Actions Workflows**: 5 (CI, Terraform, Ansible, Security, Markdown)
- **Documentation Pages**: 44 markdown files
- **Test Coverage**: Terraform validation + Ansible lint + syntax checks
- **Security Scans**: Trivy, TFLint, ansible-lint, yamllint, markdownlint
- **Supported Architectures**: x86_64, ARM64 (aarch64)
- **Supported Platforms**: Debian 12/13

---

## 🙋 Support

- 📖 [Documentation](docs/)
- 🐛 [Issue Tracker](https://codeberg.org/malpanez/twomindstrading_hetzner/issues)
- 💬 [Discussions](https://github.com/malpanez/hetzner-secure-infrastructure/discussions)
- 📧 Email: <malpanez@codeberg.org>

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
