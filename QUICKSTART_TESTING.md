# Quick Start - Testing Guide

## 🚀 Ready to Test!

Your repository has been upgraded to 2025 professional standards. Follow these steps to start testing.

## Prerequisites Check

```bash
# Check all tool versions
make version

# Expected output:
# Terraform: 1.6.0+
# Ansible: 2.15.0+
# Python: 3.10+
# Go: 1.21+
# Docker: 20.10+
```

## Step 1: Install Dependencies (5 min)

```bash
# Install all dependencies
make install-deps

# This will:
# ✅ Install Python dependencies
# ✅ Install Go modules
# ✅ Install Ansible collections
# ✅ Setup pre-commit hooks
```

## Step 2: Quick Validation (2 min)

```bash
# Fast validation check
./scripts/validate-all.sh

# This validates:
# ✅ Terraform format & syntax
# ✅ Ansible syntax
# ✅ YAML files
# ✅ Markdown files
# ✅ No secrets committed
```

## Step 3: Run Tests (10-30 min)

### Option A: Fast Tests (Skip expensive tests)

```bash
# Skip Molecule and Terratest
SKIP_MOLECULE=true SKIP_TERRATEST=true make test
```

### Option B: Partial Tests

```bash
# Only Terraform
make test-terraform-short

# Only Ansible syntax
make test-ansible-syntax

# Specific role
make test-molecule-role ROLE=nginx-wordpress
```

### Option C: Full Test Suite

```bash
# Run everything (requires Docker and Hetzner token)
make test
```

## Step 4: CI Simulation (5 min)

```bash
# Simulate full CI pipeline
make ci

# Or fast CI (skip slow tests)
make ci-fast
```

## Step 5: Deploy Test (Optional)

```bash
# Set your Hetzner Cloud token
export HCLOUD_TOKEN="your-token-here"

# Validate Terraform
make validate-terraform

# Test short mode (doesn't create real resources)
make test-terraform-short
```

## Common Commands

### Development Workflow

```bash
# See all commands
make help

# Check project status
make status

# Format code
make format

# Run linters
make lint

# Security scan
make security-scan
```

### Testing Commands

```bash
# Quick validation
./scripts/validate-all.sh

# Comprehensive test
./scripts/run-tests.sh

# CI pipeline
make ci
make ci-fast
```

### Quality Checks

```bash
# Pre-commit on all files
make pre-commit

# Validate only
make validate

# Lint only
make lint
```

## Troubleshooting

### "Command not found"

```bash
# Install missing tools
make install-deps

# Check what's missing
make version
```

### "Permission denied"

```bash
# Make scripts executable
chmod +x scripts/*.sh
```

### "Docker not running"

```bash
# Molecule tests require Docker
sudo systemctl start docker

# Or skip Molecule tests
SKIP_MOLECULE=true make test
```

### "Terraform backend"

```bash
# Tests use local backend
# No real Hetzner resources created in short mode
make test-terraform-short
```

## What's New?

### 🎯 Enhanced Makefile
- 15+ new commands
- Organized by category
- Color-coded output

### 🔐 Security Scanning
- 6 different security tools
- Pre-commit + CI/CD
- Secret detection

### 🧪 Automated Testing
- One-command test execution
- Colored output
- Progress tracking

### 📚 Professional Docs
- CONTRIBUTING.md
- SECURITY.md
- Issue/PR templates

### 🤖 Modern CI/CD
- GitHub Actions updated
- CodeQL security analysis
- Dependency scanning

## Next Steps

1. ✅ Run `make install-deps`
2. ✅ Run `./scripts/validate-all.sh`
3. ✅ Run `make ci-fast`
4. 📖 Read [CONTRIBUTING.md](CONTRIBUTING.md)
5. 📖 Read [UPGRADE_2025.md](UPGRADE_2025.md)

## Support

- 📖 Documentation: [docs/](docs/)
- 🐛 Issues: https://codeberg.org/malpanez/twomindstrading_hetzner/issues
- 📧 Email: malpanez@codeberg.org

---

**Happy Testing!** 🚀

Your repository is now production-ready with enterprise-grade tooling.
