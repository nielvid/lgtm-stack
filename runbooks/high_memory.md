# Runbook: HighMemory

**Alert Name**: `HighMemoryWarning` / `HighMemoryCritical`  
**Severity**: Warning (>80%) / Critical (>95%)  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

Available system memory has dropped below 20% (warning) or 5% (critical) of total RAM. At critical levels, the Linux OOM killer may terminate processes, causing unexpected service restarts and data loss.

---

## Likely Causes

1. Memory leak in the demo app — heap growing without being released.
2. Loki, Tempo, or Prometheus consuming excess RAM due to high cardinality or misconfigured retention.
3. Sudden traffic spike causing excessive in-memory buffering.
4. A service without memory limits consuming all host RAM.

---

## Investigation Steps

### Step 1 — Identify memory hog

```bash
# Free memory overview
free -h

# Top processes by memory
ps aux --sort=-%mem | head -15

# Check for OOM kills in kernel logs
dmesg | grep -i "killed process"
sudo journalctl -k | grep -i oom
```

### Step 2 — Check memory per service via systemd

```bash
# Memory usage per service (cgroup-based)
systemd-cgtop -n 1 --order=memory

# Check a specific service's memory limit and usage
systemctl show prometheus | grep -i memory
systemctl show loki | grep -i memory
```

### Step 3 — Check observability data directory sizes

High data volume in Loki, Tempo, or Prometheus can indirectly cause high RSS due to memory-mapped files:

```bash
# Prometheus TSDB on-disk size
du -sh /var/lib/prometheus/

# Loki chunks on-disk size
du -sh /var/lib/loki/

# Tempo blocks on-disk size
du -sh /var/lib/tempo/

# Prometheus heap via API
curl -s 'http://localhost:9090/api/v1/query?query=process_resident_memory_bytes{job="prometheus"}'
```

---

## Resolution

| Cause | Resolution |
|---|---|
| App memory leak | `sudo systemctl restart demo-app`; investigate with heap profiling |
| Loki high memory | Reduce `retention_period` in `loki-config.yaml`; `sudo systemctl restart loki` |
| Prometheus high memory | Reduce scrape interval or remove high-cardinality metrics; restart |
| Tempo high memory | Reduce `block_retention` in `tempo-config.yaml`; restart |
| General pressure | `sudo systemctl restart` the lightest non-critical service first |

---

## Rollback / Escalation

- If OOM kill has already occurred: check which service restarted via `sudo journalctl -k | grep "oom\|killed"`, then check `sudo systemctl status <service>` for the crash detail.
- Escalate to Engineering Lead if RSS exceeds 95% and cannot be reduced within 15 minutes.
