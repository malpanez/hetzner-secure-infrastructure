# Production Readiness Plan - Deployment 2 Enero 2025

> **Plan completo para tener toda la infraestructura production-ready con testing exhaustivo**

**Deadline**: 2 de Enero 2025 (o antes)
**Estado Actual**: 70% completo
**Estado Objetivo**: 100% tested, linted, production-ready

---

## 📋 Checklist de Production Readiness

### Ansible Roles

#### ✅ Roles Completos (Production Ready)
- [x] **prometheus** - APT, DEB822, Molecule tests ✅
- [x] **node_exporter** - APT, DEB822, Molecule tests ✅
- [x] **loki** - APT, DEB822, Molecule tests ✅
- [x] **promtail** - APT, DEB822, Molecule tests ✅
- [x] **grafana** - APT, DEB822, Molecule tests ✅
- [x] **openbao** - Molecule tests ✅
- [x] **firewall** - Variables corregidas ✅

#### ⏳ Roles Pendientes (Tasks + Tests)
- [ ] **mariadb**
  - [x] Defaults corregidos ✅
  - [x] Estructura ansible-galaxy ✅
  - [ ] Tasks implementadas (install, configure, optimize, backup, exporter)
  - [ ] Molecule tests (Testinfra)
  - [ ] ansible-lint passing

- [ ] **nginx-wordpress**
  - [x] Defaults corregidos ✅
  - [x] Estructura ansible-galaxy ✅
  - [ ] Tasks implementadas (install, configure, ssl, optimize, security)
  - [ ] Molecule tests (Testinfra)
  - [ ] ansible-lint passing

- [ ] **valkey**
  - [x] Defaults corregidos ✅
  - [x] Estructura ansible-galaxy ✅
  - [ ] Tasks implementadas (install, configure, backup, exporter)
  - [ ] Molecule tests (Testinfra)
  - [ ] ansible-lint passing

### Terraform Modules

#### ⏳ Pending Testing & Linting
- [ ] **hetzner-server**
  - [ ] tflint passing
  - [ ] terraform validate
  - [ ] terraform fmt -check
  - [ ] terratest (Go tests)

- [ ] **hetzner-network**
  - [ ] tflint passing
  - [ ] terraform validate
  - [ ] terratest

- [ ] **hetzner-firewall**
  - [ ] tflint passing
  - [ ] terraform validate
  - [ ] terratest

### Integration Tests

- [ ] End-to-end deployment test
- [ ] Terraform apply + Ansible playbook
- [ ] Monitoring stack validation
- [ ] Backup/restore procedures
- [ ] Disaster recovery test

---

## 🗓️ Timeline (28 Dic → 2 Ene)

### Día 1-2 (28-29 Diciembre): Ansible Roles Implementation

**Prioridad 1: MariaDB** (más crítico)
- [ ] `tasks/install.yml` - APT installation, users, directories
- [ ] `tasks/configure.yml` - my.cnf deployment, performance tuning
- [ ] `tasks/optimize.yml` - WordPress-specific optimizations
- [ ] `tasks/backup.yml` - mysqldump automation
- [ ] `tasks/exporter.yml` - mysqld_exporter for Prometheus
- [ ] `tasks/validate.yml` - Connection tests, query tests
- [ ] `molecule/default/verify.yml` - Testinfra assertions
- [ ] Run: `molecule test`

**Prioridad 2: Nginx-WordPress** (dependiente de MariaDB)
- [ ] `tasks/install.yml` - Nginx, PHP-FPM, dependencies
- [ ] `tasks/configure.yml` - Nginx vhost, PHP-FPM pool
- [ ] `tasks/ssl.yml` - Certbot, SSL automation
- [ ] `tasks/optimize.yml` - FastCGI cache, gzip, brotli
- [ ] `tasks/security.yml` - Headers, WAF rules, hardening
- [ ] `tasks/exporter.yml` - nginx_exporter, phpfpm_exporter
- [ ] `molecule/default/verify.yml` - Testinfra assertions
- [ ] Run: `molecule test`

**Prioridad 3: Valkey** (cache layer)
- [ ] `tasks/install.yml` - APT installation from Debian repos
- [ ] `tasks/configure.yml` - valkey.conf, socket, TCP
- [ ] `tasks/optimize.yml` - WordPress optimizations
- [ ] `tasks/backup.yml` - BGSAVE automation
- [ ] `tasks/exporter.yml` - redis_exporter for Prometheus
- [ ] `molecule/default/verify.yml` - Testinfra assertions
- [ ] Run: `molecule test`

### Día 3 (30 Diciembre): Ansible Testing & Linting

**ansible-lint**
```bash
ansible-lint ansible/roles/mariadb/
ansible-lint ansible/roles/nginx-wordpress/
ansible-lint ansible/roles/valkey/
ansible-lint ansible/roles/  # All roles
```

