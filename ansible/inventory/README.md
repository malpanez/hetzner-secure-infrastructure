# Ansible Inventory Structure

Clean and modular inventory following Red Hat CoP best practices.

## 📁 Directory Structure

```
inventory/
├── production.yml              # Main inventory (hosts only, 45 lines)
├── hetzner.yml                 # Dynamic inventory plugin (Hetzner Cloud API)
│
├── group_vars/                 # Variables organized by group
│   ├── all/                    # Variables for ALL hosts
│   │   ├── common.yml         # System config, packages, timezone
│   │   └── secrets.yml        # Encrypted secrets (Ansible Vault)
│   │
│   ├── hetzner/               # Variables for ALL Hetzner servers
│   │   ├── security.yml       # SSH, firewall, fail2ban, 2FA
│   │   └── system.yml         # Sysctl, kernel hardening, AppArmor
│   │
│   ├── wordpress_servers/     # Variables for WordPress servers
│   │   ├── wordpress.yml      # WordPress config, plugins, theme
│   │   ├── nginx.yml          # Nginx, SSL, caching, rate limiting
│   │   ├── php.yml            # PHP-FPM, OpCache, extensions
│   │   ├── valkey.yml         # Valkey object cache (Redis fork)
│   │   └── mariadb.yml        # MariaDB database config
│   │
│   ├── monitoring_servers/    # Variables for monitoring servers
│   │   ├── prometheus.yml     # Prometheus time-series database
│   │   ├── grafana.yml        # Grafana visualization
│   │   └── node_exporter.yml  # System metrics exporter
│   │
│   └── secrets_servers/       # Variables for secrets management
│       └── openbao.yml        # OpenBao (Vault alternative)
│
└── host_vars/                 # Host-specific variables (optional)
    └── wordpress-prod.yml     # Variables specific to wordpress-prod host
```

## 🎯 Benefits of This Structure

1. **Clean Separation**: Inventory file is ONLY hosts, variables in `group_vars/`
2. **Modular**: Each service has its own directory with related variables
3. **Scalable**: Easy to add new services or server groups
4. **Maintainable**: Find variables by service (e.g., all Nginx config in one place)
5. **Red Hat CoP Compliant**: Follows industry best practices

## 📋 Host Groups

| Group | Purpose | Hosts |
|-------|---------|-------|
| `all` | All hosts in inventory | wordpress-prod, openbao-prod, monitoring-prod |
| `hetzner` | All Hetzner Cloud servers | wordpress-prod, openbao-prod, monitoring-prod |
| `wordpress_servers` | WordPress application servers | wordpress-prod |
| `secrets_servers` | OpenBao secrets management | openbao-prod |
| `monitoring_servers` | Prometheus + Grafana | monitoring-prod |
| `monitored_servers` | Servers with Node Exporter | All servers |

## 🔧 Variable Precedence

Ansible loads variables in this order (last wins):

1. `group_vars/all/` - Lowest precedence (applies to all hosts)
2. `group_vars/hetzner/` - Hetzner-specific
3. `group_vars/wordpress_servers/` - WordPress-specific
4. `group_vars/monitoring_servers/` - Monitoring-specific
5. `group_vars/secrets_servers/` - OpenBao-specific
6. `host_vars/wordpress-prod.yml` - Highest precedence (host-specific)

## 📝 Usage Examples

### View All Hosts

```bash
ansible-inventory -i inventory/production.yml --graph
```

### View All Variables for a Host

```bash
ansible-inventory -i inventory/production.yml --host wordpress-prod
```

### List All Hosts in a Group

```bash
ansible-inventory -i inventory/production.yml --group wordpress_servers --list
```

### Validate Inventory

```bash
ansible-inventory -i inventory/production.yml --list
```

### Deploy to All Servers

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml
```

### Deploy Only WordPress

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml --limit wordpress_servers
```

### Deploy Only Monitoring

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml --limit monitoring_servers
```

## 🔐 Secrets Management

All secrets are stored in `group_vars/all/secrets.yml` and encrypted with Ansible Vault.

### Encrypt Secrets File

```bash
ansible-vault encrypt inventory/group_vars/all/secrets.yml
```

### Edit Encrypted Secrets

```bash
ansible-vault edit inventory/group_vars/all/secrets.yml
```

### Run Playbook with Vault

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml --ask-vault-pass
```

Or use a password file:

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml --vault-password-file ~/.vault_pass
```

## 🚀 Deployment Scenarios

This inventory supports flexible deployment topologies via variables:

### Scenario 1: All-in-One (1 server)

**Cost**: €9.40/month | **Capacity**: 100-200 students

Set these variables (CLI or extra vars file):

```yaml
wordpress_server_ip: "65.108.1.100"
openbao_server_ip: ""           # Empty = deploy on WordPress server
monitoring_server_ip: ""        # Empty = deploy on WordPress server
```

### Scenario 2: Separated (3 servers)

**Cost**: €28.20/month | **Capacity**: 500+ students

```yaml
wordpress_server_ip: "65.108.1.100"
openbao_server_ip: "65.108.1.101"
monitoring_server_ip: "65.108.1.102"
```

### Scenario 3: Hybrid (2 servers)

**Cost**: €18.80/month | **Capacity**: 300+ students

```yaml
wordpress_server_ip: "65.108.1.100"
openbao_server_ip: "65.108.1.101"
monitoring_server_ip: ""        # Deploy on WordPress server
```

## 📊 Variable Organization

Each service's variables are in dedicated files:

### WordPress Stack (`wordpress_servers/`)

- **wordpress.yml**: Core WordPress, LearnDash, plugins, theme
- **nginx.yml**: Web server, SSL, FastCGI cache, rate limiting
- **php.yml**: PHP-FPM, OpCache, extensions, limits
- **valkey.yml**: Object cache (Redis fork), WordPress integration
- **mariadb.yml**: Database config, performance tuning, backup

### Monitoring Stack (`monitoring_servers/`)

- **prometheus.yml**: Metrics collection, targets, retention
- **grafana.yml**: Dashboards, data sources, alerting
- **node_exporter.yml**: System metrics, custom collectors

### Secrets Stack (`secrets_servers/`)

- **openbao.yml**: Vault alternative, policies, auth methods

### Security (`hetzner/`)

- **security.yml**: SSH hardening, 2FA, firewall, fail2ban, AppArmor
- **system.yml**: Kernel parameters, sysctl hardening

## 🧪 Testing

### Syntax Check

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml --syntax-check
```

### Dry Run (Check Mode)

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml --check --diff
```

### Run on Single Host

```bash
ansible-playbook -i inventory/production.yml playbooks/site.yml --limit wordpress-prod
```

## 📚 References

- [Ansible Inventory Documentation](https://docs.ansible.com/ansible/latest/user_guide/intro_inventory.html)
- [Red Hat CoP Best Practices](https://redhat-cop.github.io/automation-good-practices/)
- [Ansible Variable Precedence](https://docs.ansible.com/ansible/latest/user_guide/playbooks_variables.html#variable-precedence-where-should-i-put-a-variable)

---

**Last Updated**: 2025-12-26
**Infrastructure Version**: v2.0
**Maintained By**: Infrastructure Team
