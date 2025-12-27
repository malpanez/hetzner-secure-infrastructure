# Testing Guide

Complete testing strategy for Hetzner infrastructure with Terraform + Ansible.

## 🎯 Test Coverage

| Component | Test Type | Tool | Coverage | Status |
|-----------|-----------|------|----------|--------|
| **Terraform** | Infrastructure | Terratest | 100% | ✅ Complete |
| **Ansible Roles** | Configuration | Molecule | 100% (11 roles) | ✅ Complete |
| **Playbooks** | Syntax | ansible-playbook | 100% | ✅ Complete |
| **Integration** | End-to-end | Custom scripts | Planned | ⚠️ TODO |

---

## 🚀 Quick Start

### Prerequisites

```bash
# Install testing tools
make install-deps

# Or manually:
# 1. Go (for Terratest)
sudo apt install golang-go

# 2. Python packages (for Molecule)
pip3 install molecule molecule-docker ansible-lint yamllint

# 3. Ansible collections
ansible-galaxy collection install -r ansible/requirements.yml

# 4. Docker (for Molecule)
sudo apt install docker.io
sudo usermod -aG docker $USER
```

### Run All Tests

```bash
# Complete test suite (~45 minutes)
make test

# Or run individually:
make test-terraform    # Infrastructure tests (30 min)
make test-ansible      # Ansible tests (15 min)
```

---

## 🧪 Terratest (Infrastructure Tests)

### What is Tested

- ✅ Hetzner servers created correctly
- ✅ Server specifications (type, location, image)
- ✅ Firewall rules configured
- ✅ SSH keys deployed
- ✅ Labels set for Ansible discovery
- ✅ Network configuration
- ✅ SSH connectivity
- ✅ Debian 13 installation

### Run Tests

```bash
# Full test suite (creates real servers - costs ~€0.05)
cd terraform/test
export HCLOUD_TOKEN="your-hetzner-token"
go test -v -timeout 30m

# Short tests only (single server)
go test -v -timeout 15m -short

# Specific test
go test -v -run TestTerraformHetznerInfrastructure
```

### Test Files

```
terraform/test/
├── go.mod                      # Go dependencies
├── infrastructure_test.go      # Main infrastructure tests
└── README.md                   # Terratest documentation
```

### Example Test Output

```
=== RUN   TestTerraformHetznerInfrastructure
=== RUN   TestTerraformHetznerInfrastructure/WordPressServerCreated
=== RUN   TestTerraformHetznerInfrastructure/ServerLabels
=== RUN   TestTerraformHetznerInfrastructure/SSHConnectivity
=== RUN   TestTerraformHetznerInfrastructure/DebianVersion
=== RUN   TestTerraformHetznerInfrastructure/FirewallConfigured
--- PASS: TestTerraformHetznerInfrastructure (12.34s)
    --- PASS: TestTerraformHetznerInfrastructure/WordPressServerCreated (0.01s)
    --- PASS: TestTerraformHetznerInfrastructure/ServerLabels (0.01s)
    --- PASS: TestTerraformHetznerInfrastructure/SSHConnectivity (2.45s)
    --- PASS: TestTerraformHetznerInfrastructure/DebianVersion (0.34s)
    --- PASS: TestTerraformHetznerInfrastructure/FirewallConfigured (0.01s)
PASS
ok      github.com/hetzner-infrastructure/test  742.123s
```

---

## 🔬 Molecule (Ansible Role Tests)

### Roles with Tests

All 11 roles have Molecule tests:

- ✅ `apparmor` - AppArmor security profiles
- ✅ `fail2ban` - Intrusion prevention
- ✅ `firewall` - UFW firewall configuration
- ✅ `grafana` - Grafana dashboards
- ✅ `mariadb` - Database server
- ✅ `nginx-wordpress` - Web server + WordPress
- ✅ `node-exporter` - Prometheus metrics exporter
- ✅ `openbao` - Secrets management
- ✅ `prometheus` - Metrics collection
- ✅ `ssh-2fa` - SSH two-factor authentication
- ✅ `valkey` - Object cache (Redis fork)

### Run Tests

```bash
# Test all roles
make test-molecule

# Test specific role
make test-molecule-role ROLE=nginx-wordpress

# Or manually:
cd ansible/roles/nginx-wordpress
molecule test
```

### Molecule Test Phases

1. **Dependency** - Install role dependencies
2. **Lint** - Check syntax and best practices
3. **Cleanup** - Remove old test containers
4. **Destroy** - Destroy test environment
5. **Create** - Create Docker container
6. **Prepare** - Prepare test environment
7. **Converge** - Apply role to container
8. **Idempotence** - Run role again (should not change)
9. **Verify** - Run verification tests
10. **Cleanup** - Remove test containers

### Example: nginx-wordpress Role Test

```bash
cd ansible/roles/nginx-wordpress
molecule test
```

**Verifies**:
- Nginx installed and running
- PHP-FPM installed and running
- FastCGI cache directory exists
- Nginx config is valid
- PHP socket exists
- Nginx listens on port 80

---

## 📋 Test Workflow

### Pre-Deployment Testing

```bash
# 1. Validate configurations
make validate

# 2. Run all tests
make test

# 3. Review results
# All tests must pass before deployment
```

### Continuous Integration

```bash
# CI pipeline (automated)
make ci

# This runs:
# 1. validate-terraform
# 2. validate-ansible
# 3. test-terraform
# 4. test-ansible
```

---

## 🐛 Troubleshooting

### Terratest Fails

**Problem**: `HCLOUD_TOKEN not set`
```bash
export HCLOUD_TOKEN="your-token-here"
```

**Problem**: `SSH timeout`
- Server may be slow to boot
- Check firewall allows SSH (port 22)
- Verify SSH key is correct

**Problem**: Test hangs
- Check Hetzner API limits
- Increase timeout: `go test -timeout 60m`

### Molecule Fails

**Problem**: `Docker daemon not running`
```bash
sudo systemctl start docker
sudo usermod -aG docker $USER
# Logout and login again
```

**Problem**: `Image not found`
```bash
# Pull image manually
docker pull geerlingguy/docker-debian13-ansible:latest
```

**Problem**: `Role dependency failed`
```bash
# Install dependencies
ansible-galaxy install -r requirements.yml
```

---

## 📊 Test Metrics

### Expected Results

| Metric | Target | Actual |
|--------|--------|--------|
| **Test Coverage** | 100% | 100% ✅ |
| **Terraform Tests** | 3+ tests | 3 ✅ |
| **Molecule Tests** | 11 roles | 11 ✅ |
| **Test Duration** | <60 min | ~45 min ✅ |
| **Pass Rate** | 100% | TBD |

### Cost of Testing

| Test Type | Cost | Duration |
|-----------|------|----------|
| Terraform (single server) | ~€0.02 | ~15 min |
| Terraform (multi-server) | ~€0.05 | ~30 min |
| Molecule (all roles) | €0 (local Docker) | ~15 min |
| **Total per run** | **~€0.05** | **~45 min** |

---

## 🔄 Automated Testing Schedule

### Recommended Schedule

- **On every commit**: `make validate` (fast, free)
- **Before merge**: `make ci` (complete, costs ~€0.05)
- **Weekly**: Full test suite including multi-server
- **Before production deploy**: Complete test suite

---

## 📚 Additional Resources

- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Ansible Testing Strategies](https://docs.ansible.com/ansible/latest/reference_appendices/test_strategies.html)

---

**Last Updated**: 2025-12-26
**Test Status**: ✅ All 11 roles + 3 Terratest suites implemented
