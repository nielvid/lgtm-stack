# Runbook: DiskAlmostFull

**Alert Name**: `DiskAlmostFullWarning` / `DiskAlmostFullCritical`  
**Severity**: Warning (>80%) / Critical (>95%)  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

A filesystem on the host has exceeded the 80% (warning) or 95% (critical) usage threshold. At 100%, writes will fail — Prometheus will stop writing metrics, Loki will drop logs, Tempo will fail to store traces, and containers may crash.

---

## Likely Causes

1. Prometheus TSDB blocks accumulating beyond retention period.
2. Loki chunk storage growing due to high-volume log ingestion.
3. Tempo trace blocks not being compacted or cleaned up.
4. Docker container layers and images accumulating on `/var/lib/docker`.
5. Application log files on the host filling disk.

---

## Investigation Steps

### Step 1 — Identify which directories are consuming space

```bash
# Overall disk usage per mount
df -h

# Top space consumers from root
du -h / --max-depth=3 2>/dev/null | sort -rh | head -20

# Docker-specific usage
docker system df
```

### Step 2 — Check observability data volumes

```bash
# Prometheus TSDB
docker exec prometheus du -sh /prometheus/

# Loki chunks
docker exec loki du -sh /loki/

# Tempo blocks
docker exec tempo du -sh /var/tempo/
```

### Step 3 — Find and remove stale Docker resources

```bash
# Show dangling images, stopped containers, unused volumes
docker system df -v

# Remove stopped containers, dangling images, unused networks
docker system prune -f

# Remove unused volumes (caution: verify first)
docker volume ls --filter dangling=true
```

---

## Resolution

| Cause | Resolution |
|---|---|
| Prometheus old blocks | Reduce `retention.time` in `prometheus.yml`; restart Prometheus |
| Loki old chunks | Reduce `retention_period` in `loki-config.yaml`; restart Loki |
| Tempo old traces | Reduce `block_retention` in `tempo-config.yaml`; restart Tempo |
| Docker images/layers | `docker system prune -af --volumes` (data loss risk — verify volumes first) |
| Host log files | `journalctl --vacuum-time=7d` to trim system journal |
| GCP disk full | Resize disk via GCP Console: `gcloud compute disks resize <disk> --size=<GB>` |

---

## Rollback / Escalation

- If Prometheus write fails (disk 100%): immediately free space before anything else — data loss is certain if writes stay blocked.
- Escalate to Engineering Lead if disk cannot be freed within 30 minutes.
- For persistent growth: increase GCP persistent disk size or add object storage for Loki/Tempo.
