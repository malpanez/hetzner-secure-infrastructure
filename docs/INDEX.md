# Documentation Index

**Last Updated**: $(date +%Y-%m-%d)

Quick access to all project documentation.

---

## 🚀 Quick Start

### New Users

1. [README](../README.md) - Project overview
2. [Quick Start (Spanish)](guides/QUICK_START_ES.md) - Guía rápida en español
3. [Go Live Today Checklist](../GO_LIVE_TODAY_CHECKLIST.md) - Production deployment

### Existing Users

- [Deployment Guide](guides/DEPLOYMENT.md) - Standard deployment process
- [Troubleshooting](guides/TROUBLESHOOTING.md) - Common issues and solutions

---

## 📚 Documentation Categories

### Architecture & Infrastructure

- [System Overview](architecture/SYSTEM_OVERVIEW.md) - High-level architecture
- [Architecture Decisions](infrastructure/ARCHITECTURE_DECISIONS.md) - Why we chose these technologies
- [Architecture Summary](infrastructure/ARCHITECTURE_SUMMARY.md) - Technical architecture details
- [WordPress Stack](infrastructure/WORDPRESS-STACK.md) - Complete WordPress infrastructure
- [Monitoring Architecture](infrastructure/MONITORING_ARCHITECTURE.md) - Prometheus + Grafana + Loki
- [Caching Stack](infrastructure/CACHING_STACK.md) - Valkey + CDN setup
- [OpenBao Deployment](infrastructure/OPENBAO_DEPLOYMENT.md) - Secrets management
- [Cloudflare Setup](infrastructure/CLOUDFLARE_SETUP.md) - CDN + DNS + WAF
- [Nginx Improvements](infrastructure/NGINX_IMPROVEMENTS.md) - Performance optimizations
- [Nginx Modular Implementation](infrastructure/NGINX_MODULAR_IMPLEMENTATION.md) - Modular config approach
- [Why Not Varnish](infrastructure/WHY_NOT_VARNISH.md) - Technology decisions

### Deployment & Operations

- [Deployment Automation Setup](guides/DEPLOYMENT_AUTOMATION_SETUP.md) - **Complete production guide**
- [Deployment Guide](guides/DEPLOYMENT_GUIDE.md) - Standard deployment
- [Production Readiness Plan](guides/PRODUCTION_READINESS_PLAN.md) - Pre-launch checklist
- [Testing & DR Strategy](guides/TESTING_AND_DR_STRATEGY.md) - Disaster recovery
- [Complete Testing Guide](guides/COMPLETE_TESTING_GUIDE.md) - QA procedures
- [Logging](guides/LOGGING.md) - Centralized logging with Loki
- [Grafana Alerts Troubleshooting](guides/GRAFANA_ALERTS_TROUBLESHOOTING.md) - Alert management

### Security

- [SSH 2FA Initial Setup](security/SSH_2FA_INITIAL_SETUP.md) - **How to setup 2FA** (QR code capture)
- [SSH 2FA Break-Glass](security/SSH_2FA_BREAK_GLASS.md) - Emergency access procedures
- [SSH Key Strategy](security/SSH_KEY_STRATEGY.md) - Key management
- [AppArmor](security/APPARMOR.md) - Application sandboxing
- [Backup & Recovery](security/BACKUP_RECOVERY.md) - Backup strategy
- [YubiKey Setup](security/YUBIKEY_SETUP.md) - Hardware token authentication
- [Security Policy](../SECURITY.md) - Vulnerability reporting

### Performance

- [ARM64 vs x86 Comparison](performance/ARM64_vs_X86_COMPARISON.md) - **Performance benchmarks**
- [ARM64 Staging Benchmark](performance/ARM64_STAGING_BENCHMARK.md) - CAX11 test results
- [x86 Staging Benchmark](performance/X86_STAGING_BENCHMARK_WITH_MONITORING.md) - CX23 test results
- [Testing x86 vs ARM](performance/TESTING_x86_vs_ARM.md) - Methodology

### Configuration

- [Nginx Configuration Explained](guides/NGINX_CONFIGURATION_EXPLAINED.md) - Deep dive into Nginx setup
- [Ansible Best Practices](guides/ANSIBLE_BEST_PRACTICES.md) - Coding standards
- [Terraform Cloud Migration](guides/TERRAFORM_CLOUD_MIGRATION.md) - Terraform setup

### Reference

- [Trading Course Website Template](reference/TRADING_COURSE_WEBSITE_TEMPLATE.md) - Site structure
- [WordPress Plugins Analysis](reference/WORDPRESS_PLUGINS_ANALYSIS.md) - Plugin security review
- [Hetzner API Token](infrastructure/HETZNER_API_TOKEN.md) - API setup

---

## 🎯 By Task

### I want to

**Deploy to production today**
→ [Go Live Today Checklist](../GO_LIVE_TODAY_CHECKLIST.md)

**Setup automated deployments (no 2FA prompt)**
→ [Deployment Automation Setup](guides/DEPLOYMENT_AUTOMATION_SETUP.md)

**Capture 2FA QR code for my phone**
→ [SSH 2FA Initial Setup](security/SSH_2FA_INITIAL_SETUP.md)

**Migrate DNS to Cloudflare**
→ [Deployment Automation Setup - Section 3](guides/DEPLOYMENT_AUTOMATION_SETUP.md#cloudflare--godaddy-dns-setup)

**Setup OpenBao automatic rotation**
→ [Deployment Automation Setup - Section 2](guides/DEPLOYMENT_AUTOMATION_SETUP.md#openbao-secret-rotation)

**Understand ARM64 vs x86 performance**
→ [ARM64 vs x86 Comparison](performance/ARM64_vs_X86_COMPARISON.md)

**Fix a problem**
→ [Troubleshooting](guides/TROUBLESHOOTING.md)

**Review security configuration**
→ [SSH 2FA Break-Glass](security/SSH_2FA_BREAK_GLASS.md)

**Learn about the architecture**
→ [System Overview](architecture/SYSTEM_OVERVIEW.md)

---

## 📋 Checklists

- [✅ Go Live Today](../GO_LIVE_TODAY_CHECKLIST.md) - Production deployment
- [✅ Production Readiness](guides/PRODUCTION_READINESS_PLAN.md) - Pre-launch review
- [✅ Testing Checklist](guides/COMPLETE_TESTING_GUIDE.md) - QA validation

---

## 🗂️ Archived Documentation

Older documentation is in [.archive/](../.archive/) folder.

---

**Need help?** Check [Troubleshooting](guides/TROUBLESHOOTING.md) or open an issue.
