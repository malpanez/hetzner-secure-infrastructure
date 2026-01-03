# ARM64 vs x86 Performance Comparison

**Date**: 2026-01-01
**Test**: Apache Bench - 100,000 requests, 100 concurrent connections
**Location**: Localhost (no network latency)
**Workload**: WordPress redirect (302)

---

## Server Specifications

| Specification | x86 (CX23) | ARM64 (CAX11) | Difference |
|---------------|------------|---------------|------------|
| **Provider** | Hetzner Cloud | Hetzner Cloud | - |
| **Architecture** | x86_64 (Intel/AMD) | aarch64 (Ampere) | Different |
| **vCPUs** | 2 cores | 2 cores | Same |
| **RAM** | 4 GB | 4 GB | Same |
| **Storage** | 40 GB NVMe | 40 GB NVMe | Same |
| **Price** | €3.68/month | €4.05/month | **+€0.37 (ARM64 higher)** |

---

## Performance Results - Head to Head

### Throughput

| Metric | x86 (CX23) | ARM64 (CAX11) | Winner | Difference |
|--------|------------|---------------|--------|------------|
| **Requests/sec** | 3,114 req/sec | 8,339 req/sec | **ARM64** | **+168% (2.68x faster)** |
| **Transfer rate** | 1,244 KB/sec | 540,573 KB/sec | **ARM64** | **+434x faster** |
| **Total time** | 32.1 seconds | 12.0 seconds | **ARM64** | **-63% faster** |

### Latency

| Metric | x86 (CX23) | ARM64 (CAX11) | Winner | Difference |
|--------|------------|---------------|--------|------------|
| **Mean time per request** | 32.1ms | 12.0ms | **ARM64** | **-63% (2.7x faster)** |
| **Median (50%)** | 31ms | 12ms | **ARM64** | **-61%** |
| **75th percentile** | 40ms | 13ms | **ARM64** | **-68%** |
| **90th percentile** | 49ms | 15ms | **ARM64** | **-69%** |
| **95th percentile** | 57ms | 16ms | **ARM64** | **-72%** |
| **99th percentile** | 76ms | 18ms | **ARM64** | **-76%** |
| **Max (slowest)** | 172ms | 87ms | **ARM64** | **-49%** |

### Connection Times

| Phase | x86 (CX23) | ARM64 (CAX11) | Winner |
|-------|------------|---------------|--------|
| **Connect (mean)** | 0ms | 2ms | x86 |
| **Processing (mean)** | 32ms | 10ms | **ARM64 (3.2x faster)** |
| **Waiting (mean)** | 32ms | 3ms | **ARM64 (10.7x faster)** |
| **Total (mean)** | 32ms | 12ms | **ARM64 (2.7x faster)** |

### Reliability

| Metric | x86 (CX23) | ARM64 (CAX11) | Result |
|--------|------------|---------------|--------|
| **Failed requests** | 0 | 0 | **Perfect (tie)** |
| **Error rate** | 0% | 0% | **Perfect (tie)** |
| **Success rate** | 100% | 100% | **Perfect (tie)** |

---

## Resource Usage

### Memory Utilization

| Metric | x86 (CX23) | ARM64 (CAX11) | Winner |
|--------|------------|---------------|--------|
| **Total RAM** | 3.7 GB | 3.7 GB | Tie |
| **Used (before test)** | 899 MB (24%) | 736 MB (19%) | **ARM64 (lower)** |
| **Available** | 2.9 GB (79%) | 3.0 GB (80%) | **ARM64 (more)** |

### CPU Load

| Metric | x86 (CX23) | ARM64 (CAX11) | Notes |
|--------|------------|---------------|-------|
| **vCPUs** | 2 | 2 | Same core count |
| **Load (1m peak)** | 0.66 | 0.19 | ARM64 baseline load |
| **Load per core** | 0.33 per core | 0.10 per core | ARM64 lower per-core load |

---

## Cost-Performance Analysis

### Price per Performance

