# Documentation Reorganization Plan

> **Date**: December 31, 2024
> **Purpose**: Organize root-level documentation for better maintainability

---

## 📋 Current State Analysis

### Root Directory (20 .md files)
Too many documentation files in root - needs organization.

---

## 🎯 Reorganization Plan

### Keep in Root (Core docs - 8 files)
These are the most frequently accessed:

1. ✅ **README.md** - Project overview and quick start
2. ✅ **PRODUCTION_READINESS_PLAN.md** - Current status and roadmap
3. ✅ **TESTING_x86_vs_ARM.md** - Current testing guide
4. ✅ **CHANGELOG.md** - Version history
5. ✅ **CONTRIBUTING.md** - How to contribute
6. ✅ **SECURITY.md** - Security policy
7. ✅ **DEPLOYMENT_GUIDE.md** - Main deployment guide
8. ✅ **TROUBLESHOOTING.md** - Quick troubleshooting reference

### Move to `.archive/` (Completed/Outdated - 6 files)

**`.archive/completed-plans-2024-12/`**:
- ✅ MODULARIZATION_PLAN.md (archived, marked as complete)
- ✅ SESSION_SUMMARY.md (archived, marked as complete)
- TESTING.md (outdated, replaced by TESTING_x86_vs_ARM.md)
- TERRAFORM_VALIDATION.md (one-time validation, archived)
- CHANGELOG_BEST_PRACTICES.md (historical, archived)
- SECURITY_FIXES.md (historical, archived)

### Move to `docs/guides/` (How-to guides - 4 files)

- DEPLOYMENT_CHECKLIST.md → docs/guides/DEPLOYMENT_CHECKLIST.md
- POST_DEPLOYMENT.md → docs/guides/POST_DEPLOYMENT.md
- GUIA_RAPIDA.md → docs/guides/QUICK_START_ES.md (rename for clarity)
- TERRAFORM_ANSIBLE_INTEGRATION.md → docs/guides/TERRAFORM_ANSIBLE_INTEGRATION.md

### Move to `docs/reference/` (Reference docs - 2 files)

- MODULARIZATION_SUMMARY.md → docs/reference/MODULARIZATION_SUMMARY.md
- ROLES_SUMMARY.md → docs/reference/ROLES_SUMMARY.md

---

## 📁 Final Structure

```
/
├── README.md                           # Project overview
├── PRODUCTION_READINESS_PLAN.md        # Current status (master doc)
├── TESTING_x86_vs_ARM.md               # Current testing workflow
├── DEPLOYMENT_GUIDE.md                 # Main deployment guide
├── TROUBLESHOOTING.md                  # Quick troubleshooting
├── CHANGELOG.md                        # Version history
├── CONTRIBUTING.md                     # Contribution guide
├── SECURITY.md                         # Security policy
│
├── docs/
│   ├── guides/                         # How-to guides
│   │   ├── DEPLOYMENT_CHECKLIST.md
│   │   ├── POST_DEPLOYMENT.md
│   │   ├── QUICK_START_ES.md
│   │   ├── TERRAFORM_ANSIBLE_INTEGRATION.md
│   │   ├── ANSIBLE_BEST_PRACTICES.md
│   │   ├── CODEBERG_CICD.md
│   │   ├── GRAFANA_ALERTS_TROUBLESHOOTING.md
│   │   ├── INVENTORY_RESTRUCTURE.md
│   │   ├── LOGGING.md
│   │   ├── STAGING_DEPLOYMENT.md
│   │   ├── TERRAFORM_ANSIBLE_WORKFLOW.md
│   │   ├── TESTING_AND_DR_STRATEGY.md
│   │   └── TROUBLESHOOTING.md
│   │
│   ├── reference/                      # Reference documentation
│   │   ├── MODULARIZATION_SUMMARY.md
│   │   ├── ROLES_SUMMARY.md
│   │   ├── TRADING_COURSE_WEBSITE_TEMPLATE.md
│   │   └── WORDPRESS_PLUGINS_ANALYSIS.md
│   │
│   ├── infrastructure/                 # Infrastructure docs
│   │   ├── ARCHITECTURE_DECISIONS.md
│   │   ├── ARCHITECTURE_SUMMARY.md
│   │   ├── ARM_VS_X86_COMPARISON.md
│   │   ├── CACHING_STACK.md
│   │   ├── CLOUDFLARE_SETUP.md
│   │   ├── HETZNER_API_TOKEN.md
│   │   ├── MONITORING_ARCHITECTURE.md
│   │   ├── OPENBAO_DEPLOYMENT.md
│   │   ├── WHY_NOT_VARNISH.md
│   │   ├── WORDPRESS-STACK.md
│   │   └── WORDPRESS-STACK-MERMAID.md
│   │
│   ├── security/                       # Security docs
│   │   ├── APPARMOR.md
│   │   ├── BACKUP_RECOVERY.md
│   │   ├── SSH-2FA.md
│   │   ├── SSH_KEY_STRATEGY.md
│   │   └── YUBIKEY_SETUP.md
│   │
│   └── performance/                    # Performance benchmarks
│       ├── BENCHMARK_RESULTS_x86_CX23.md
│       └── X86_STAGING_BENCHMARK_WITH_MONITORING.md
│
└── .archive/
    └── completed-plans-2024-12/        # Historical planning docs
        ├── README.md
        ├── MODULARIZATION_PLAN.md
        ├── SESSION_SUMMARY.md
        ├── TESTING.md (old version)
        ├── TERRAFORM_VALIDATION.md
        ├── CHANGELOG_BEST_PRACTICES.md
        └── SECURITY_FIXES.md
```

---

## ✅ Actions Required

### 1. Archive Completed Plans
```bash
mv TESTING.md .archive/completed-plans-2024-12/
mv TERRAFORM_VALIDATION.md .archive/completed-plans-2024-12/
mv CHANGELOG_BEST_PRACTICES.md .archive/completed-plans-2024-12/
mv SECURITY_FIXES.md .archive/completed-plans-2024-12/
```

### 2. Move Guides
```bash
mv DEPLOYMENT_CHECKLIST.md docs/guides/
mv POST_DEPLOYMENT.md docs/guides/
mv GUIA_RAPIDA.md docs/guides/QUICK_START_ES.md
mv TERRAFORM_ANSIBLE_INTEGRATION.md docs/guides/
```

### 3. Move Reference Docs
```bash
mv MODULARIZATION_SUMMARY.md docs/reference/
mv ROLES_SUMMARY.md docs/reference/
```

### 4. Update Cross-References
Update links in remaining files to reflect new paths.

### 5. Update README.md
Add clear documentation map pointing to new locations.

---

## 🎯 Benefits

1. **Cleaner root directory** - Only 8 essential files
2. **Logical organization** - Guides, references, and archives separated
3. **Easier navigation** - Users know where to find specific info
4. **Better maintainability** - Clear what's active vs archived
5. **Preserved history** - Archive keeps historical context

---

**Status**: Plan created, ready for implementation
