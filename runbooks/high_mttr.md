# Runbook: HighMTTR

**Alert Name**: `HighMTTR`  
**Severity**: Warning  
**Threshold**: MTTR > 60 minutes (average over 7 days)  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

The Mean Time to Restore (MTTR) — average time from incident detection to service restoration — has exceeded 60 minutes over the past 7 days, breaching the DORA high-performer threshold.

**DORA Benchmarks**:
- Elite: < 1 hour ← **SLO target**
- High: < 1 day
- Medium: 1 day – 1 week
- Low: > 1 week

---

## Likely Causes

1. Alerts are firing but on-call engineers are not being notified promptly (Slack config issue).
2. Runbooks are missing, outdated, or not linked from alert payloads.
3. Lack of observability — engineers spend most of MTTR finding the root cause.
4. No rollback procedure — teams must fix forward instead of reverting.
5. Incident response process not defined — no clear owner or escalation path.

---

## Investigation Steps

### Step 1 — Review recent incidents for time breakdown

Check the DORA dashboard for MTTR trend and identify which incidents are outliers:

```bash
# Query MTTR metric from Pushgateway
curl -s http://localhost:9091/metrics | grep cicd_mttr_seconds
```

For each high-MTTR incident, identify which phase took the longest:
- **Detection**: Time from incident start to alert fire
- **Triage**: Time from alert to root cause identified
- **Resolution**: Time from root cause to fix deployed

### Step 2 — Verify alert notification pipeline

Test that Alertmanager is routing alerts correctly to Slack:

```bash
# Send a test alert to Alertmanager
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{
    "labels": {"alertname": "MTTRTest", "severity": "warning"},
    "annotations": {"summary": "MTTR pipeline test alert"}
  }]'
```

Check `#DevOps-Alerts` in Slack — did the message arrive with runbook link?

### Step 3 — Audit runbook accessibility

```bash
# Verify all runbooks exist and are linked in alert rules
ls runbooks/
grep -r "runbook:" prometheus/rules/
```

Ensure every alert annotation includes a `runbook:` URL pointing to the correct file.

---

## Resolution

| Root Cause | Resolution |
|---|---|
| Notification failure | Fix Slack webhook / Alertmanager config; test with manual curl |
| Missing runbooks | Create and link runbooks for all alerts (see `/runbooks/`) |
| Slow root-cause analysis | Improve dashboards; ensure Loki→Tempo drill-down works |
| No rollback procedure | Document rollback steps in every runbook; automate git revert |
| Unclear ownership | Define clear on-call rotation and escalation matrix |

---

## Escalation

- Review MTTR monthly alongside CFR in reliability meeting.
- If MTTR trend is worsening, schedule a full incident response process review.
- Run a Game Day chaos exercise quarterly to practice fast recovery.