**Molecule tests**
```bash
cd ansible/roles/mariadb && molecule test
cd ansible/roles/nginx-wordpress && molecule test
cd ansible/roles/valkey && molecule test
```

**Integration test**
```bash
ansible-playbook -i inventory/test.yml playbooks/site.yml --check
ansible-playbook -i inventory/test.yml playbooks/site.yml --syntax-check
```

### Día 4 (31 Diciembre): Terraform Testing

**tflint**
```bash
cd terraform/modules/hetzner-server
tflint --init
tflint

cd terraform/modules/hetzner-network
tflint

cd terraform/modules/hetzner-firewall
tflint
```

**terraform validate**
```bash
cd terraform/environments/production
terraform init
terraform validate
terraform fmt -check -recursive
terraform plan
```

**terratest** (Go tests)
```bash
cd terraform/modules/hetzner-server/test
go test -v -timeout 30m
```

### Día 5 (1 Enero): End-to-End Testing

**Full deployment test:**
```bash
# 1. Terraform deployment
cd terraform/environments/production
terraform apply

# 2. Ansible deployment
cd ../../../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml

# 3. Validation
ansible-playbook -i inventory/hetzner.yml playbooks/validate.yml

# 4. Monitoring check
# - Prometheus targets up
# - Loki receiving logs
# - Grafana dashboards working
# - All exporters responding

# 5. Backup test
# - MariaDB backup
# - Prometheus snapshot
# - Loki backup
# - Valkey BGSAVE

# 6. Disaster recovery test (opcional)
# - Destroy and recreate server
# - Restore from backups
```

### Día 6 (2 Enero): Production Deployment

**Go-live checklist:**
- [ ] All ansible-lint checks passing
- [ ] All Molecule tests passing
- [ ] All terraform validate passing
- [ ] All tflint checks passing
- [ ] End-to-end test successful
- [ ] Backups tested and working
- [ ] Monitoring fully operational
- [ ] Documentation updated
- [ ] Secrets properly managed
- [ ] DNS configured
- [ ] SSL certificates valid
- [ ] Performance tested

---

## 🧪 Testing Tools Setup

### Molecule (Ansible)

**Installation:**
```bash
pip install molecule molecule-docker ansible-lint yamllint
```

**molecule.yml structure:**
```yaml
---
dependency:
  name: galaxy
driver:
  name: docker
platforms:
  - name: debian-13
    image: debian:13
    pre_build_image: true
provisioner:
  name: ansible
  config_options:
    defaults:
      callbacks_enabled: timer, profile_tasks
verifier:
  name: ansible  # Using Testinfra via ansible
```

**Testinfra examples:**

```python
# molecule/default/tests/test_mariadb.py
def test_mariadb_installed(host):
    mariadb = host.package("mariadb-server")
    assert mariadb.is_installed

def test_mariadb_running(host):
    mariadb = host.service("mariadb")
    assert mariadb.is_running
    assert mariadb.is_enabled

def test_mariadb_listening(host):
    assert host.socket("tcp://0.0.0.0:3306").is_listening

def test_mariadb_config_exists(host):
    config = host.file("/etc/mysql/my.cnf")
    assert config.exists
    assert config.user == "root"
    assert config.group == "root"

def test_mariadb_wordpress_database(host):
    cmd = host.run("mysql -e 'SHOW DATABASES;'")
    assert "wordpress" in cmd.stdout
```

### Terraform Testing

**tflint installation:**
```bash
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
```

**.tflint.hcl:**
```hcl
plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = false
}

rule "terraform_naming_convention" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}
```

**terratest example:**
```go
// test/hetzner_server_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestHetznerServer(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../",
        Vars: map[string]interface{}{
            "server_name": "test-server",
            "server_type": "cx11",
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    serverIP := terraform.Output(t, terraformOptions, "ipv4_address")
    assert.NotEmpty(t, serverIP)
}
```

---

## 📝 Implementation Checklist por Role

### MariaDB Role

**tasks/install.yml:**
```yaml
- name: mariadb | install | Add MariaDB repository key
- name: mariadb | install | Add MariaDB APT repository
- name: mariadb | install | Install MariaDB server
- name: mariadb | install | Install MariaDB client
- name: mariadb | install | Create MariaDB directories
- name: mariadb | install | Secure MariaDB installation
```

**tasks/configure.yml:**
```yaml
- name: mariadb | configure | Deploy my.cnf configuration
- name: mariadb | configure | Create WordPress database
- name: mariadb | configure | Create WordPress user
- name: mariadb | configure | Set database permissions
- name: mariadb | configure | Enable slow query log
- name: mariadb | configure | Configure binary logging
```

