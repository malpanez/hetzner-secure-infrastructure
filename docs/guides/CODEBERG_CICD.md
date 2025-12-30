# Codeberg CI/CD - Woodpecker CI

## Overview

Codeberg provides **FREE unlimited CI/CD** through **Woodpecker CI**, a lightweight, open-source continuous integration platform.

## 🆚 Comparison: Codeberg vs GitHub

| Feature | **Codeberg (Woodpecker)** | GitHub Actions |
|---------|--------------------------|----------------|
| **Cost** | **FREE Unlimited** ⭐ | 2,000 min/month free |
| **Private Repos** | **Unlimited minutes** | Pay after 2,000 min |
| **Public Repos** | **Unlimited** | Unlimited |
| **Concurrent Jobs** | Shared runners | Shared + self-hosted |
| **Syntax** | Simple YAML | Complex YAML |
| **Marketplace** | Limited plugins | Huge ecosystem |
| **Open Source** | ✅ Fully OSS | ❌ Proprietary |
| **Privacy** | ✅ EU-based, GDPR | ❌ US-based |
| **Philosophy** | Community-first | Corporate |

## ⚡ Quick Facts

- **No time limits** on builds
- **No cost** for any usage
- **Docker-based** - Each step runs in isolated container
- **Git forge agnostic** - Works with Gitea, Forgejo, Codeberg
- **Simple configuration** - Easier than GitHub Actions
- **Matrix builds** supported
- **Secrets management** included
- **Caching** available

## 📋 Configuration

### File Location

```
.woodpecker/
  └── test.yml      # Main CI pipeline
```

### Basic Syntax

```yaml
---
# Simpler than GitHub Actions
steps:
  validate-terraform:
    image: hashicorp/terraform:1.6
    commands:
      - terraform fmt -check
      - terraform validate
    when:
      - event: push
      - event: pull_request

  test-ansible:
    image: cytopia/ansible:latest-tools
    commands:
      - ansible-playbook --syntax-check playbooks/site.yml
```

**vs GitHub Actions:**

```yaml
# More verbose
jobs:
  validate-terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.6
      - run: terraform fmt -check
      - run: terraform validate
```

## 🔧 Features

### 1. Docker Native

Every step runs in its own Docker container:

```yaml
steps:
  my-step:
    image: alpine:latest  # Any Docker image
    commands:
      - echo "Running in isolated container"
```

### 2. Matrix Builds

```yaml
matrix:
  TERRAFORM_VERSION:
    - 1.6
    - 1.7
    - 1.8

steps:
  test:
    image: hashicorp/terraform:${TERRAFORM_VERSION}
    commands:
      - terraform version
```

### 3. Secrets Management

```bash
# Set secrets via Codeberg UI:
# Repository → Settings → Secrets
```

```yaml
steps:
  deploy:
    image: alpine
    environment:
      - HCLOUD_TOKEN
    commands:
      - echo "Token: $HCLOUD_TOKEN"
    secrets: [hcloud_token]
```

### 4. Conditional Execution

```yaml
when:
  - event: push
    branch: main
  - event: pull_request
  - event: tag
```

### 5. Service Containers

```yaml
services:
  database:
    image: postgres:15
    environment:
      POSTGRES_PASSWORD: secret

steps:
  test:
    image: node:18
    commands:
      - npm test  # Can access database:5432
```

## 📊 Performance

### Build Times

