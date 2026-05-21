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

# CPU breakdown by mode (user/sys/iowait/steal)
mpstat 1 5
```

### Step 2 — Check application metrics in Grafana

Open [Grafana → Node Exporter Dashboard](http://YOUR_VM_IP:3000/d/node-exporter).

- Look for CPU mode breakdown: is it `user` (application), `sys` (kernel), or `iowait` (disk)?
- Correlate with request rate — is this a traffic spike?
- Check Loki logs: `{service_name="demo-app"} |= "error"`.

### Step 3 — Identify which systemd service is responsible

```bash
# CPU usage by process with service name
systemd-cgtop -n 1

# Check resource usage of a specific service
systemctl status prometheus
systemctl status demo-app

# View recent logs of the suspect service
sudo journalctl -u demo-app --since "10 min ago"
sudo journalctl -u prometheus --since "10 min ago"
```

---

## Resolution

| Cause | Resolution |
|---|---|
| Runaway service | `sudo systemctl restart <service-name>` |
| Traffic spike | Investigate and add rate limiting to the demo app |
| Batch job | Reschedule to off-peak hours via cron |
| High iowait | Check disk I/O — see `disk_almost_full.md` runbook |
| High steal | GCP: check for CPU throttling; upgrade machine type if sustained |

---

## Rollback / Escalation

- If caused by a recent deployment: `git revert` the bad commit, push to `main`, then on VM: `sudo git -C /opt/lgtm-stack pull && sudo systemctl restart demo-app`.
- If CPU remains > 95% after initial steps: escalate to Engineering Lead.
- For sustained (> 30 min critical): restart the affected services one by one: `sudo systemctl restart prometheus alertmanager loki tempo`.
