# Testing & Disaster Recovery Strategy

## 🎯 Objectives

1. **Infrastructure Testing**: Terratest validates Terraform code
2. **Configuration Testing**: Molecule validates Ansible roles
3. **Disaster Recovery**: Rebuild entire stack in <30 minutes
4. **Plugin Auto-Install**: WordPress plugins installed automatically
5. **Backup & Restore**: Automated backups with restore procedures

---

## 🧪 Testing Strategy

### 1. Infrastructure Testing (Terratest)

**Purpose**: Validate Terraform creates correct infrastructure

**What to test**:

- ✅ Servers created with correct specs
- ✅ Firewall rules applied
- ✅ SSH keys configured
- ✅ Labels set correctly for Ansible discovery
- ✅ Outputs generated (IPs, hostnames)

**Location**: `terraform/test/`

**Example Test**:

```go
// terraform/test/infrastructure_test.go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
    "github.com/stretchr/testify/assert"
)

func TestTerraformInfrastructure(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../environments/production",
        Vars: map[string]interface{}{
            "deploy_monitoring_server": false,
            "deploy_openbao_server": false,
        },
    }

    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)

    // Test server type
    serverType := terraform.Output(t, terraformOptions, "wordpress_server_type")
    assert.Equal(t, "cx21", serverType)

    // Test server created
    ipv4 := terraform.Output(t, terraformOptions, "wordpress_ipv4")
    assert.NotEmpty(t, ipv4)

    // Test labels
    labels := terraform.OutputMap(t, terraformOptions, "wordpress_labels")
    assert.Equal(t, "production", labels["environment"])
    assert.Equal(t, "wordpress", labels["role"])
}
```

**Run tests**:

```bash
cd terraform/test
go test -v -timeout 30m
```

---

### 2. Ansible Role Testing (Molecule)

**Purpose**: Validate Ansible roles work correctly

**Existing tests** (already configured):

- ✅ `common` role
- ✅ `security-hardening` role

**Need to add**:

- ⚠️ `nginx-wordpress` role
- ⚠️ `valkey` role (renamed from redis)
- ⚠️ `prometheus` role
- ⚠️ `grafana` role

**Molecule Test Structure**:

```
ansible/roles/nginx-wordpress/
├── molecule/
│   └── default/
│       ├── molecule.yml       # Molecule config
│       ├── converge.yml       # Apply role
│       ├── verify.yml         # Test assertions
│       └── prepare.yml        # Pre-requisites
```

**Example Verify** (nginx-wordpress):

```yaml
# ansible/roles/nginx-wordpress/molecule/default/verify.yml
---
- name: Verify nginx-wordpress role
  hosts: all
  tasks:
    - name: Check Nginx is installed
      ansible.builtin.package:
        name: nginx
        state: present
      check_mode: yes
      register: nginx_installed
      failed_when: nginx_installed.changed

    - name: Check Nginx is running
      ansible.builtin.service:
        name: nginx
        state: started
      check_mode: yes
      register: nginx_running
      failed_when: nginx_running.changed

    - name: Check FastCGI cache directory exists
      ansible.builtin.stat:
        path: /var/run/nginx-cache
      register: cache_dir
      failed_when: not cache_dir.stat.exists

    - name: Check PHP-FPM socket exists
      ansible.builtin.stat:
        path: /run/php/php8.3-fpm.sock
      register: php_socket
      failed_when: not php_socket.stat.exists

    - name: Test Nginx config syntax
      ansible.builtin.command: nginx -t
      changed_when: false
```

**Run Molecule tests**:

```bash
# Test single role
cd ansible/roles/nginx-wordpress
molecule test

# Test all roles
cd ansible/roles
for role in */; do
    if [ -d "$role/molecule" ]; then
        echo "Testing $role..."
        (cd "$role" && molecule test)
    fi
done
```

---

## 🔄 Disaster Recovery Plan

### Scenario: Complete Server Loss

