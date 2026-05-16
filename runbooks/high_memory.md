# Runbook: HighMemory

**Alert Name**: `HighMemoryWarning` / `HighMemoryCritical`  
**Severity**: Warning (>80%) / Critical (>95%)  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

Available system memory has dropped below 20% (warning) or 5% (critical) of total RAM. At critical levels, the Linux OOM killer may terminate processes, causing unexpected container restarts and data loss.

---

## Likely Causes

1. Memory leak in the application — heap growing without being released.
2. Loki, Tempo, or Prometheus consuming excess RAM due to high cardinality or misconfigured retention.
3. Sudden traffic spike causing excessive in-memory buffering.
4. Container without memory limits consuming all host RAM.

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
journalctl -k | grep -i oom
```

### Step 2 — Check container memory usage

```bash
# Memory per container
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}"
```

Cross-reference with Grafana → Node Exporter → Memory panel.

### Step 3 — Check observability stack memory

High cardinality Loki streams or large Prometheus TSDB blocks are common causes:

```bash
# Loki data size
docker exec loki du -sh /loki/

# Prometheus TSDB size
docker exec prometheus du -sh /prometheus/

# Check if Prometheus heap is large
curl http://localhost:9090/api/v1/query?query=process_resident_memory_bytes{job="prometheus"}
```

---

## Resolution

| Cause | Resolution |
|---|---|
| App memory leak | Restart app container; investigate with heap dump |
| Loki high memory | Reduce retention or lower `ingestion_rate_mb` in loki-config.yaml |
| Prometheus high memory | Reduce scrape interval or remove high-cardinality metrics |
| No container limits | Add `mem_limit` to docker-compose.yml and redeploy |
| General pressure | Restart lightest non-essential containers first |

---

## Rollback / Escalation

- If OOM kill has already occurred: `docker compose ps` to identify restarted containers; `docker compose logs <service>` for last known state.
- Escalate to Engineering Lead if RSS exceeds 95% and cannot be reduced within 15 minutes.
