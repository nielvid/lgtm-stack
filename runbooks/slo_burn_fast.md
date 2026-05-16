# Runbook: SLOBurnRateFast

**Alert Name**: `SLOBurnRateFast`  
**Severity**: Critical  
**Window**: 1h + 5m (multi-window)  
**Threshold**: 14× budget burn rate  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

The availability SLO (99.5% over 30 days) is being burned at **14× the sustainable rate** in both the 1-hour and 5-minute windows simultaneously. At this rate, the **entire 30-day error budget will be exhausted in approximately 2 days**. Immediate action is required.

**Error budget context**: Monthly budget = 216 minutes. At 14× burn, 14 minutes of budget is consumed every 1 minute of the alert window.

---

## Likely Causes

1. A recent deployment introduced a regression causing widespread HTTP 5xx errors.
2. A dependency (database, external API) has failed, causing cascading errors.
3. Infrastructure failure: host crash, out-of-memory, disk full — causing application unavailability.
4. A traffic spike overwhelming the service with unhandled errors.

---

## Investigation Steps

### Step 1 — Check current error rate and source

```promql
# In Grafana → Explore (Prometheus datasource)

# Current error ratio
sum(rate(http_requests_total{job="demo-app",status=~"5.."}[5m]))
/ sum(rate(http_requests_total{job="demo-app"}[5m]))

# Errors by status code
sum by(status)(rate(http_requests_total{job="demo-app",status=~"5.."}[5m]))
```

Open: **Grafana → SLO & Error Budget dashboard** — confirm burn rate panel shows > 14×.

### Step 2 — Correlate to recent deployments

```bash
# Check last 5 GitHub Actions deployments in DORA dashboard
# OR check git log
git log --oneline -10

# Check if errors started at a deploy time
docker compose logs --since="1h" app | grep -E "ERROR|FATAL|panic"
```

### Step 3 — Trace the errors in Tempo

1. Open **Grafana → Unified Observability dashboard**.
2. In the Loki panel, filter: `{service_name="demo-app"} |= "error" | logfmt`.
3. Click a log line with a `traceId` field → "View Trace in Tempo".
4. Identify the failing span (red) and its error message.

---

## Resolution

| Cause | Resolution |
|---|---|
| Bad deployment | `git revert HEAD && git push origin main` (triggers redeploy) |
| Database failure | Check DB connectivity: `docker compose logs db`; restart if needed |
| OOM / disk full | See `high_memory.md` / `disk_almost_full.md` runbooks |
| Traffic spike | Enable rate limiting in Nginx; scale app replicas |
| External API down | Add circuit breaker; return cached/degraded response |

---

## Rollback / Escalation

1. **Immediate** (< 5 min): Roll back last deployment if errors correlate to deploy time.
2. **< 15 min**: Escalate to Engineering Lead if error rate remains > 10%.
3. **< 30 min**: Engage full incident response; open incident channel; page on-call.
4. Document all actions for the mandatory PIR after resolution.