**Recovery Time Objective (RTO)**: 30 minutes
**Recovery Point Objective (RPO)**: 24 hours (daily backups)

### Prerequisites (Always Ready)

1. **Backups stored off-server**:
   - Database: S3/Backblaze B2
   - WordPress uploads: S3/Backblaze B2
   - Configuration: Git repository

2. **Credentials available**:
   - Hetzner Cloud API token
   - Ansible Vault password
   - Cloudflare API token
   - LearnDash license key

3. **DNS ready to update**:
   - Cloudflare account access
   - Domain registrar access

---

### DR Procedure (Step-by-Step)

#### Phase 1: Provision New Infrastructure (5 min)

```bash
# 1. Set environment
export HCLOUD_TOKEN="your-token"
export TF_VAR_hcloud_token="${HCLOUD_TOKEN}"

# 2. Provision with Terraform
cd terraform/environments/production
terraform init
terraform apply -auto-approve \
  -var="deploy_monitoring_server=false" \
  -var="deploy_openbao_server=false"

# 3. Get new server IP
NEW_IP=$(terraform output -raw wordpress_ipv4)
echo "New WordPress IP: ${NEW_IP}"
```

#### Phase 2: Configure Server with Ansible (15 min)

```bash
# 4. Wait for server to be ready
while ! ssh -o ConnectTimeout=5 admin@${NEW_IP} "echo OK" 2>/dev/null; do
    echo "Waiting for server..."
    sleep 10
done

# 5. Run Ansible configuration
cd ../../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml \
  --ask-vault-pass \
  --limit wordpress_servers

# This automatically installs:
# - Nginx + FastCGI cache
# - PHP 8.3 + OpCache
# - MariaDB
# - Valkey object cache
# - WordPress core
# - Redis Object Cache plugin
# - Nginx Helper plugin
# - Cloudflare plugin
# - LearnDash Pro (if license configured)
```

#### Phase 3: Restore Data (10 min)

```bash
# 6. Restore database
scp latest-backup.sql admin@${NEW_IP}:/tmp/
ssh admin@${NEW_IP} "mysql wordpress < /tmp/latest-backup.sql"

# 7. Restore wp-content/uploads
rsync -avz backup/uploads/ admin@${NEW_IP}:/var/www/domain.com/wp-content/uploads/

# 8. Configure wp-config.php secrets (if not in Ansible Vault)
ssh admin@${NEW_IP}
# Edit wp-config.php with database credentials
```

#### Phase 4: Update DNS (Immediate)

```bash
# 9. Update Cloudflare DNS
# Option A: Via dashboard
# Cloudflare → DNS → Edit A record → Point to ${NEW_IP}

# Option B: Via API
curl -X PUT "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/dns_records/${RECORD_ID}" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data "{\"type\":\"A\",\"name\":\"@\",\"content\":\"${NEW_IP}\",\"proxied\":true}"

# 10. Purge Cloudflare cache
curl -X POST "https://api.cloudflare.com/client/v4/zones/${ZONE_ID}/purge_cache" \
  -H "Authorization: Bearer ${CF_API_TOKEN}" \
  -H "Content-Type: application/json" \
  --data '{"purge_everything":true}'
```

#### Phase 5: Verification (5 min)

```bash
# 11. Test site
curl -I https://yourdomain.com
# Should return 200 OK

# 12. Test WordPress admin
curl -I https://yourdomain.com/wp-admin
# Should redirect to login

# 13. Login and verify
# - Check LearnDash courses exist
# - Check students can access content
# - Check enrollment data preserved

# 14. Test caching
curl -I https://yourdomain.com
# Look for: X-Cache-Status: HIT (after 2nd request)
```

**Total Time**: ~30 minutes ✅

---

## 🔌 WordPress Plugin Auto-Installation

### Current Implementation

**Ansible WordPress Role** automatically installs plugins via WP-CLI:

