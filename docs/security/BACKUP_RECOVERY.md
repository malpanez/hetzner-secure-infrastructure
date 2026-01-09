# Backup and Disaster Recovery

> **Comprehensive backup strategy and disaster recovery procedures**

## Table of Contents

- [Backup Strategy](#backup-strategy)
- [Backup Tools](#backup-tools)
- [Automated Backups](#automated-backups)
- [Backup Verification](#backup-verification)
- [Disaster Recovery](#disaster-recovery)
- [RTO and RPO](#rto-and-rpo)
- [Testing Procedures](#testing-procedures)

---

## Backup Strategy

### Backup Types

1. **Infrastructure as Code (IaC) Backups**
   - Terraform state files
   - Ansible inventory and configurations
   - All infrastructure code in Git

2. **System Configuration Backups**
   - `/etc` directory
   - System service configurations
   - User home directories
   - SSH keys and certificates

3. **Application Data Backups**
   - Application databases
   - User-uploaded files
   - Application state

4. **Log Backups**
   - System logs
   - Application logs
   - Audit logs

### Backup Frequency

| Backup Type | Frequency | Retention | Storage Location |
|-------------|-----------|-----------|------------------|
| IaC Code | Real-time (Git) | Indefinite | Codeberg + local |
| System Config | Daily | 30 days | Restic/Remote |
| Application Data | Hourly | 7 days, weekly for 4 weeks | Restic/S3 |
| Logs | Daily | 90 days | Remote logging |
| Full System | Weekly | 4 weeks | Hetzner Snapshots |

---

## Backup Tools

### Recommended: Restic

**Why Restic?**

- Encrypted backups
- Deduplication
- Incremental backups
- Multiple storage backends
- Open source and actively maintained

**Installation:**

```bash
# Install Restic
sudo apt update
sudo apt install restic

# Verify installation
restic version
```

### Alternative: Hetzner Cloud Backups

**Features:**

- Automated weekly snapshots
- 7 daily backups retained
- Managed by Hetzner
- Simple activation

**Enable via Terraform:**

```hcl
resource "hcloud_server" "server" {
  # ...
  backups = true  # Enable automatic backups
}
```

**Cost:** ~20% of server price per month

---

## Automated Backups

### Restic Backup Configuration

**1. Initialize Restic Repository:**

```bash
# Set environment variables
export RESTIC_REPOSITORY="s3:s3.amazonaws.com/your-backup-bucket"
export RESTIC_PASSWORD="your-secure-password"  # Store in vault!
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"

# Initialize repository (first time only)
restic init

# Alternative: Local backup
export RESTIC_REPOSITORY="/mnt/backup"
restic init
```

**2. Create Backup Script:**

```bash
#!/bin/bash
# /usr/local/bin/backup-system.sh
# Automated system backup using Restic

set -euo pipefail

# Configuration
RESTIC_REPO="${RESTIC_REPOSITORY:-/mnt/backup}"
RESTIC_PASSWORD_FILE="/root/.restic-password"
BACKUP_PATHS=(
    "/etc"
    "/home"
    "/root"
    "/var/log"
    "/usr/local/bin"
)
EXCLUDE_PATTERNS=(
    "*.tmp"
    "*.cache"
    "/home/*/.cache"
    "/var/log/*.gz"
)
LOG_FILE="/var/log/backup.log"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

# Load environment
if [ -f /etc/default/backup ]; then
    source /etc/default/backup
fi

# Pre-backup checks
log "Starting backup process"

# Check if repository is accessible
if ! restic -r "$RESTIC_REPO" -p "$RESTIC_PASSWORD_FILE" snapshots &>/dev/null; then
    log "ERROR: Cannot access repository"
    exit 1
fi

# Create backup
log "Creating backup..."
restic -r "$RESTIC_REPO" -p "$RESTIC_PASSWORD_FILE" backup \
    "${BACKUP_PATHS[@]}" \
    --exclude-file=<(printf '%s\n' "${EXCLUDE_PATTERNS[@]}") \
    --tag "$(hostname)" \
    --tag "automated" \
    --verbose 2>&1 | tee -a "$LOG_FILE"

# Verify latest backup
log "Verifying backup..."
restic -r "$RESTIC_REPO" -p "$RESTIC_PASSWORD_FILE" check --read-data-subset=5% \
    2>&1 | tee -a "$LOG_FILE"

# Cleanup old backups (keep policy)
log "Pruning old backups..."
restic -r "$RESTIC_REPO" -p "$RESTIC_PASSWORD_FILE" forget \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 12 \
    --tag "automated" \
    --prune \
    2>&1 | tee -a "$LOG_FILE"

log "Backup completed successfully"

# Send notification (optional)
# curl -X POST https://your-monitoring-endpoint \
#     -d "Backup completed on $(hostname)"
```

**3. Make Script Executable:**

```bash
sudo chmod +x /usr/local/bin/backup-system.sh
```

**4. Create Cron Job:**

```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * /usr/local/bin/backup-system.sh >> /var/log/backup-cron.log 2>&1

# Or hourly for critical data
0 * * * * /usr/local/bin/backup-critical-data.sh >> /var/log/backup-cron.log 2>&1
```

### Ansible Playbook for Backup Setup

```yaml
---
# ansible/playbooks/setup-backups.yml

- name: Setup automated backups
  hosts: all
  become: yes

  vars:
    restic_version: "0.16.2"
    restic_repository: "{{ lookup('env', 'RESTIC_REPOSITORY') }}"
    restic_password: "{{ lookup('env', 'RESTIC_PASSWORD') }}"

  tasks:
    - name: Install Restic
      ansible.builtin.apt:
        name: restic
        state: present
        update_cache: yes

    - name: Create Restic password file
      ansible.builtin.copy:
        content: "{{ restic_password }}"
        dest: /root/.restic-password
        owner: root
        group: root
        mode: '0600'
      no_log: yes

    - name: Create backup configuration
      ansible.builtin.template:
        src: templates/backup-config.j2
        dest: /etc/default/backup
        owner: root
        group: root
        mode: '0600'

    - name: Deploy backup script
      ansible.builtin.copy:
        src: files/backup-system.sh
        dest: /usr/local/bin/backup-system.sh
        owner: root
        group: root
        mode: '0755'

    - name: Create backup cron job
      ansible.builtin.cron:
        name: "Daily system backup"
        minute: "0"
        hour: "2"
        job: "/usr/local/bin/backup-system.sh >> /var/log/backup-cron.log 2>&1"
        user: root

    - name: Initialize Restic repository
      ansible.builtin.command:
        cmd: restic -r {{ restic_repository }} -p /root/.restic-password init
      environment:
        RESTIC_REPOSITORY: "{{ restic_repository }}"
      register: restic_init
      failed_when: restic_init.rc != 0 and 'already initialized' not in restic_init.stderr
      changed_when: "'created restic repository' in restic_init.stdout"
```

---

## Backup Verification

### Manual Verification

**List Backups:**

```bash
restic -r $RESTIC_REPOSITORY snapshots
```

**Verify Backup Integrity:**

```bash
# Quick check
restic -r $RESTIC_REPOSITORY check

# Full data verification (slow)
restic -r $RESTIC_REPOSITORY check --read-data
```

**Browse Backup Contents:**

```bash
# List files in latest snapshot
restic -r $RESTIC_REPOSITORY ls latest

# Mount backup as filesystem
mkdir /mnt/restic
restic -r $RESTIC_REPOSITORY mount /mnt/restic
# Browse files, then unmount:
umount /mnt/restic
```

### Automated Verification

**Create Verification Script:**

```bash
#!/bin/bash
# /usr/local/bin/verify-backups.sh

set -euo pipefail

RESTIC_REPO="${RESTIC_REPOSITORY:-/mnt/backup}"
RESTIC_PASSWORD_FILE="/root/.restic-password"
LOG_FILE="/var/log/backup-verification.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

log "Starting backup verification"

# Check repository integrity
if restic -r "$RESTIC_REPO" -p "$RESTIC_PASSWORD_FILE" check --read-data-subset=10%; then
    log "SUCCESS: Backup verification passed"
    exit 0
else
    log "ERROR: Backup verification failed"
    # Send alert
    curl -X POST https://your-alert-endpoint -d "Backup verification failed on $(hostname)"
    exit 1
fi
```

**Schedule Weekly Verification:**

```bash
sudo crontab -e

# Add weekly verification on Sundays at 4 AM
0 4 * * 0 /usr/local/bin/verify-backups.sh >> /var/log/backup-verification.log 2>&1
```

---

## Disaster Recovery

### Recovery Scenarios

#### Scenario 1: File Restoration

**Restore Specific File:**

```bash
# Find the file
restic -r $RESTIC_REPOSITORY find "sshd_config"

# Restore to original location
restic -r $RESTIC_REPOSITORY restore latest --target / --include /etc/ssh/sshd_config

# Or restore to temporary location
restic -r $RESTIC_REPOSITORY restore latest --target /tmp/restore --include /etc/ssh/sshd_config
```

#### Scenario 2: Full System Recovery

**Step 1: Deploy New Server**

```bash
cd terraform/environments/production
tofu apply
```

**Step 2: Restore System Configuration**

```bash
# SSH to new server
ssh user@new-server-ip

# Install Restic
sudo apt update && sudo apt install restic

# Restore /etc
sudo restic -r $RESTIC_REPOSITORY restore latest --target / --include /etc

# Restore home directories
sudo restic -r $RESTIC_REPOSITORY restore latest --target / --include /home

# Restore custom scripts
sudo restic -r $RESTIC_REPOSITORY restore latest --target / --include /usr/local/bin
```

**Step 3: Re-run Ansible**

```bash
cd ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml
```

**Step 4: Reconfigure 2FA**

```bash
ssh user@new-server-ip
sudo /usr/local/bin/setup-2fa-yubikey.sh $USER
```

#### Scenario 3: Infrastructure Rebuild

**Complete Disaster Recovery:**

```bash
# 1. Clone repository
git clone https://codeberg.org/malpanez/twomindstrading_hetzner.git
cd twomindstrading_hetzner

# 2. Deploy infrastructure
cd terraform/environments/production
tofu init
tofu apply

# 3. Run Ansible hardening
cd ../../../ansible
ansible-playbook -i inventory/hetzner.yml playbooks/site.yml

# 4. Restore application data
ssh user@server-ip
sudo restic -r $RESTIC_REPOSITORY restore latest --target /
```

---

## RTO and RPO

### Service Level Objectives

| Scenario | RTO (Recovery Time Objective) | RPO (Recovery Point Objective) |
|----------|-------------------------------|-------------------------------|
| File corruption | < 15 minutes | Last backup (daily) |
| Server failure | < 2 hours | Last backup (24 hours) |
| Complete infrastructure loss | < 4 hours | Last backup (24 hours) |
| Data center outage | < 8 hours | Last backup (24 hours) |

### RTO Optimization Strategies

1. **Faster Server Deployment**
   - Use Terraform Cloud for faster state operations
   - Pre-built server images with Packer
   - Automated deployment pipelines

2. **Backup Accessibility**
   - Multiple backup storage locations
   - Fast restore paths (SSD-backed storage)
   - Parallel restoration

3. **Documentation**
   - Updated recovery runbooks
   - Automated recovery scripts
   - Regular DR drills

---

## Testing Procedures

### Monthly DR Drill

**Objective:** Verify backup and recovery procedures work correctly.

**Procedure:**

```bash
#!/bin/bash
# DR Drill Script

echo "=== Disaster Recovery Drill ==="
echo "Date: $(date)"

# 1. Create test server
echo "1. Creating test server..."
cd terraform/environments/staging
tofu apply -auto-approve

# 2. Restore latest backup
echo "2. Restoring backup..."
ssh staging-server "sudo restic -r $RESTIC_REPOSITORY restore latest --target /tmp/restore"

# 3. Verify critical files
echo "3. Verifying files..."
ssh staging-server "test -f /tmp/restore/etc/ssh/sshd_config && echo 'SSH config OK'"
ssh staging-server "test -d /tmp/restore/home && echo 'Home directories OK'"

# 4. Measure restore time
RESTORE_TIME=$(ssh staging-server "cat /var/log/backup.log | grep 'Restore completed' | tail -1")
echo "Restore completed in: $RESTORE_TIME"

# 5. Cleanup
echo "5. Cleaning up test server..."
tofu destroy -auto-approve

echo "=== DR Drill Completed ==="
```

### Quarterly Full Recovery Test

1. **Week 1:** Plan and schedule
2. **Week 2:** Execute DR test in staging
3. **Week 3:** Document findings and improvements
4. **Week 4:** Update runbooks and procedures

---

## Backup Best Practices

### Security

- [ ] Encrypt all backups
- [ ] Store encryption keys securely (separate from backups)
- [ ] Use strong, unique passwords for backup repositories
- [ ] Implement multi-factor authentication for backup access
- [ ] Regular security audits of backup access logs

### Reliability

- [ ] Follow 3-2-1 rule: 3 copies, 2 different media, 1 offsite
- [ ] Test restore procedures monthly
- [ ] Monitor backup success/failure
- [ ] Alert on backup failures
- [ ] Verify backup integrity weekly

### Compliance

- [ ] Document retention policies
- [ ] Implement data classification
- [ ] Secure deletion of expired backups
- [ ] Audit backup access
- [ ] Compliance with GDPR/regulations

---

## Monitoring Backup Health

### Prometheus Metrics

```yaml
# /etc/prometheus/backup-exporter.yml
- job_name: 'backup-metrics'
  static_configs:
    - targets: ['localhost:9101']
  metrics_path: /metrics
```

### Alert Rules

```yaml
# Alert on backup failure
- alert: BackupFailed
  expr: backup_last_success > 86400  # 24 hours
  for: 1h
  annotations:
    summary: "Backup has not succeeded in 24 hours"
```

---

## Recovery Checklist

**Pre-Recovery:**

- [ ] Identify recovery scope (file, system, infrastructure)
- [ ] Verify backup integrity
- [ ] Prepare target environment
- [ ] Notify stakeholders

**During Recovery:**

- [ ] Document start time
- [ ] Follow runbook procedures
- [ ] Verify each restoration step
- [ ] Monitor for errors

**Post-Recovery:**

- [ ] Verify system functionality
- [ ] Check application data integrity
- [ ] Reconfigure services (2FA, etc.)
- [ ] Document lessons learned
- [ ] Update runbooks if needed

---

**Document Version:** 1.0.0
**Last Updated:** 2026-01-09
**Next Review:** 2026-03-25
**Owner:** DevOps Team
