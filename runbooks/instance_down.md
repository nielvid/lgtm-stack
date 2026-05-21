# Runbook: InstanceDown

**Alert Name**: `InstanceDown` / `HTTPProbeFailure`  
**Severity**: Critical  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

A monitored target has become unreachable by Prometheus (`up == 0`) or an HTTP probe via Blackbox Exporter has failed. This typically indicates a crashed service, a network issue, or a host-level problem.

---

## Likely Causes

1. The service crashed (OOM kill, application panic, unhandled exception).
2. The host VM has lost network connectivity or is rebooting.
3. The service port is no longer listening (misconfiguration, port conflict).
4. The systemd service unit failed and is in a `failed` state.

---

## Investigation Steps

### Step 1 — Check which service is down

```bash
# Check status of all LGTM services at once
sudo systemctl status prometheus alertmanager loki tempo \
  otelcol-contrib node-exporter blackbox-exporter pushgateway \
  grafana-server demo-app

# Find any failed units
systemctl --failed --no-legend

# View recent logs of the failed service
sudo journalctl -u <service-name> --since "15 min ago" --no-pager
```

### Step 2 — Check if the port is listening

```bash
# Confirm which ports are bound
sudo ss -tlnp | grep -E "9090|9093|3100|3200|3000|9100|9115|9091|8080|4317|4318"

# Direct connectivity check to a specific service
curl -sv http://localhost:9090/-/healthy
curl -sv http://localhost:3100/ready
curl -sv http://localhost:3200/ready
```

### Step 3 — Check system-level health

```bash
# Was a process OOM-killed?
sudo dmesg | grep -i "killed process" | tail -10
sudo journalctl -k | grep -i oom | tail -10

# Is the disk full (causing write failures and crashes)?
df -h

# Check overall system load
uptime
free -h
```

---

## Resolution

| Cause | Resolution |
|---|---|
| Service crashed | `sudo systemctl restart <service-name>` |
| Service in failed state | `sudo systemctl reset-failed <service-name> && sudo systemctl start <service-name>` |
| OOM kill | Free memory (see `high_memory.md`), then `sudo systemctl start <service-name>` |
| All services down | `sudo systemctl restart prometheus alertmanager loki tempo otelcol-contrib grafana-server demo-app` |
| Host unreachable | Use GCP Console → Compute Engine → VM → Connect via Serial Console |
| Port conflict | `sudo ss -tlnp | grep <port>` to find the conflicting process; kill it |

---

## Rollback / Escalation

- If all services are down: SSH to host and run `sudo systemctl start prometheus alertmanager loki tempo grafana-server`.
- If the VM is unreachable: use GCP Console serial console to investigate.
- Escalate to Engineering Lead if services cannot be restored within 15 minutes.
