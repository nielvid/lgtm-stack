# Runbook: DiskAlmostFull

**Alert Name**: `DiskAlmostFullWarning` / `DiskAlmostFullCritical`  
**Severity**: Warning (>80%) / Critical (>95%)  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

A filesystem on the host has exceeded the 80% (warning) or 95% (critical) usage threshold. At 100%, writes will fail — Prometheus will stop writing metrics, Loki will drop logs, Tempo will fail to store traces, and services may crash.

---

## Likely Causes

1. Prometheus TSDB blocks accumulating beyond the configured retention period.
2. Loki chunk storage growing due to high-volume log ingestion.
3. Tempo trace blocks not being compacted or cleaned up.
4. System journal logs (`/var/log/journal`) growing without rotation.
5. Application log files accumulating on the host.

---

## Investigation Steps

### Step 1 — Identify which directories are consuming space

```bash
# Overall disk usage per mount
df -h

# Top space consumers from root
du -h / --max-depth=3 2>/dev/null | sort -rh | head -20

# Check the journal size
journalctl --disk-usage
```

### Step 2 — Check observability data volumes

```bash
# Prometheus TSDB
du -sh /var/lib/prometheus/

# Loki chunks and WAL
du -sh /var/lib/loki/

# Tempo blocks and WAL
du -sh /var/lib/tempo/

# Grafana database
du -sh /var/lib/grafana/

# Pushgateway persistence
du -sh /var/lib/pushgateway/
```

### Step 3 — Find and clean system log accumulation

```bash
# Check journal size per service
journalctl --disk-usage

# Vacuum journal to keep only last 7 days
sudo journalctl --vacuum-time=7d

# Vacuum journal to a size limit
sudo journalctl --vacuum-size=500M

# Check for large files in /var/log
find /var/log -type f -size +50M | sort -k5 -rh
```

---

## Resolution

| Cause | Resolution |
|---|---|
| Prometheus old blocks | Reduce `--storage.tsdb.retention.time` in `prometheus.service`; `sudo systemctl restart prometheus` |
| Loki old chunks | Reduce `retention_period` in `/etc/loki/loki-config.yaml`; `sudo systemctl restart loki` |
| Tempo old traces | Reduce `block_retention` in `/etc/tempo/tempo-config.yaml`; `sudo systemctl restart tempo` |
| Journal logs | `sudo journalctl --vacuum-time=7d` |
| System apt cache | `sudo apt-get clean && sudo apt-get autoclean` |
| GCP disk full | Resize disk via GCP Console: `gcloud compute disks resize <disk> --size=<GB> --zone=<zone>` |

---

## Rollback / Escalation

- If Prometheus write fails (disk 100%): free space immediately before anything else — metrics will be lost if writes stay blocked.
- Escalate to Engineering Lead if disk cannot be freed within 30 minutes.
- For persistent growth: increase the GCP persistent disk size or reduce retention periods in the config files.