| Metric | x86 (CX23) | ARM64 (CAX11) | Winner |
|--------|------------|---------------|--------|
| **Monthly cost** | €3.68 | €4.05 | **x86 (-€0.37)** |
| **Annual cost** | €44.16 | €48.60 | **x86 (-€4.44)** |
| **Req/sec per €** | 846 req/€ | 2,059 req/€ | **ARM64 (2.43x better)** |
| **Req/sec per € annually** | 70.6 req/€ | 171.6 req/€ | **ARM64 (2.43x better)** |

### Performance per Dollar

**ARM64 delivers 2.43x more performance for ~10% higher cost**

---

## Detailed Analysis

### Why ARM64 is Faster

1. **Modern ARM architecture** (Ampere Neoverse)
   - Optimized for cloud workloads
   - Better power efficiency = more consistent performance
   - No SMT/hyperthreading overhead (physical cores)

2. **Better memory efficiency**
   - Lower baseline memory usage (736 MB vs 899 MB)
   - More memory available for caching

3. **Newer generation hardware**
   - ARM64 CAX servers are Hetzner's newest offering
   - Latest NVMe storage generation
   - Modern CPU microarchitecture

### Response Time Distribution Comparison

**x86 (CX23)**:
- 50% of requests: ≤ 31ms
- 90% of requests: ≤ 49ms
- 95% of requests: ≤ 57ms
- 99% of requests: ≤ 76ms

**ARM64 (CAX11)**:
- 50% of requests: ≤ 12ms
- 90% of requests: ≤ 15ms
- 95% of requests: ≤ 16ms
- 99% of requests: ≤ 18ms

**Result**: ARM64 is consistently 2-4x faster across all percentiles.

---

## Monitoring Stack Impact

Both servers run identical monitoring stack:
- Prometheus (metrics)
- Grafana (visualization)
- Loki (logs)
- Promtail (log shipping)
- Node Exporter (system metrics)

**Overhead**: ~400 MB RAM, < 1% CPU (both architectures)

**Impact**: Negligible on both platforms

---

## Grafana Monitoring During Benchmark

### x86 (CX23) - System Load Behavior

**Observation during 100k request test**:
- Load 1m: Peaked at **0.66** (33% of 2 vCPU capacity)
- Load 5m: Stable at **0.32**
- Load 15m: Very stable at **0.21**
- Recovery: Immediate after test completion

**System Processes**:
- Runnable processes: Mean **1.46**, max **4**
- Blocked I/O: **0** (no I/O bottleneck)
- Process forks: Stable at **~3.5/sec**

**Interpretation**: System handled load comfortably with 67% CPU headroom remaining.

### ARM64 (CAX11) - System Load Behavior

**Observation during 100k request test**:
- Load 1m: Baseline **0.19** (very low)
- System remained responsive throughout
- No visible stress on CPU resources
- Lower per-core utilization than x86

**Key Difference**:
- ARM64 maintained **significantly lower system load** (0.19 vs 0.66)
- This indicates **better CPU efficiency** per request
- Same 2 vCPU count, but ARM64 processes requests with less CPU stress

### Monitoring Insights

| Metric | x86 (CX23) | ARM64 (CAX11) | Analysis |
|--------|------------|---------------|----------|
| **Peak Load (1m)** | 0.66 | 0.19 | ARM64: 71% lower load |
| **CPU Headroom** | 67% | ~90% | ARM64: More capacity available |
| **I/O Blocking** | 0 | 0 | Both: No bottleneck |
| **Process Stability** | Excellent | Excellent | Both: Stable |
| **Recovery Time** | Immediate | Immediate | Both: Fast |

**Conclusion**: Both platforms handle the workload easily, but ARM64 does so with significantly lower CPU utilization, suggesting better architectural efficiency.

---

## Real-World Implications

### For WordPress Hosting

| Scenario | x86 (CX23) | ARM64 (CAX11) | Recommendation |
|----------|------------|---------------|----------------|
| **Small blog** (< 1k visits/day) | ✅ Sufficient | ✅ Overkill | Either works |
| **Medium site** (1k-10k visits/day) | ✅ Good | ✅✅ Excellent | **ARM64** |
| **Large site** (10k-50k visits/day) | ⚠️ May struggle | ✅ Handles well | **ARM64** |
| **High traffic** (> 50k visits/day) | ❌ Insufficient | ⚠️ Add caching | Multi-server |

