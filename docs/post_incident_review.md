# Post-Incident Review (PIR) — Latency Injection Simulation

**Incident ID**: INC-2024-001  
**Date**: 2024-12-01  
**Severity**: P2  
**Duration**: 42 minutes  
**Status**: Resolved  
**Author**: Platform Team  
**Type**: Blameless PIR (Simulated — Game Day)

---

## Summary

A latency injection was deliberately introduced to simulate high database query times in the demo application. The P99 latency spiked to 2.3 seconds (SLO: 200ms), triggering the `HighLatencySLOBreach` alert. The burn rate exceeded the 6x slow-burn threshold. The issue was detected automatically at T+3 minutes and resolved at T+42 minutes.

---

## Timeline

| Time | Event |
|---|---|
| T+0:00 | Latency injection activated — artificial 2s sleep added to `/api/data` endpoint |
| T+0:45 | P99 latency rises above 500ms; error rate stable |
| T+3:00 | `HighLatencySLOBreach` alert fires in Slack `#DevOps-Alerts` |
| T+5:00 | On-call engineer acknowledges alert, opens Grafana Unified dashboard |
| T+7:00 | Traces in Tempo show slow span on `/api/data` → database query |
| T+10:00 | Loki logs confirm repeated `db.query_time > 2000ms` entries with trace ID correlation |
| T+15:00 | Root cause identified: artificial latency injection in Game Day scenario |
| T+18:00 | `SLOBurnRateSlow` alert fires (6x burn, 6h+30m window) |
| T+25:00 | Rollback plan documented; latency injection removed from code |
| T+38:00 | Deploy of fix pushed to main; GitHub Actions workflow triggers |
| T+42:00 | P99 latency drops below 100ms; alerts auto-resolve |
| T+45:00 | Slack shows `✅ [RESOLVED]` notifications for all fired alerts |

---

## Root Cause

**Immediate cause**: Artificial sleep (`setTimeout(2000)`) injected in the database query handler of the demo app to simulate slow queries.

**Contributing factors**:
- No request timeout configured in the HTTP client, allowing requests to queue rather than fail fast.
- The database connection pool was not sized for the increased wait time, causing pool exhaustion at high concurrency.

---

## Impact

| Metric | Value |
|---|---|
| Duration | 42 minutes |
| P99 latency peak | 2.3 seconds |
| Error budget consumed | ~19% of monthly availability budget |
| Users affected | 0 (simulated scenario — no real traffic) |
| Services affected | demo-app only |

---

## Detection & Response Gaps

1. **Gap**: Alert fired at T+3 minutes, but the on-call runbook was not immediately accessible — engineer had to search for it.
   - **Action**: Add runbook link to every Alertmanager alert payload (implemented — see `alertmanager.yml` annotations).

2. **Gap**: No automated request timeout — requests queued indefinitely rather than failing fast.
   - **Action**: Add `timeout: 5s` to all outbound HTTP clients in demo app. Add circuit breaker.

3. **Gap**: Database connection pool exhaustion was not alerted on separately.
   - **Action**: Add `ConnectionPoolExhaustion` alert rule in a future iteration.

---

## Action Items

| Item | Owner | Due Date | Status |
|---|---|---|---|
| Add runbook links to all alert payloads | Platform SRE | Immediate | ✅ Done |
| Add HTTP request timeout (5s) to demo app | App Team | 2024-12-08 | ⬜ Open |
| Add circuit breaker to outbound calls | App Team | 2024-12-15 | ⬜ Open |
| Add connection pool saturation alert | Platform SRE | 2024-12-15 | ⬜ Open |
| Run Game Day quarterly | Engineering Lead | Quarterly | ⬜ Scheduled |

---

## What Went Well

- Alertmanager correctly grouped and routed the alert to Slack with structured payload within 3 minutes.
- Grafana Unified dashboard enabled metric → log → trace correlation within 10 minutes.
- `SLOBurnRateSlow` alert prevented the team from underestimating sustained impact.
- GitHub Actions DORA workflow correctly marked the recovery deployment as a CFR event.

---

## Lessons Learned

1. **Observability works**: The LGTM stack successfully correlated a latency spike (metrics) to specific slow queries (logs) to the exact slow span (traces) — all within a single Grafana session.
2. **Burn rate alerting prevents surprise**: The multi-window burn rate gave early warning before the budget was fully exhausted.
3. **Runbook accessibility is critical**: Engineers must not have to search for runbooks during incidents.
