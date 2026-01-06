# Inventory Files Comparison

This project has TWO inventory files. Choose based on your workflow.

## 📋 Inventory Files

### 1. `production.yml` - Static Inventory ⭐ **RECOMMENDED**

**Current Default** in `ansible.cfg`

```yaml
wordpress_servers:
  hosts:
    wordpress-prod:
      ansible_host: "{{ wordpress_server_ip }}"
```

**Pros**:

- ✅ Simple and explicit
- ✅ No API token required
- ✅ Works immediately
- ✅ Full control over host names
- ✅ Compatible with all group_vars structure

**Cons**:

- ❌ Manual IP management
- ❌ Must update when adding/removing servers

**When to use**:

- Starting with infrastructure
- Fixed/known IPs
- Small deployments (<10 servers)
- No Terraform integration

**Usage**:

```bash
ansible-playbook playbooks/site.yml
# Uses production.yml by default (configured in ansible.cfg)
```

---

### 2. `hetzner.yml` - Dynamic Inventory

**Auto-discovery** from Hetzner Cloud API

```yaml
plugin: hetzner.hcloud.hcloud
token: "{{ lookup('env', 'HCLOUD_TOKEN') }}"
```

**Pros**:

- ✅ Auto-discovers servers from Hetzner API
- ✅ Syncs with Terraform state
- ✅ Auto-groups by labels
- ✅ No manual IP updates needed

**Cons**:

- ❌ Requires HCLOUD_TOKEN environment variable
- ❌ Requires `hcloud` Ansible collection
- ❌ Host names determined by Hetzner API
- ❌ More complex setup

**When to use**:

- Using Terraform to provision servers
- Many servers (10+)
- Frequent server changes
- Auto-scaling scenarios

**Setup**:

```bash
# 1. Install collection
ansible-galaxy collection install hetzner.hcloud

# 2. Set API token
export HCLOUD_TOKEN="your-token-here"

# 3. Test
ansible-inventory -i inventory/hetzner.yml --graph

# 4. Use
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml
```

---

## 🔄 Migration Path

### Phase 1: Manual (Current) ✅

```
production.yml → Fixed IPs → group_vars/
```

### Phase 2: Terraform + Dynamic (Future)

```
Terraform → Hetzner Cloud → hetzner.yml → group_vars/
```

---

## 🛠️ Switching Inventories

### Temporary Switch

```bash
# Use dynamic inventory for this playbook run
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml
```

### Permanent Switch

Edit `ansible.cfg`:

```ini
[defaults]
inventory = inventory/hetzner.yml  # Change from production.yml
```

---

## 📊 Feature Comparison

| Feature | production.yml | hetzner.yml |
|---------|---------------|-------------|
| **Setup complexity** | Low | Medium |
| **API token required** | No | Yes |
| **Auto-discovery** | No | Yes |
| **Terraform integration** | No | Yes |
| **IP management** | Manual | Automatic |
| **Host naming** | Custom | From Hetzner |
| **Group by labels** | Manual | Automatic |
| **Works offline** | Yes | No |
| **Current default** | ✅ Yes | No |

---

## 🎯 Recommendation

**Start with `production.yml`** (already configured):

1. ✅ Simpler to understand
2. ✅ No external dependencies
3. ✅ Works with all group_vars
4. ✅ Ready to use now

**Migrate to `hetzner.yml` when**:

1. You implement Terraform provisioning
2. You have 10+ servers
3. You need auto-scaling
4. IPs change frequently

---

## 📁 File Locations

```
inventory/
├── production.yml       ⭐ Current default (static)
├── hetzner.yml          Alternative (dynamic)
├── README.md            General inventory docs
├── README_INVENTORIES.md This file
└── group_vars/          Works with BOTH inventories
    ├── all/
    ├── hetzner/
    ├── wordpress_servers/
    ├── monitoring_servers/
    └── secrets_servers/
```

---

## 🧪 Testing Both

### Test Static Inventory

```bash
ansible-inventory -i inventory/production.yml --graph
```

### Test Dynamic Inventory

```bash
export HCLOUD_TOKEN="your-token"
ansible-inventory -i inventory/hetzner.yml --graph
```

---

**Current Configuration**: Using `production.yml` (recommended for initial deployment)
**Last Updated**: 2025-12-26
