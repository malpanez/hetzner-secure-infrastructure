# Grafana Alerts and Troubleshooting Guide

> **Complete guide for understanding and resolving Grafana/Prometheus alerts**

## Table of Contents

- [Understanding the Monitoring Stack](#understanding-the-monitoring-stack)
- [Common Alerts and Resolutions](#common-alerts-and-resolutions)
- [Node Exporter Metrics Explained](#node-exporter-metrics-explained)
- [Accessing Grafana](#accessing-grafana)
- [Dashboard Overview](#dashboard-overview)
- [Alert States](#alert-states)
- [Troubleshooting Workflows](#troubleshooting-workflows)
- [Performance Metrics Reference](#performance-metrics-reference)

---

## Understanding the Monitoring Stack

### Components Deployed

Our staging environment uses an **all-in-one deployment** with:

| Component | Port | Purpose | Bind Address |
|-----------|------|---------|--------------|
| **Prometheus** | 9090 | Metrics collection and storage | 127.0.0.1 (localhost) |
| **Grafana** | 3000 | Visualization and dashboards | 127.0.0.1 (localhost) |
| **Loki** | 3100 | Log aggregation | 127.0.0.1 (localhost) |
| **Promtail** | - | Log shipper | - |
| **Node Exporter** | 9100 | System metrics exporter | 0.0.0.0 (all interfaces) |

**Security Note**: Prometheus, Grafana, and Loki are bound to localhost only and accessed via:
- SSH tunnel (recommended for development)
- Nginx reverse proxy (for production with subdomains)

---

## Accessing Grafana

### Method 1: SSH Tunnel (Recommended for Development)

```bash
# Create SSH tunnel for Grafana and Prometheus
ssh -L 3000:localhost:3000 -L 9090:localhost:9090 malpanez@46.224.156.140

# Access in browser:
# - Grafana: http://localhost:3000
# - Prometheus: http://localhost:9090
```

### Method 2: Nginx Reverse Proxy (Production)

If DNS is configured:
- Grafana: `http://grafana.yourdomain.com`
- Prometheus: `http://prometheus.yourdomain.com`

### Login Credentials

```
Username: admin
Password: CHANGE_ME_STRONG_PASSWORD_32_CHARS_MIN
```

**Important**: Change default password on first login!

---

## Dashboard Overview

### Installed Dashboards

We have 2 pre-configured dashboards from Grafana.com:

#### 1. Node Exporter Full (Dashboard #1860)

**Purpose**: Comprehensive system metrics visualization

**Key Panels**:
- CPU usage (system, user, iowait)
- Memory usage (used, free, cached, buffers)
- Disk I/O (read/write rates)
- Network traffic (rx/tx)
- Load averages (1m, 5m, 15m)
- Filesystem usage
- System uptime

**Best for**: Day-to-day operations and capacity planning

#### 2. Prometheus Stats (Dashboard #3662)

**Purpose**: Monitor Prometheus itself (self-monitoring)

**Key Panels**:
- Scrape duration
- Sample ingestion rate
- Memory usage
- Storage size
- Target status (UP/DOWN)

**Best for**: Ensuring monitoring stack health

---

## Common Alerts and Resolutions

### 🔴 High CPU Usage

**Alert Trigger**: CPU usage > 80% for 5 minutes

**Symptoms**:
- Slow response times
- High load averages
- Dashboard shows red CPU panel

**Investigation Steps**:

1. **Check current processes**
   ```bash
   ssh malpanez@46.224.156.140
   top -o %CPU
   # Press 'q' to quit
   ```

2. **Identify the culprit**
   ```bash
   ps aux | sort -rk 3 | head -10
   ```

3. **Check WordPress/PHP-FPM**
   ```bash
   systemctl status php8.2-fpm
   journalctl -u php8.2-fpm -n 50 --no-pager
   ```

**Common Causes and Fixes**:

| Cause | Resolution |
|-------|------------|
| **High traffic** | Scale horizontally (add servers) or vertically (upgrade server type) |
| **Slow DB queries** | Optimize WordPress queries, enable object cache (Valkey) |
| **Plugin issues** | Disable suspicious plugins, check plugin compatibility |
| **Cron jobs** | Check `/var/log/cron.log`, optimize scheduled tasks |
| **DDoS attack** | Check Cloudflare analytics, enable rate limiting |

**Quick Fix for WordPress**:
```bash
# Restart PHP-FPM to clear worker pool
sudo systemctl restart php8.2-fpm

# Clear WordPress cache
sudo rm -rf /var/www/*/wp-content/cache/*

# Restart Nginx
sudo systemctl restart nginx
```

---

### 🟡 High Memory Usage

**Alert Trigger**: Memory usage > 85% for 5 minutes

**Symptoms**:
- System swapping
- OOM (Out of Memory) kills
- Slow performance

**Investigation Steps**:

1. **Check memory breakdown**
   ```bash
   free -h
   ```

2. **Find memory hogs**
   ```bash
   ps aux | sort -rk 4 | head -10
   ```

3. **Check for memory leaks**
   ```bash
   # Monitor memory over time
   watch -n 5 'free -h; echo "---"; ps aux | head -5'
   ```

**Expected Memory Usage (4GB CX23 x86)**:

| Component | Normal Usage | Alert If > |
|-----------|--------------|-----------|
| **System** | ~400 MB | - |
| **PHP-FPM** | ~200 MB | 600 MB |
| **MariaDB** | ~150 MB | 500 MB |
| **Nginx** | ~50 MB | 150 MB |
| **Valkey** | ~50 MB | 200 MB |
| **Prometheus** | ~25 MB | 100 MB |
| **Grafana** | ~83 MB | 200 MB |
| **Loki** | ~50 MB | 150 MB |
| **Cached/Buffers** | ~2.5 GB | Normal (not a problem) |

**Important**: Linux uses free memory for caching. High "cached" memory is GOOD, not bad!

**Common Fixes**:

```bash
# Clear system caches (safe, will refill automatically)
sudo sync && sudo sysctl -w vm.drop_caches=3

# Restart memory-hungry services
sudo systemctl restart mariadb
sudo systemctl restart php8.2-fpm

# Check for zombie processes
ps aux | grep defunct

# Kill specific process (replace PID)
sudo kill -9 <PID>
```

---

### 🟠 High Disk Usage

**Alert Trigger**: Disk usage > 80%

**Investigation Steps**:

1. **Check disk usage**
   ```bash
   df -h
   ```

2. **Find large directories**
   ```bash
   du -sh /* 2>/dev/null | sort -hr | head -10
   du -sh /var/* 2>/dev/null | sort -hr | head -10
   ```

3. **Find large files**
   ```bash
   find / -type f -size +100M -exec ls -lh {} \; 2>/dev/null
   ```

**Common Space Hogs**:

| Location | Typical Size | Cleanup Command |
|----------|--------------|-----------------|
| **Logs** | `/var/log` | `sudo journalctl --vacuum-time=7d` |
| **Prometheus data** | `/var/lib/prometheus` | Reduce retention in config |
| **WordPress uploads** | `/var/www/*/wp-content/uploads` | Archive or delete old media |
| **Backups** | `/var/backups` | `sudo rm -rf /var/backups/*.old` |
| **Package cache** | `/var/cache/apt` | `sudo apt clean` |
| **Old kernels** | `/boot` | `sudo apt autoremove --purge` |

**Cleanup Script**:

```bash
#!/bin/bash
# Safe cleanup script

# Clean package cache
sudo apt clean
sudo apt autoremove -y

# Clean old logs (keep 7 days)
sudo journalctl --vacuum-time=7d

# Clean old backup files
sudo find /var/backups -type f -mtime +30 -delete

# Report disk usage
echo "=== Disk Usage After Cleanup ==="
df -h
```

---

### 🔵 High Load Average

**Alert Trigger**: 15-minute load average > number of CPUs

**Understanding Load Average**:
- **CX23 x86**: 2 vCPUs → Normal load: 0.0 - 2.0
- **Load > 2.0**: System is overloaded
- **Load > 4.0**: Critical, investigate immediately

**Check Load**:
```bash
uptime
# Example: load average: 0.53, 0.42, 0.38
#          1-min   5-min  15-min
```

**Investigation**:

```bash
# Check what's causing load
top
# Press '1' to see per-CPU breakdown
# Press 'Shift+P' to sort by CPU
# Press 'Shift+M' to sort by memory

# Check I/O wait
iostat -x 1 5

# Check disk activity
iotop -o
```

**Common Causes**:

| Symptom | Cause | Fix |
|---------|-------|-----|
| High CPU%, low I/O | CPU-bound tasks | Optimize code, scale up CPU |
| Low CPU%, high I/O wait | Disk bottleneck | Check disk health, optimize queries |
| Many processes in D state | Uninterruptible I/O | Restart services, check disk |
| High load but low CPU% | Too many processes | Reduce PHP-FPM workers |

---

### 🟢 Target Down (Node Exporter Offline)

**Alert**: Prometheus can't scrape metrics from Node Exporter

**Symptoms**:
- No data in Grafana dashboards
- Prometheus targets page shows "DOWN"
- "No data" or "Query returned no data" errors

**Check Prometheus Targets**:

```bash
# Via SSH tunnel
curl http://localhost:9090/api/v1/targets | jq .

# Check target status
curl -s http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, instance: .labels.instance, health: .health}'
```

**Fix Steps**:

1. **Check Node Exporter is running**
   ```bash
   sudo systemctl status node_exporter
   ```

2. **Check if port 9100 is listening**
   ```bash
   sudo ss -tlnp | grep 9100
   # Should show: *:9100 ... node_exporter
   ```

3. **Test metrics endpoint**
   ```bash
   curl http://localhost:9100/metrics | head -20
   ```

4. **Check Prometheus config**
   ```bash
   cat /etc/prometheus/prometheus.yml
   # Verify scrape_configs have correct targets
   ```

5. **Check file service discovery**
   ```bash
   ls -la /etc/prometheus/file_sd/
   cat /etc/prometheus/file_sd/node.yml

   # Should contain:
   # ---
   # - targets:
   #   - localhost:9100
   #   labels:
   #     instance: "stag-de-wp-01"
   #     job: node_exporter
   ```

6. **Restart Prometheus**
   ```bash
   sudo systemctl restart prometheus
   sudo systemctl status prometheus
   ```

---

## Node Exporter Metrics Explained

### CPU Metrics

```promql
# CPU usage by mode
node_cpu_seconds_total{mode="idle"}     # Time CPU spent idle
node_cpu_seconds_total{mode="user"}     # Time spent in user processes
node_cpu_seconds_total{mode="system"}   # Time spent in kernel
node_cpu_seconds_total{mode="iowait"}   # Time waiting for I/O
node_cpu_seconds_total{mode="steal"}    # Time stolen by hypervisor (virtualization overhead)
```

**CPU Usage % Calculation**:
```promql
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)
```

### Memory Metrics

```promql
node_memory_MemTotal_bytes       # Total RAM
node_memory_MemFree_bytes        # Completely unused memory
node_memory_MemAvailable_bytes   # Available for new applications (includes cache)
node_memory_Buffers_bytes        # Disk buffers
node_memory_Cached_bytes         # Page cache
node_memory_SwapTotal_bytes      # Total swap
node_memory_SwapFree_bytes       # Free swap
```

**Memory Usage % Calculation**:
```promql
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100
```

### Disk Metrics

```promql
node_filesystem_size_bytes       # Total filesystem size
node_filesystem_free_bytes       # Free space
node_filesystem_avail_bytes      # Available space (for non-root users)
node_disk_io_time_seconds_total  # Time spent doing I/O
node_disk_read_bytes_total       # Bytes read
node_disk_written_bytes_total    # Bytes written
```

### Network Metrics

```promql
node_network_receive_bytes_total    # Bytes received
node_network_transmit_bytes_total   # Bytes transmitted
node_network_receive_errs_total     # Receive errors
node_network_transmit_errs_total    # Transmit errors
```

---

## Alert States

Grafana uses 4 alert states:

| State | Icon | Meaning | Action |
|-------|------|---------|--------|
| **Normal** | 🟢 | All good | None |
| **Pending** | 🟡 | Threshold exceeded, waiting for confirmation | Monitor |
| **Alerting** | 🔴 | Alert confirmed, action needed | Investigate |
| **No Data** | ⚪ | No metrics received | Check exporter |

---

## Troubleshooting Workflows

### Workflow 1: Dashboard Shows "No Data"

```
1. Check Prometheus targets
   → http://localhost:9090/targets

2. Is Node Exporter UP?
   → YES: Check time range in Grafana (top-right)
   → NO: Go to "Target Down" section above

3. Check Prometheus is scraping
   → http://localhost:9090/graph
   → Query: node_cpu_seconds_total
   → Execute

4. If no data in Prometheus
   → Check /var/log/prometheus/prometheus.log
   → Check file_sd config
   → Restart Prometheus
```

### Workflow 2: High CPU Alert

```
1. Verify alert in Grafana
   → Check CPU graph for spike pattern

2. SSH into server
   → Run: top -o %CPU

3. Identify process
   → PHP-FPM: Check slow logs, restart if needed
   → MariaDB: Check slow query log
   → Unknown: Check logs, consider killing

4. Take action
   → Optimize code/queries
   → Scale resources
   → Enable caching

5. Monitor for 15 minutes
   → Alert should clear if resolved
```

### Workflow 3: Memory Leak Detection

```
1. Check memory trend over 24 hours
   → Grafana → Memory panel → Last 24h

2. Is memory steadily increasing?
   → YES: Possible leak
   → NO: Normal usage spike

3. Identify leaking process
   → SSH: watch -n 60 'ps aux | head -5'
   → Look for growing RSS values

4. Restart service
   → sudo systemctl restart <service>

5. Monitor for 4-6 hours
   → If leak persists, investigate code
```

---

## Performance Metrics Reference

### Staging x86 (CX23) Baseline Metrics

These are **normal/expected** values for our staging environment:

#### Idle State (No Traffic)

| Metric | Value | Status |
|--------|-------|--------|
| CPU Usage | 2-5% | 🟢 Normal |
| Memory Used | ~800 MB / 3.7 GB (21%) | 🟢 Normal |
| Load Average | 0.05 - 0.15 | 🟢 Normal |
| Disk Usage | ~2.5 GB / 40 GB (6%) | 🟢 Normal |
| Network TX | < 1 Kbps | 🟢 Normal |
| Network RX | < 1 Kbps | 🟢 Normal |

#### Under Load (100k requests, 500 concurrency)

| Metric | Value | Status |
|--------|-------|--------|
| CPU Usage | 40-60% | 🟢 Normal |
| Memory Used | ~850 MB / 3.7 GB (23%) | 🟢 Normal |
| Load Average | 0.4 - 0.7 | 🟢 Normal |
| Requests/sec | 5,200+ | 🟢 Excellent |
| Mean Response Time | 95ms | 🟢 Excellent |
| Failed Requests | 0% | 🟢 Perfect |

#### Alert Thresholds

| Metric | Warning | Critical | Action |
|--------|---------|----------|--------|
| CPU Usage | > 70% | > 85% | Investigate processes |
| Memory Used | > 75% | > 90% | Clear caches, restart services |
| Load Average | > 2.0 | > 4.0 | Scale up or optimize |
| Disk Usage | > 75% | > 90% | Clean up files |
| Response Time | > 500ms | > 1000ms | Optimize queries/cache |

---

## Useful Prometheus Queries

### CPU

```promql
# CPU usage percentage
100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# CPU by mode
sum by (mode) (rate(node_cpu_seconds_total[5m])) * 100
```

### Memory

```promql
# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Memory available (GB)
node_memory_MemAvailable_bytes / 1024 / 1024 / 1024
```

### Disk

```promql
# Disk usage percentage
(1 - (node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})) * 100

# Disk I/O rate (MB/s)
rate(node_disk_read_bytes_total[5m]) / 1024 / 1024
```

### Network

```promql
# Network receive rate (Mbps)
rate(node_network_receive_bytes_total{device="eth0"}[5m]) * 8 / 1024 / 1024

# Network transmit rate (Mbps)
rate(node_network_transmit_bytes_total{device="eth0"}[5m]) * 8 / 1024 / 1024
```

---

## Quick Reference Commands

### Service Management

```bash
# Check all monitoring services
sudo systemctl status prometheus grafana-server loki promtail node_exporter

# Restart monitoring stack
sudo systemctl restart prometheus grafana-server loki node_exporter

# Check service logs
sudo journalctl -u prometheus -f
sudo journalctl -u grafana-server -f
```

### Monitoring Health Checks

```bash
# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq '.data.activeTargets[] | {job: .labels.job, health: .health}'

# Check Node Exporter metrics
curl http://localhost:9100/metrics | grep node_cpu

# Check Grafana health
curl http://localhost:3000/api/health
```

### Performance Checks

```bash
# Current resource usage
htop

# Disk I/O
iostat -x 1 5

# Network traffic
iftop -i eth0

# MySQL queries
mysqladmin -u root -p processlist

# PHP-FPM status
curl http://localhost/php-fpm-status
```

---

## Next Steps

1. **Set up alerting** - Configure Alertmanager for email/Slack notifications
2. **Create custom dashboards** - Build WordPress-specific dashboards
3. **Add more exporters** - Consider MySQL exporter, Nginx exporter
4. **Document runbooks** - Create step-by-step response guides for each alert
5. **Test disaster recovery** - Simulate failures and document recovery procedures

---

## Additional Resources

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Dashboards](https://grafana.com/grafana/dashboards/)
- [Node Exporter Metrics](https://github.com/prometheus/node_exporter)
- [Prometheus Best Practices](https://prometheus.io/docs/practices/)
- [Grafana Alerting Guide](https://grafana.com/docs/grafana/latest/alerting/)