- **Startup**: ~10-20 seconds (container pull)
- **Typical build**: 2-5 minutes
- **Full test suite**: 10-30 minutes
- **No timeout limits** (unlike GitHub's 6 hours)

### Caching

```yaml
steps:
  build:
    image: golang:1.21
    commands:
      - go build
    volumes:
      - /tmp/cache:/go/pkg  # Cache Go packages
```

## 🎯 Best Practices

### 1. Use Specific Image Tags

```yaml
# ✅ Good
image: hashicorp/terraform:1.6.0

# ❌ Bad (can break unexpectedly)
image: hashicorp/terraform:latest
```

### 2. Fail Fast

```yaml
steps:
  lint:
    image: golangci/golangci-lint:latest
    commands:
      - golangci-lint run
    # Fail entire pipeline if linting fails
```

### 3. Parallel Steps

```yaml
# These run in parallel by default
steps:
  test-go:
    image: golang:1.21
    commands: [go test]

  test-python:
    image: python:3.11
    commands: [pytest]
```

### 4. Environment-Specific Configs

```yaml
when:
  - branch: main
    event: push

# Only runs on main branch
steps:
  deploy:
    image: alpine
    commands: [./deploy.sh]
```

## 🔐 Security

### Secrets

- Stored encrypted in Codeberg
- Only accessible to authorized repos
- Not exposed in logs
- Per-repository or organization-wide

### Permissions

```yaml
# Limit what pipeline can do
steps:
  safe-step:
    image: alpine
    privileged: false  # No Docker-in-Docker
    commands:
      - echo "Safe operation"
```

## 📚 Current Setup

This repository uses **both**:

### Woodpecker CI (Codeberg)
- File: `.woodpecker/test.yml`
- Runs on: Push to `main`, Pull Requests
- **FREE unlimited minutes** ⭐
- Validates Terraform & Ansible
- Runs Molecule tests

### GitHub Actions
- Files: `.github/workflows/*.yml`
- More comprehensive (CodeQL, Terratest)
- Uses free tier (2,000 min/month)

## 🚀 Migration Tips

### From GitHub Actions to Woodpecker

1. **Checkout** (automatic)
   ```yaml
   # GitHub
   - uses: actions/checkout@v4

   # Woodpecker - automatic, no need to specify
   ```

2. **Setup Tools**
   ```yaml
   # GitHub
   - uses: hashicorp/setup-terraform@v3

   # Woodpecker - use Docker image
   image: hashicorp/terraform:1.6
   ```

3. **Run Commands**
   ```yaml
   # GitHub
   - run: terraform validate

   # Woodpecker
   commands:
     - terraform validate
   ```

## 📖 Resources

- [Woodpecker CI Docs](https://woodpecker-ci.org/docs/intro)
- [Codeberg CI Documentation](https://docs.codeberg.org/ci/)
- [Example Pipelines](https://codeberg.org/Codeberg/pages-server/src/branch/main/.woodpecker)
- [Plugin Index](https://woodpecker-ci.org/plugins)

## 💡 Why Use Woodpecker?

### Advantages

✅ **Cost**: Completely free, unlimited
✅ **Simplicity**: Easier syntax than GitHub Actions
✅ **Speed**: Fast container-based execution
✅ **Privacy**: EU-based, GDPR compliant
✅ **Vendor Lock-in**: Open source, portable
✅ **Resource Efficient**: Lightweight

### Disadvantages

❌ **Ecosystem**: Smaller plugin marketplace
❌ **Community**: Less Stack Overflow answers
❌ **Features**: Fewer advanced features
❌ **Documentation**: Less comprehensive

## 🎯 Recommendation

### Use Woodpecker For:
- ✅ Basic CI/CD (lint, test, build)
- ✅ Cost-sensitive projects
- ✅ Privacy-focused projects
- ✅ Simple pipelines
- ✅ Open source projects

### Use GitHub Actions For:
- ✅ Complex workflows
- ✅ Need specific marketplace actions
- ✅ Advanced features (matrix combinations, etc.)
- ✅ Already on GitHub

### Ideal Setup (This Repo):
- ✅ **Woodpecker**: Quick validation (free)
- ✅ **GitHub Actions**: Comprehensive testing (free tier)
- ✅ **Best of both worlds!**

---

**Last Updated**: 2025-12-27
**Woodpecker Version**: Latest
**Status**: Active and FREE ⭐
