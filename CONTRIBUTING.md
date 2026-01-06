# Contributing to Hetzner Secure Infrastructure

Thank you for your interest in contributing! This document provides guidelines and instructions for contributing to this project.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [Development Setup](#development-setup)
- [Making Changes](#making-changes)
- [Testing](#testing)
- [Submitting Changes](#submitting-changes)
- [Coding Standards](#coding-standards)
- [Documentation](#documentation)

## Code of Conduct

This project follows the [Contributor Covenant Code of Conduct](https://www.contributor-covenant.org/version/2/1/code_of_conduct/). By participating, you are expected to uphold this code.

## Getting Started

### Prerequisites

Before contributing, ensure you have:

- **Terraform** >= 1.6.0
- **Ansible** >= 2.15.0
- **Python** >= 3.10
- **Go** >= 1.21 (for Terratest)
- **Docker** (for Molecule tests)
- **Git**
- **pre-commit**

### Fork and Clone

1. Fork the repository on Codeberg
2. Clone your fork:

```bash
git clone https://codeberg.org/YOUR-USERNAME/twomindstrading_hetzner.git
cd twomindstrading_hetzner
```

1. Add upstream remote:

```bash
git remote add upstream https://codeberg.org/malpanez/twomindstrading_hetzner.git
```

## Development Setup

### 1. Install Dependencies

```bash
make install-deps
```

This will install:

- Python dependencies (Ansible, Molecule, etc.)
- Go dependencies (Terratest)
- Ansible Galaxy collections
- Pre-commit hooks

### 2. Verify Setup

```bash
make version
make status
```

### 3. Run Tests

Verify everything works:

```bash
make validate
make test
```

## Making Changes

### 1. Create a Branch

Always create a new branch for your work:

```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/bug-description
```

Branch naming conventions:

- `feature/` - New features
- `fix/` - Bug fixes
- `docs/` - Documentation updates
- `refactor/` - Code refactoring
- `test/` - Test additions/improvements

### 2. Make Your Changes

Follow our [coding standards](#coding-standards) when making changes.

### 3. Test Your Changes

Before committing, always test:

```bash
# Quick validation
make validate

# Full test suite
make test

# Or run specific tests
make test-terraform
make test-ansible
make test-molecule-role ROLE=nginx-wordpress
```

### 4. Commit Your Changes

We use [Conventional Commits](https://www.conventionalcommits.org/):

```bash
# Format: <type>(<scope>): <description>

git commit -m "feat(terraform): add support for load balancer"
git commit -m "fix(ansible): correct nginx configuration path"
git commit -m "docs(readme): update installation instructions"
git commit -m "test(molecule): add tests for fail2ban role"
```

**Commit Types:**

- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation only
- `style:` - Code style changes (formatting, etc.)
- `refactor:` - Code refactoring
- `test:` - Adding or updating tests
- `chore:` - Maintenance tasks
- `ci:` - CI/CD changes

**Pre-commit hooks will automatically:**

- Format your code
- Run linters
- Check for secrets
- Validate commit messages

## Testing

### Required Tests

All contributions must include appropriate tests:

#### Terraform Changes

```bash
# Format and validate
cd terraform/environments/production
terraform fmt -recursive
terraform validate

# Run Terratest
cd ../../test
go test -v -timeout 30m
```

#### Ansible Changes

```bash
# Syntax check
cd ansible
ansible-playbook playbooks/site.yml --syntax-check

# Lint
ansible-lint playbooks/site.yml

# Molecule tests (for role changes)
cd roles/your-role
molecule test
```

#### Documentation Changes

```bash
# Check markdown
markdownlint *.md docs/*.md

# Check links
make docs-check
```

### Test Coverage

- **Terraform**: All modules must have Terratest coverage
- **Ansible**: All roles must have Molecule tests
- **Documentation**: All code examples must be tested

## Submitting Changes

### 1. Update Documentation

Ensure documentation is up to date:

- Update README.md if adding features
- Update relevant docs/ files
- Add/update code comments
- Update CHANGELOG.md

### 2. Push Your Changes

```bash
git push origin your-branch-name
```

### 3. Create a Pull Request

1. Go to the repository on Codeberg
2. Click "New Pull Request"
3. Select your branch
4. Fill out the PR template completely
5. Link related issues

**PR Title Format:**

```
<type>(<scope>): <description>

Example:
feat(ansible): add Redis sentinel support
fix(terraform): correct network security group rules
```

### 4. PR Review Process

1. **Automated Checks**: CI/CD must pass
2. **Code Review**: At least one maintainer approval required
3. **Testing**: All tests must pass
4. **Documentation**: Docs must be updated
5. **Conflicts**: Resolve any merge conflicts

## Coding Standards

### Terraform

- Use descriptive variable names
- Include variable descriptions
- Add validation rules where appropriate
- Use consistent formatting (run `terraform fmt`)
- Follow [HashiCorp best practices](https://www.terraform.io/docs/language/syntax/style.html)

```hcl
# Good
variable "server_type" {
  description = "Hetzner Cloud server type"
  type        = string
  default     = "cx21"

  validation {
    condition     = contains(["cx11", "cx21", "cx31"], var.server_type)
    error_message = "Server type must be cx11, cx21, or cx31."
  }
}

# Bad
variable "st" {
  type    = string
  default = "cx21"
}
```

### Ansible

- Follow [Red Hat Community of Practice](https://redhat-cop.github.io/automation-good-practices/)
- Use fully qualified collection names (FQCN)
- Include task names
- Use meaningful variable names
- Add comments for complex logic

```yaml
# Good
- name: Install and configure Nginx
  ansible.builtin.package:
    name: nginx
    state: present
  notify: Restart nginx

# Bad
- package:
    name: nginx
```

### Python

- Follow PEP 8
- Use type hints
- Add docstrings
- Run `black` for formatting
- Use `ruff` for linting

```python
# Good
def deploy_infrastructure(server_type: str, region: str) -> dict[str, any]:
    """Deploy infrastructure to Hetzner Cloud.

    Args:
        server_type: The Hetzner server type (e.g., 'cx21')
        region: The deployment region (e.g., 'nbg1')

    Returns:
        Dictionary containing deployment details
    """
    pass

# Bad
def deploy(st, r):
    pass
```

### Shell Scripts

- Use `#!/usr/bin/env bash`
- Enable strict mode: `set -euo pipefail`
- Add comments
- Use `shellcheck`
- Quote variables

```bash
#!/usr/bin/env bash
set -euo pipefail

# Good
readonly SERVER_TYPE="${1:-cx21}"
echo "Deploying server type: ${SERVER_TYPE}"

# Bad
server_type=$1
echo "Deploying server type: $server_type"
```

## Documentation

### Code Comments

- Explain **why**, not **what**
- Use clear, concise language
- Keep comments up to date

### README Updates

When adding features, update:

- Features list
- Quick start guide
- Architecture diagrams (if applicable)
- Examples

### Documentation Files

Create/update docs in `docs/` directory:

- Architecture decisions → `ARCHITECTURE_DECISIONS.md`
- Deployment guides → `DEPLOYMENT_GUIDE.md`
- Troubleshooting → `TROUBLESHOOTING.md`

## Release Process

Maintainers will handle releases:

1. Update CHANGELOG.md
2. Update version in relevant files
3. Create release tag
4. Build and publish artifacts

## Questions?

- **Issues**: [Project Issues](https://codeberg.org/malpanez/twomindstrading_hetzner/issues)
- **Discussions**: [GitHub Discussions](https://github.com/malpanez/hetzner-secure-infrastructure/discussions)
- **Email**: <malpanez@codeberg.org>

## Recognition

Contributors will be recognized in:

- CHANGELOG.md
- GitHub releases
- README.md (for significant contributions)

---

**Thank you for contributing!** 🎉

Your contributions help make this project better for everyone.