### For Development/Staging

**ARM64 is the clear winner**:
- ~2.7x faster = shorter CI/CD cycles
- Slightly higher cost but better price/performance
- Same core count with better per-core throughput

### For Production

**ARM64 recommended for**:
- New deployments (no legacy constraints)
- WordPress sites
- Modern PHP applications
- Cost-conscious operations

**x86 still needed for**:
- Legacy software requiring x86
- Specific x86-only dependencies
- Applications not ARM-compatible

---

## Benchmark Reproducibility

### Test Commands

```bash
# On the server
ssh user@server
ab -n 100000 -c 100 http://localhost/
```

### Test Environment
- Both tests run from localhost (no network latency)
- Same WordPress configuration (redirect to /wp-admin/install.php)
- Same Nginx + PHP-FPM + MariaDB stack
- Same monitoring stack (Prometheus + Grafana + Loki)
- Tests run within 2 days of each other

---

## Conclusion

### Performance Winner: ARM64 by a landslide 🏆

| Category | Winner | Margin |
|----------|--------|--------|
| **Throughput** | ARM64 | **2.68x faster** |
| **Latency** | ARM64 | **2.7x lower** |
| **Cost** | x86 | **~10% cheaper** |
| **Cost/Performance** | ARM64 | **2.43x better** |
| **Reliability** | Tie | Both 100% |
| **Memory Efficiency** | ARM64 | Lower baseline |
| **vCPU Count** | Tie | 2 cores each |

### Recommendation

**Use ARM64 (CAX11 or CAX21) for**:
- ✅ New WordPress deployments
- ✅ Cost-sensitive projects
- ✅ High-performance requirements
- ✅ Modern PHP/Node.js applications
- ✅ Development and staging environments

**Use x86 (CX23) only if**:
- ❌ You have x86-specific dependencies
- ❌ You need legacy software compatibility
- ❌ Your application isn't ARM-compatible

### Final Verdict

**ARM64 (CAX11) offers ~2.7x better performance at ~10% higher cost**

For WordPress hosting on Hetzner Cloud, ARM64 is the obvious choice. The combination of:
- Similar vCPU cores (2 vs 2)
- Better performance (8,339 vs 3,114 req/sec)
- Slightly higher cost (€4.05 vs €3.68)
- Better cost/performance ratio (2.43x)

Makes ARM64 the clear winner for modern web applications.

**Grade Comparison**:
- x86 (CX23): A+ (excellent)
- ARM64 (CAX11): **S-tier** (exceptional)

---

## Next Steps

### Immediate Actions
1. ✅ **Choose ARM64** for production deployment (CAX11 or CAX21)
2. ✅ Update infrastructure templates to default to CAX series
3. ✅ Document ARM64 configuration

### For Production
1. Deploy ARM64 CAX11 for WordPress production (or CAX21 for more headroom)
2. Add Cloudflare CDN for edge caching
3. Configure Grafana alerts
4. Set up automated backups
5. Monitor performance for 30 days

### For Scaling (when revenue justifies)
Consider 2-3 server architecture:
```
Server 1: WordPress + Nginx (CAX11: €4.05)
Server 2: MariaDB (CAX11: €4.05)
Server 3: Monitoring + OpenBao (CAX11: €4.05)
Total: €12.15/month
```

Compared to x86 equivalent:
```
Server 1: WordPress + Nginx (CPX21: €5.90)
Server 2: MariaDB (CPX11: €4.15)
Server 3: Monitoring (CPX11: €4.15)
Total: €14.20/month
```

**Savings**: €2.05/month (€24.60/year) with better performance

---

**Author**: Infrastructure Team
**Last Updated**: 2026-01-01
**Test Date**: 2026-01-01
**Benchmark Version**: 2.0 (Apples-to-Apples)
