# CI/CD Pipeline Documentation

## 🎯 Overview

This repository uses **automated testing** on every commit to ensure infrastructure quality.

**CI Platforms**:

- ✅ **Woodpecker CI** (Codeberg native) - Primary
- ✅ **GitHub Actions** (if mirrored to GitHub) - Secondary

---

## 🔄 CI Pipeline Stages

### Stage 1: Validation (Fast - 2 minutes)

```
┌─────────────────────────────────────┐
│ Terraform Validation                │
│ - Format check (terraform fmt)      │
│ - Syntax validation                 │
│ - Init test (no backend)            │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Ansible Validation                  │
│ - Syntax check (--syntax-check)     │
│ - Ansible-lint                      │
│ - YAML lint                         │
└─────────────────────────────────────┘
```

### Stage 2: Testing (Medium - 15 minutes)

```
┌─────────────────────────────────────┐
│ Molecule Tests (Ansible Roles)      │
│ - Test all 12 roles in parallel     │
│ - Docker containers                 │
│ - Idempotence checks                │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ Security Scanning                   │
│ - Trivy vulnerability scan          │
│ - Strict ansible-lint              │
└─────────────────────────────────────┘
```

### Stage 3: Documentation (Fast - 1 minute)

```
┌─────────────────────────────────────┐
│ Documentation Checks                │
│ - Broken links detection            │
│ - Required files verification       │
└─────────────────────────────────────┘
```

---

## 🚀 Triggers

### Automatic (on every push to main)

- ✅ Terraform validation
- ✅ Ansible validation
- ✅ Molecule tests
- ✅ Security scans

### Pull Request

- ✅ All validation stages
- ✅ All test stages

- 🔒 Blocks merge if tests fail

### Manual

```bash
# Run locally before pushing
make ci
```

---

## 📊 Test Matrix

### Ansible Roles (Parallel Testing)

| Role | Test Time | Docker Image |
|------|-----------|--------------|
| nginx-wordpress | ~2 min | debian:13 |
| valkey | ~2 min | debian:13 |
| mariadb | ~2 min | debian:13 |
| prometheus | ~2 min | debian:13 |
| grafana | ~2 min | debian:13 |
| fail2ban | ~1 min | debian:13 |
| firewall | ~1 min | debian:13 |
| apparmor | ~1 min | debian:13 |
| **Total** | **~15 min** | *Parallel* |

---

## 🔧 Woodpecker CI (Codeberg)

### Setup

1. **Enable Woodpecker CI**:

   ```
   Codeberg → Repository Settings → Integrations → Woodpecker CI
   ```

2. **Grant Permissions**:
   - Repository access
   - Docker socket access (for Molecule)

3. **Pipeline File**: `.woodpecker/test.yml`

### Status Badge

```markdown
[![Build Status](https://ci.codeberg.org/api/badges/malpanez/twomindstrading_hetzner/status.svg)](https://ci.codeberg.org/malpanez/twomindstrading_hetzner)
```

---

## 🔧 GitHub Actions (Optional Mirror)

### Setup

1. **Mirror to GitHub**:

   ```bash
   git remote add github https://github.com/yourusername/hetzner-infrastructure.git
   git push github main
   ```

2. **GitHub Actions** auto-enabled (`.github/workflows/ci.yml`)

3. **Required Secrets**: None for validation/testing

### Status Badge

```markdown
[![CI](https://github.com/yourusername/hetzner-infrastructure/actions/workflows/ci.yml/badge.svg)](https://github.com/yourusername/hetzner-infrastructure/actions/workflows/ci.yml)
```

---

## ⚙️ Local Testing

### Before Committing

```bash
# Quick validation (2 minutes)
make validate

# Full local tests (no cloud resources)
make test-molecule
```

### Complete CI Simulation

```bash
# Run exactly what CI runs
make ci
```

---

## 🐛 Troubleshooting

### Woodpecker CI Fails

**Problem**: Docker permission denied

```yaml
# Add to .woodpecker/test.yml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock
```

**Problem**: Ansible collection not found

```yaml
# Add installation step
- ansible-galaxy collection install -r requirements.yml
```

### GitHub Actions Fails

**Problem**: Molecule test timeout

```yaml
# Increase timeout
timeout-minutes: 30
```

**Problem**: Docker not available

```yaml
# Use services
services:
  docker:
    image: docker:dind
```

---

## 📈 Pipeline Optimization

### Current Performance

| Stage | Duration | Can Parallelize |
|-------|----------|-----------------|
| Validation | 2 min | No |
| Molecule Tests | 15 min | **Yes** ✅ |
| Security Scan | 2 min | No |
| Docs Check | 1 min | No |
| **Total** | **~20 min** | - |

### Optimization Strategies

1. **Parallel Molecule Tests** (implemented)
   - 12 roles tested simultaneously
   - Reduces 24+ min → 15 min

2. **Cache Dependencies**
   - Cache Terraform providers
   - Cache Python packages
   - Cache Docker images

3. **Skip on Docs-Only Changes**

   ```yaml
   when:
     - path:
         exclude:

           - '**.md'
           - 'docs/**'
   ```

---

## 🔐 Security Considerations

### Secrets in CI

**Never commit**:

- ❌ Hetzner API tokens
- ❌ Ansible Vault passwords
- ❌ SSH private keys

**Safe for CI**:

- ✅ Validation (no secrets needed)
- ✅ Molecule tests (local Docker)
- ✅ Syntax checks

### Production Deploys

**NOT in CI** (manual only):

- Terraform apply (creates real servers)
- Ansible deploy (configures production)

**Reason**: Requires secrets and can incur costs

---

## 📊 Success Criteria

### All Checks Must Pass

- ✅ Terraform format valid
- ✅ Terraform syntax valid

- ✅ Ansible syntax valid
- ✅ All 12 Molecule tests pass
- ✅ No high-severity vulnerabilities
- ✅ All required docs present

### Failure = Block Merge

Pull requests cannot merge if any check fails.

---

## 🎯 CI Best Practices

### 1. Run Locally First

```bash

make ci  # Before pushing
```

### 2. Keep Pipelines Fast

- Current: ~20 minutes
- Target: <15 minutes

### 3. Meaningful Commit Messages

```
feat: add Valkey role with caching
test: add Molecule tests for Valkey role
docs: update caching documentation
```

### 4. Small, Focused PRs

- One feature per PR
- Easier to review
- Faster CI execution

---

## 📚 References

- [Woodpecker CI Docs](https://woodpecker-ci.org/docs/intro)
- [GitHub Actions Docs](https://docs.github.com/en/actions)
- [Molecule Docs](https://molecule.readthedocs.io/)
- [Ansible Lint Docs](https://ansible-lint.readthedocs.io/)

---

**Last Updated**: 2025-12-26
**Pipeline Status**: ✅ Configured and ready
