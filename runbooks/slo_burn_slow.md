# Runbook: SLOBurnRateSlow

**Alert Name**: `SLOBurnRateSlow`  
**Severity**: Warning  
**Window**: 6h + 30m (multi-window)  
**Threshold**: 6× budget burn rate  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

The availability SLO (99.5% over 30 days) is being burned at **6× the sustainable rate** across both the 6-hour and 30-minute windows simultaneously. At this rate, the **30-day error budget will be exhausted in approximately 5 days**. This requires investigation within the next few hours — it is not an immediate page but warrants focused attention.

**Error budget context**: Monthly budget = 216 minutes. At 6× burn, ~6 minutes of budget consumed per hour.

---

## Likely Causes

1. A subtle regression introduced in a recent deployment causing intermittent errors (not immediately obvious).
2. Gradual resource saturation (CPU creep, slow memory leak) increasing error rates over hours.
3. An external dependency degrading slowly (e.g., database connection pool slowly filling).
4. A low-traffic endpoint experiencing high error rates skewing the overall ratio.

---

## Investigation Steps

### Step 1 — Identify error patterns over the past 6 hours

```promql
# In Grafana → Explore (Prometheus)
# Error rate trend (6h)
sum(rate(http_requests_total{job="demo-app",status=~"5.."}[30m]))
/ sum(rate(http_requests_total{job="demo-app"}[30m]))

# Which endpoints are failing?
sum by(path)(rate(http_requests_total{job="demo-app",status=~"5.."}[6h]))
```

Look at the **Burn Rate History panel** in the SLO & Error Budget dashboard — is it trending up or flat?

### Step 2 — Review recent deployments and changes

```bash
# Last 10 commits pushed to main
git log --oneline -10

# Any infra changes in last 6 hours?
docker compose logs --since=6h | grep -E "restart|exit|error" | head -30
```

### Step 3 — Check resource saturation trends

In **Grafana → Node Exporter dashboard**, review:
- CPU trend: is it slowly climbing?
- Memory: is available memory shrinking?
- Disk I/O: is there increasing wait?

Cross-reference timing with when burn rate began increasing.

---

## Resolution

| Cause | Resolution |
|---|---|
| Subtle regression | Identify failing endpoint, hotfix or revert deployment |
| Resource saturation | Address root cause (memory leak, CPU pressure) per specific runbook |
| DB pool exhaustion | Increase pool size or add connection timeout |
| Low-traffic bad endpoint | Fix or temporarily disable the failing route |

---

## Rollback / Escalation

- Treat as non-urgent but schedule a fix within **4 business hours**.
- If burn rate increases to 14× → escalate immediately to `slo_burn_fast.md` protocol.
- Engineer on-call owns this investigation. No overnight page unless it becomes fast burn.
