# Runbook: HighCPU

**Alert Name**: `HighCPUWarning` / `HighCPUCritical`  
**Severity**: Warning (>80%) / Critical (>95%)  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

CPU utilization on the host has exceeded the warning (80%) or critical (95%) threshold for more than 5 minutes (warning) or 2 minutes (critical). Sustained high CPU can cause request latency increases, OOM kills, and cascading failures.

---

## Likely Causes

1. A runaway process (loop, zombie, memory leak with GC thrashing) consuming all CPU cycles.
2. Sudden traffic spike overwhelming the application — check request rate.
3. A batch job or cron task running unexpectedly (e.g., log rotation, database vacuum).
4. Kernel-level issue: high `iowait`, `steal` (in virtualized environments), or `sys` CPU.

---

## Investigation Steps

### Step 1 — Identify top CPU consumers

SSH into the affected host and run:

```bash
# Top processes by CPU
top -bn1 | head -20

# More detailed view
ps aux --sort=-%cpu | head -15

# Check CPU breakdown (user/sys/iowait/steal)
mpstat 1 5
```

### Step 2 — Check application metrics in Grafana

Open [Grafana → Node Exporter Dashboard](http://YOUR_VM_IP:3000/d/node-exporter).

- Look for CPU mode breakdown: is it `user` (application), `sys` (kernel), or `iowait` (disk)?
- Correlate with request rate — is this a traffic spike?
- Check Loki logs for errors: `{service_name="demo-app"} |= "error"`.

### Step 3 — Check for runaway containers

```bash
# CPU usage by container
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

# Check if a specific container is the culprit
docker top <container_name>
```

---

## Resolution

| Cause | Resolution |
|---|---|
| Runaway process | `kill -9 <PID>` or `docker restart <container>` |
| Traffic spike | Scale app replicas or enable rate limiting |
| Batch job | Reschedule batch to off-peak hours |
| High iowait | Check disk I/O — see `disk_almost_full.md` runbook |
| High steal | GCP: check for CPU throttling; upgrade machine type if sustained |

---

## Rollback / Escalation

- If caused by a recent deployment: `git revert` and redeploy.
- If CPU remains > 95% after initial steps: escalate to Engineering Lead.
- For sustained (> 30 min critical): consider restarting all containers: `docker compose restart`.
