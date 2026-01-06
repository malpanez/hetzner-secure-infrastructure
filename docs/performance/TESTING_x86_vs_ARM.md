# Architecture Testing Guide: x86 vs ARM

Quick reference for testing CX23 (x86) vs CAX11 (ARM) to decide production architecture.

---

## Current Status

✅ `terraform.staging.tfvars` configured with:

- Architecture: **x86 (CX23)** - ready for TEST 1
- API Token: Using "Default" Hetzner project
- SSH Key: Regular ED25519 (WSL2 compatible)

---

## Test Plan Overview

1. **TEST x86 (CX23)**: Deploy → Ansible → Benchmark → Document → Destroy
2. **TEST ARM (CAX11)**: Deploy → Ansible → Benchmark → Document → Destroy
3. **Compare & Decide**: Choose architecture for production

---

## TEST 1: x86 Cost-Optimized (CX23)

### Current Config

```hcl
architecture = "x86"    # CX series
server_size  = "small"  # cx23: 2 vCPU, 4GB RAM, €3.68/mo
location     = "nbg1"   # Nuremberg
```

### Step 1: Deploy Server

```bash
cd terraform
terraform init  # If first time
terraform plan -var-file=terraform.staging.tfvars
terraform apply -var-file=terraform.staging.tfvars
```

**Expected Output:**

```
server_type      = "cx23"
architecture     = "x86"
server_ipv4      = "X.X.X.X"
server_specs     = {
  cpu   = "2 vCPUs"
  ram   = "4 GB"
  disk  = "40 GB"
  price = "€3.68/month"
}
```

**If CX23 unavailable:**

```
Error: server type 'cx23' is not available in location 'nbg1'
```

→ Skip to TEST 2 (ARM)

### Step 2: Wait for Cloud-Init

```bash
# Get server IP from terraform output
SERVER_IP=$(terraform output -raw server_ipv4)

# Wait ~5 minutes for cloud-init to complete
ssh malpanez@$SERVER_IP "cloud-init status --wait"
```

### Step 3: Run Ansible

```bash
cd ../ansible

# Update inventory with server IP
# Edit ansible/inventory/staging.yml if needed

# Deploy full WordPress stack
ansible-playbook -i inventory/staging.yml playbooks/wordpress.yml
```

### Step 4: Validate WordPress

```bash
# Check HTTP response
curl -I http://$SERVER_IP

# Expected:
# HTTP/1.1 200 OK
# X-Powered-By: PHP/8.4

# Test WordPress installation
curl http://$SERVER_IP | grep -i wordpress
```

### Step 5: Benchmark

```bash
# Install Apache Bench if needed
sudo apt-get install apache2-utils -y

# Run benchmark (1000 requests, 10 concurrent)
ab -n 1000 -c 10 http://$SERVER_IP/ > ~/test_x86_benchmark.txt

# Check key metrics
cat ~/test_x86_benchmark.txt | grep -E "Requests per second|Time per request|Transfer rate"
```

**Example Output:**

```
Requests per second:    150.32 [#/sec] (mean)
Time per request:       66.53 [ms] (mean)
Time per request:       6.653 [ms] (mean, across all concurrent requests)
```

### Step 6: Check Logs & Resource Usage

```bash
ssh malpanez@$SERVER_IP

# CPU & RAM usage
htop  # Press q to exit

# Nginx logs
sudo tail -n 50 /var/log/nginx/access.log
sudo tail -n 50 /var/log/nginx/error.log

# PHP-FPM slow log
sudo tail -n 50 /var/log/php8.4-fpm.log

# MariaDB slow queries
sudo mysql -e "SELECT * FROM mysql.slow_log LIMIT 10;"

# Exit server
exit
```

### Step 7: Document Results

```bash
cat > ~/test_x86_results.txt <<EOF
=== x86 (CX23) Test Results ===
Date: $(date)
Server IP: $SERVER_IP

Deployment:
- Successfully deployed: YES/NO
- Deployment time: X minutes
- Cloud-init completion: X minutes

Ansible:
- Playbook execution: SUCCESS/FAIL
- Total time: X minutes

WordPress:
- Installation successful: YES/NO
- HTTP response: 200 OK
- PHP version: 8.4

Benchmark (ab -n 1000 -c 10):
- Requests per second: XXX [#/sec]
- Time per request (mean): XX.XX [ms]
- Failed requests: 0

Resource Usage:
- CPU idle: XX%
- RAM available: X.X GB / 4 GB
- Disk usage: XX GB / 40 GB

Issues:
- None / List any issues

Overall: PASS/FAIL
EOF

cat ~/test_x86_results.txt
```

### Step 8: Destroy