```yaml
# ansible/roles/nginx-wordpress/tasks/wordpress.yml
- name: Install WordPress plugins
  community.general.wordpress_plugin:
    name: "{{ item.slug }}"
    state: "{{ item.state }}"
  loop: "{{ wordpress_plugins }}"
  when: wordpress_plugins is defined
```

### Plugins Installed Automatically

From `inventory/group_vars/wordpress_servers/wordpress.yml`:

```yaml
wordpress_plugins:
  - slug: redis-cache        # ✅ Auto-installed
  - slug: nginx-helper       # ✅ Auto-installed
  - slug: cloudflare         # ✅ Auto-installed
```

### LearnDash Pro Installation

**Challenge**: LearnDash Pro is not in WordPress.org repository (paid plugin)

**Solution 1**: Manual upload (one-time)

```yaml
# ansible/roles/nginx-wordpress/tasks/learndash.yml
- name: Upload LearnDash Pro zip
  ansible.builtin.copy:
    src: "{{ learndash_zip_path }}"
    dest: /tmp/learndash.zip

- name: Install LearnDash Pro
  ansible.builtin.command:
    cmd: wp plugin install /tmp/learndash.zip --activate
    chdir: "{{ wordpress_root }}"
  become_user: www-data
```

**Solution 2**: Download from secure storage (recommended for DR)

```yaml
- name: Download LearnDash from S3
  amazon.aws.s3_object:
    bucket: my-wordpress-backups
    object: /licenses/learndash-pro-latest.zip
    dest: /tmp/learndash.zip
    mode: get

- name: Install LearnDash
  ansible.builtin.command:
    cmd: wp plugin install /tmp/learndash.zip --activate
```

**Solution 3**: Version-controlled (best for DR)

```bash
# Store in private Git repository
git clone https://github.com/yourorg/wordpress-premium-plugins.git
cd wordpress-premium-plugins
# Contains: learndash/, elementor-pro/, etc.
```

```yaml
- name: Clone premium plugins repository
  ansible.builtin.git:
    repo: git@github.com:yourorg/wordpress-premium-plugins.git
    dest: /tmp/premium-plugins
    version: main

- name: Install LearnDash from repository
  ansible.builtin.command:
    cmd: wp plugin install /tmp/premium-plugins/learndash --activate
```

---

## 💾 Automated Backup Strategy

### What to Backup

1. **Database** (critical - daily):
   - WordPress database
   - User data
   - Course progress
   - Enrollments

2. **Uploads** (important - daily):
   - wp-content/uploads/
   - Course materials
   - User-uploaded content
   - Certificates

3. **Configuration** (critical - in Git):
   - Ansible playbooks ✅
   - Terraform configs ✅
   - nginx configs (via Ansible) ✅
   - wp-config.php secrets (in Vault) ✅

4. **Plugin/Theme customizations** (important - in Git or backup):
   - Custom themes
   - Premium plugins (LearnDash)
   - Child theme modifications

### Backup Implementation

**Ansible Backup Role** (`ansible/roles/backup/`):

```yaml
# ansible/roles/backup/tasks/main.yml
---
- name: Install backup dependencies
  ansible.builtin.package:
    name:
      - awscli  # or rclone for Backblaze B2
      - mariadb-client
    state: present

- name: Create backup script
  ansible.builtin.template:
    src: backup-wordpress.sh.j2
    dest: /usr/local/bin/backup-wordpress
    mode: '0750'

- name: Schedule daily backups
  ansible.builtin.cron:
    name: "WordPress daily backup"
    minute: "0"
    hour: "2"
    job: "/usr/local/bin/backup-wordpress"
    user: root
```

**Backup Script** (`ansible/roles/backup/templates/backup-wordpress.sh.j2`):

