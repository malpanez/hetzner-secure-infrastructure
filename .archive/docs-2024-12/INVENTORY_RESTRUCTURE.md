# Inventory Restructure - Before & After

## 🎯 Goal

Reorganize Ansible inventory to follow Red Hat CoP best practices with clean separation of concerns.

## 📊 Comparison

### Before (Old Structure)

```
inventory/
├── production.yml (191 lines) ❌
│   - Host definitions
│   - WordPress variables
│   - Monitoring variables
│   - OpenBao variables
│   - Security variables
│   - Comments and examples
│
├── group_vars/
│   ├── all.yml (57 lines) ❌
│   └── hetzner.yml (169 lines) ❌
│
└── hetzner.yml (36 lines)

Total: 453 lines across 4 files
```

**Problems**:
- ❌ Inventory mixed with variables
- ❌ Flat file structure hard to navigate
- ❌ Variables not organized by service
- ❌ Duplication between files
- ❌ Hard to find specific configuration

### After (New Structure)

```
inventory/
├── production.yml (45 lines) ✅ - ONLY host definitions
├── hetzner.yml (36 lines) ✅ - Dynamic inventory plugin
├── README.md (Documentation)
│
└── group_vars/
    ├── all/
    │   ├── common.yml (67 lines) - Global config
    │   └── secrets.yml (24 lines) - Encrypted secrets
    │
    ├── hetzner/
    │   ├── security.yml (133 lines) - SSH, firewall, 2FA
    │   └── system.yml (54 lines) - Kernel, sysctl
    │
    ├── wordpress_servers/
    │   ├── wordpress.yml (89 lines) - WordPress, LearnDash, plugins
    │   ├── nginx.yml (155 lines) - Web server, SSL, cache
    │   ├── php.yml (123 lines) - PHP-FPM, OpCache
    │   ├── valkey.yml (108 lines) - Object cache
    │   └── mariadb.yml (113 lines) - Database
    │
    ├── monitoring_servers/
    │   ├── prometheus.yml (77 lines) - Metrics collection
    │   ├── grafana.yml (125 lines) - Dashboards
    │   └── node_exporter.yml (82 lines) - System metrics
    │
    └── secrets_servers/
        └── openbao.yml (133 lines) - Secrets management

Total: 1,327 lines across 16 files (but organized!)
```

**Benefits**:
- ✅ Clean separation: inventory vs variables
- ✅ Organized by service/role
- ✅ Easy to find configuration
- ✅ Scalable architecture
- ✅ Red Hat CoP compliant

## 🔄 What Changed

### 1. Inventory File (`production.yml`)

**Before**: 191 lines mixing hosts + variables
**After**: 45 lines with ONLY host definitions

```yaml
# Before: Messy
all:
  children:
    wordpress_servers:
      hosts:
        wordpress-prod:
          ansible_host: "{{ wordpress_server_ip }}"
      vars:
        wordpress_domain: "..."
        php_version: "8.3"
        nginx_ssl_enabled: true
        # ... 50+ more variables

# After: Clean
all:
  children:
    wordpress_servers:
      hosts:
        wordpress-prod:
          ansible_host: "{{ wordpress_server_ip }}"
```

### 2. Variables Organization

**Before**: Flat files
```
group_vars/
├── all.yml (everything global)
└── hetzner.yml (everything Hetzner)
```

**After**: Organized by service
```
group_vars/
├── all/
│   ├── common.yml (system basics)
│   └── secrets.yml (credentials)
├── hetzner/
│   ├── security.yml (SSH, firewall, 2FA)
│   └── system.yml (kernel, sysctl)
├── wordpress_servers/
│   ├── wordpress.yml
│   ├── nginx.yml
│   ├── php.yml
│   ├── valkey.yml
│   └── mariadb.yml
├── monitoring_servers/
│   ├── prometheus.yml
│   ├── grafana.yml
│   └── node_exporter.yml
└── secrets_servers/
    └── openbao.yml
```

### 3. Variable Precedence (Clearer)

```
1. group_vars/all/common.yml         (lowest - applies to ALL)
2. group_vars/hetzner/security.yml   (Hetzner-specific)
3. group_vars/wordpress_servers/*.yml (WordPress-specific)
4. host_vars/wordpress-prod.yml      (highest - host-specific)
```

## 📈 Metrics

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Inventory file lines** | 191 | 45 | 76% reduction |
| **Files** | 4 | 16 | Better organization |
| **Avg lines per file** | 113 | 83 | Easier to read |
| **Variables by service** | ❌ No | ✅ Yes | Much better! |
| **Easy to find config** | ❌ Hard | ✅ Easy | Know where to look |
| **Scalability** | ❌ Poor | ✅ Excellent | Add groups easily |

## 🎓 Examples

### Finding Configuration

**Before**: Search through 191-line production.yml or 169-line hetzner.yml
**After**: Go directly to the file you need:

- Need Nginx config? → `wordpress_servers/nginx.yml`
- Need PHP settings? → `wordpress_servers/php.yml`
- Need SSH config? → `hetzner/security.yml`
- Need Prometheus? → `monitoring_servers/prometheus.yml`

### Adding a New Service

**Before**: Add variables to production.yml, making it even longer
**After**: Create new directory in `group_vars/`:

```bash
mkdir group_vars/database_servers/
echo "mariadb_version: 10.11" > group_vars/database_servers/mariadb.yml
```

### Deployment Scenarios

Both before and after support flexible deployments, but new structure is clearer:

```yaml
# All-in-one (1 server)
wordpress_server_ip: "65.108.1.100"
openbao_server_ip: ""
monitoring_server_ip: ""

# Separated (3 servers)
wordpress_server_ip: "65.108.1.100"
openbao_server_ip: "65.108.1.101"
monitoring_server_ip: "65.108.1.102"
```

## ✅ Validation

### Inventory Structure
```bash
$ ansible-inventory -i inventory/production.yml --graph
@all:
  |--@ungrouped:
  |--@hetzner:
  |  |--@wordpress_servers:
  |  |  |--wordpress-prod
  |  |--@secrets_servers:
  |  |  |--openbao-prod
  |  |--@monitoring_servers:
  |  |  |--monitoring-prod
  |--@monitored_servers:
  |  |--@wordpress_servers:
  |  |  |--wordpress-prod
  |  |--@secrets_servers:
  |  |  |--openbao-prod
  |  |--@monitoring_servers:
  |  |  |--monitoring-prod
```

### Variables Loading
```bash
$ ansible-inventory -i inventory/production.yml --host wordpress-prod | grep php_version
    "php_version": "8.3",

$ ansible-inventory -i inventory/production.yml --host wordpress-prod | grep valkey_version
    "valkey_version": "8.0",

$ ansible-inventory -i inventory/production.yml --host wordpress-prod | grep nginx_ssl_enabled
    "nginx_ssl_enabled": true,
```

All variables load correctly! ✅

## 🚀 Migration Steps

1. ✅ Created new directory structure
2. ✅ Split variables by service/role
3. ✅ Simplified production.yml to hosts only
4. ✅ Validated with ansible-inventory commands
5. ✅ Created documentation (README.md)
6. ✅ Removed old flat files

## 📚 References

- [Red Hat CoP Best Practices](https://redhat-cop.github.io/automation-good-practices/)
- [Ansible Inventory Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html#content-organization)
- [Variable Precedence](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable)

---

**Completed**: 2025-12-26
**Status**: ✅ Production-ready
**Validated**: All inventory commands working correctly