```bash
cd ../terraform
terraform destroy -var-file=terraform.staging.tfvars
```

---

## TEST 2: ARM (CAX11)

### Update Config

Edit `terraform/terraform.staging.tfvars`:

```hcl
# Comment out x86
# architecture = "x86"
# server_size  = "small"
# location     = "nbg1"

# Uncomment ARM
architecture = "arm"    # CAX series
server_size  = "small"  # cax11: 2 vCPU, 4GB RAM, €4.05/mo
location     = "fsn1"   # Falkenstein
```

### Repeat All Steps

Run same commands as TEST 1, but save results to `~/test_arm_results.txt`:

```bash
cd terraform
terraform apply -var-file=terraform.staging.tfvars
# ... (all same steps)
cat > ~/test_arm_results.txt <<EOF
=== ARM (CAX11) Test Results ===
# ... (same format as x86)
EOF
```

---

## Compare Results

```bash
# Side-by-side comparison
paste ~/test_x86_results.txt ~/test_arm_results.txt | column -t

# Key metrics to compare:
# 1. Availability: Did CX23 deploy successfully?
# 2. Performance: Requests/sec (higher is better)
# 3. Latency: Time per request (lower is better)
# 4. Compatibility: Any ARM-specific issues?
# 5. Cost: €3.68/mo (x86) vs €4.05/mo (ARM)
```

---

## Decision Matrix

| Criteria | x86 (CX23) | ARM (CAX11) | Winner |
|----------|------------|-------------|--------|
| **Availability** | Limited stock | Always available | ARM ✓ |
| **Cost** | €3.68/mo | €4.05/mo | x86 ✓ |
| **Performance** | ??? req/s | ??? req/s | TBD |
| **Latency** | ??? ms | ??? ms | TBD |
| **Compatibility** | 100% | 100% | Tie |

### Decision Rules

**Choose x86 (CX23) if:**

- ✅ CX23 deployed successfully (stock available)
- ✅ Performance similar to ARM (within 10%)
- ✅ No compatibility issues

**Choose ARM (CAX11) if:**

- ❌ CX23 stock unavailable
- ✅ Performance equal or better than x86
- ✅ Better long-term availability

**Default recommendation:** ARM (CAX11)

- Reason: Only €0.37/mo more expensive (€4.44/year)
- Always available (no stock issues)
- Modern ARM64 architecture

---

## Production Decision

After testing, update production config:

### If choosing x86 (CX23)

```hcl
# terraform.production.tfvars
architecture = "x86"
server_size  = "small"  # cx23: €3.68/mo
location     = "nbg1"
```

### If choosing ARM (CAX11)

```hcl
# terraform.production.tfvars
architecture = "arm"
server_size  = "small"  # cax11: €4.05/mo
location     = "fsn1"
```

---

## Next Steps After Testing

1. ✅ Destroy staging: `terraform destroy -var-file=terraform.staging.tfvars`
2. ⏳ Create `terraform.production.tfvars` with chosen architecture
3. ⏳ Deploy production
4. ⏳ Configure monitoring (Prometheus + Grafana)
5. ⏳ Migrate DNS to Cloudflare
6. ⏳ Setup SSL/TLS with Let's Encrypt

---

## Troubleshooting

### CX23 not available

```
Error: server type 'cx23' is not available in location 'nbg1'
```

→ Normal, limited stock. Skip to ARM test.

### Ansible connection timeout

```bash
# Check if cloud-init finished
ssh malpanez@$SERVER_IP "cloud-init status"

# If still running, wait:
ssh malpanez@$SERVER_IP "cloud-init status --wait"
```

### WordPress not responding

```bash
# Check Nginx status
ssh malpanez@$SERVER_IP "sudo systemctl status nginx"

# Check PHP-FPM status
ssh malpanez@$SERVER_IP "sudo systemctl status php8.4-fpm"

# Check MariaDB status
ssh malpanez@$SERVER_IP "sudo systemctl status mariadb"
```

---

## Quick Command Reference

```bash
# Deploy
cd terraform && terraform apply -var-file=terraform.staging.tfvars

# Get IP
SERVER_IP=$(terraform output -raw server_ipv4)

# Run Ansible
cd ../ansible && ansible-playbook -i inventory/staging.yml playbooks/wordpress.yml

# Benchmark
ab -n 1000 -c 10 http://$SERVER_IP/

# Destroy
cd ../terraform && terraform destroy -var-file=terraform.staging.tfvars
```

---

Ready to start? Run:

```bash
cd /home/malpanez/repos/hetzner-secure-infrastructure/terraform
terraform plan -var-file=terraform.staging.tfvars
```