**tasks/optimize.yml:**
```yaml
- name: mariadb | optimize | Set InnoDB buffer pool size
- name: mariadb | optimize | Configure connection settings
- name: mariadb | optimize | Set query cache (WordPress)
- name: mariadb | optimize | Optimize table cache
- name: mariadb | optimize | Configure thread settings
```

**tasks/backup.yml:**
```yaml
- name: mariadb | backup | Create backup directory
- name: mariadb | backup | Deploy backup script
- name: mariadb | backup | Create backup cron job
- name: mariadb | backup | Set backup retention policy
```

**tasks/exporter.yml:**
```yaml
- name: mariadb | exporter | Create exporter user
- name: mariadb | exporter | Download mysqld_exporter
- name: mariadb | exporter | Install mysqld_exporter
- name: mariadb | exporter | Deploy exporter systemd service
- name: mariadb | exporter | Start exporter service
- name: mariadb | exporter | Configure firewall for exporter
```

**tasks/validate.yml:**
```yaml
- name: mariadb | validate | Wait for MariaDB to start
- name: mariadb | validate | Test database connection
- name: mariadb | validate | Verify WordPress database exists
- name: mariadb | validate | Test exporter endpoint
- name: mariadb | validate | Display MariaDB status
```

**molecule/default/verify.yml:**
```yaml
- name: Verify MariaDB
  hosts: all
  tasks:
    - name: Check MariaDB is installed
      package:
        name: mariadb-server
        state: present
      check_mode: yes
      register: pkg_check
      failed_when: pkg_check is changed

    - name: Check MariaDB is running
      service:
        name: mariadb
        state: started
        enabled: yes
      check_mode: yes
      register: svc_check
      failed_when: svc_check is changed

    - name: Check MariaDB is listening
      wait_for:
        port: 3306
        timeout: 5

    - name: Verify configuration file exists
      stat:
        path: /etc/mysql/my.cnf
      register: config
      failed_when: not config.stat.exists

    - name: Test database connection
      command: mysql -e 'SELECT 1;'
      changed_when: false

    - name: Verify WordPress database exists
      command: mysql -e 'SHOW DATABASES LIKE "wordpress";'
      register: db_check
      changed_when: false
      failed_when: "'wordpress' not in db_check.stdout"

    - name: Check exporter is running
      uri:
        url: http://localhost:9104/metrics
        status_code: 200
      when: mariadb_mysqld_exporter_enabled
```

---

## 🎯 Success Criteria

### Ansible

- [ ] **0 ansible-lint warnings** en todos los roles
- [ ] **100% Molecule tests passing** (mariadb, nginx-wordpress, valkey)
- [ ] **Syntax check passing** en site.yml
- [ ] **Variables**: 100% con prefijo `rolename_`
- [ ] **Task names**: 100% con formato `role | taskfile | description`
- [ ] **Idempotencia**: Re-run sin cambios

### Terraform

- [ ] **0 tflint warnings** en todos los módulos
- [ ] **terraform validate passing** en todos los entornos
- [ ] **terraform fmt -check passing** (código formateado)
- [ ] **terratest passing** en módulos críticos
- [ ] **terraform plan** sin errores

### Integration

- [ ] **Full deployment** exitoso (Terraform + Ansible)
- [ ] **Monitoring stack** operacional (Prometheus, Loki, Grafana)
- [ ] **All exporters** reportando métricas
- [ ] **All alerts** configuradas y funcionales
- [ ] **Backups** automáticos funcionando
- [ ] **SSL** válido y auto-renovable
- [ ] **Performance** dentro de límites aceptables

---

## 📚 Recursos

### Ansible
- [Molecule Documentation](https://molecule.readthedocs.io/)
- [Testinfra Documentation](https://testinfra.readthedocs.io/)
- [ansible-lint Rules](https://ansible.readthedocs.io/projects/lint/rules/)

### Terraform
- [tflint Documentation](https://github.com/terraform-linters/tflint)
- [Terratest Documentation](https://terratest.gruntwork.io/)
- [Terraform Testing Best Practices](https://www.terraform.io/docs/language/modules/testing-experiment.html)

---

## 🚀 Quick Start Commands

```bash
# Ansible - Implement role tasks
cd ansible/roles/mariadb
# Edit tasks/*.yml files
molecule test

# Ansible - Lint all
cd ../../
ansible-lint roles/

# Terraform - Lint
cd terraform/modules/hetzner-server
tflint

# Terraform - Test
cd terraform/environments/production
terraform validate
terraform plan

# Full deployment test
./scripts/test-full-deployment.sh
```

---

**Deadline**: 2 Enero 2025
**Estado Actual**: Plan creado ✅
**Siguiente paso**: Implementar tasks de mariadb role