```bash
#!/bin/bash
# Automated WordPress backup to S3/B2

set -e

BACKUP_DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/backups/wordpress"
S3_BUCKET="{{ backup_s3_bucket }}"
DB_NAME="{{ wordpress_db_name }}"
WP_ROOT="{{ wordpress_root }}"

# Create backup directory
mkdir -p "${BACKUP_DIR}"

# 1. Backup database
mysqldump "${DB_NAME}" | gzip > "${BACKUP_DIR}/db-${BACKUP_DATE}.sql.gz"

# 2. Backup uploads
tar -czf "${BACKUP_DIR}/uploads-${BACKUP_DATE}.tar.gz" \
    -C "${WP_ROOT}" wp-content/uploads

# 3. Upload to S3/B2
aws s3 cp "${BACKUP_DIR}/db-${BACKUP_DATE}.sql.gz" \
    "s3://${S3_BUCKET}/wordpress/db/"

aws s3 cp "${BACKUP_DIR}/uploads-${BACKUP_DATE}.tar.gz" \
    "s3://${S3_BUCKET}/wordpress/uploads/"

# 4. Cleanup local backups (keep 7 days)
find "${BACKUP_DIR}" -type f -mtime +7 -delete

# 5. Cleanup S3 backups (keep 30 days)
aws s3 ls "s3://${S3_BUCKET}/wordpress/db/" | \
    awk '{print $4}' | \
    head -n -30 | \
    xargs -I {} aws s3 rm "s3://${S3_BUCKET}/wordpress/db/{}"
```

---

## 🧪 Complete Testing Workflow

### Pre-Deployment Testing

```bash
# 1. Test Terraform syntax
cd terraform/environments/production
terraform fmt -check
terraform validate

# 2. Run Terratest
cd ../../test
go test -v -timeout 30m

# 3. Test Ansible syntax
cd ../../ansible
ansible-playbook playbooks/site.yml --syntax-check

# 4. Test Ansible roles with Molecule
cd roles
for role in nginx-wordpress valkey prometheus grafana; do
    cd $role
    molecule test
    cd ..
done

# 5. Dry-run Ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml --check
```

### Post-Deployment Validation

```bash
# 6. Infrastructure tests
./scripts/test-infrastructure.sh

# 7. Application tests
./scripts/test-wordpress.sh

# 8. Performance tests
./scripts/test-performance.sh
```

---

## 📋 DR Checklist

### Monthly (Preparation)

- [ ] Test backup restore procedure
- [ ] Verify all credentials accessible
- [ ] Update DR documentation
- [ ] Review RTO/RPO targets

### Quarterly (Validation)

- [ ] Full DR drill (complete rebuild)
- [ ] Time the recovery process
- [ ] Update procedures based on learnings

### After Every Major Change

- [ ] Update Terraform configs in Git
- [ ] Update Ansible playbooks in Git
- [ ] Test deployment from scratch
- [ ] Document new dependencies

---

## ⚡ Quick Recovery Commands

### Emergency Rebuild (All-in-One)

```bash
#!/bin/bash
# emergency-rebuild.sh

export HCLOUD_TOKEN="your-token"

# 1. Provision (5 min)
cd terraform/environments/production
terraform apply -auto-approve
NEW_IP=$(terraform output -raw wordpress_ipv4)

# 2. Configure (15 min)
cd ../../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml \
  --limit wordpress_servers

# 3. Restore data (10 min)
./scripts/restore-from-backup.sh latest

# 4. Update DNS
./scripts/update-cloudflare-dns.sh ${NEW_IP}

echo "✅ Recovery complete! New IP: ${NEW_IP}"
```

Make executable:

```bash
chmod +x emergency-rebuild.sh
```

---

## 📊 Testing Coverage Goals

| Component | Test Type | Coverage | Status |
|-----------|-----------|----------|--------|
| Terraform | Terratest | 80%+ | ⚠️ To implement |
| Ansible roles | Molecule | 80%+ | ⚠️ Partial (2/7 roles) |
| WordPress plugins | Auto-install | 100% | ✅ Complete |
| Backup/Restore | Integration test | 100% | ⚠️ To implement |
| DR procedure | Manual drill | Quarterly | ⚠️ To schedule |

---

**Last Updated**: 2026-01-09
**Next Review**: Monthly
**DR Drill Schedule**: Quarterly
