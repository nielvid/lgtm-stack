# Runbook: InstanceDown

**Alert Name**: `InstanceDown` / `HTTPProbeFailure`  
**Severity**: Critical  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

A monitored target has become unreachable by Prometheus (`up == 0`) or an HTTP probe via Blackbox Exporter has failed. This typically indicates a crashed container, network issue, or host-level problem.

---

## Likely Causes

1. The container has crashed (OOM kill, application panic, signal).
2. The host VM has lost network connectivity or is rebooting.
3. The service port is no longer listening (misconfiguration, port conflict).
4. Prometheus cannot reach the target due to a Docker network issue.

---

## Investigation Steps

### Step 1 — Check container status

```bash
# Which containers are down?
docker compose ps

# View recent logs for the failed service
docker compose logs --tail=100 <service_name>

# Check exit code
docker inspect <container_id> --format='{{.State.ExitCode}} {{.State.Error}}'
```

### Step 2 — Check host and network connectivity

```bash
# Is the host reachable? (run from another machine)
ping <VM_EXTERNAL_IP>

# Is the Docker network intact?
docker network inspect lgtm-network

# Can Prometheus resolve the target?
docker exec prometheus wget -qO- http://<target_service>:<port>/metrics | head -5
```

### Step 3 — Check system resources and kernel logs

```bash
# Was the process OOM-killed?
dmesg | grep -i "killed process" | tail -10

# Check systemd status of Docker
systemctl status docker

# Check disk space (full disk causes container crashes)
df -h
```

---

## Resolution

| Cause | Resolution |
|---|---|
| Container crashed | `docker compose restart <service>` |
| OOM kill | Free memory (see `high_memory.md`), then restart container |
| All containers down | `docker compose up -d` from repo directory |
| Docker daemon crashed | `sudo systemctl restart docker && docker compose up -d` |
| Host unreachable | Check GCP Console → Compute Engine → VM status; start if stopped |
| Network issue | `docker network rm lgtm-network && docker compose up -d` |

---

## Rollback / Escalation

- If all containers are down: SSH to host, run `cd /opt/lgtm-stack && docker compose up -d`.
- If the VM is unreachable: use GCP Console serial console to investigate.
- Escalate to Engineering Lead if services cannot be restored within 15 minutes.
