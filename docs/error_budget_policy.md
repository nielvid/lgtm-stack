# Error Budget Policy

## Overview

This document defines how the team responds when the error budget for each SLO is consumed, who owns the response, and how we review and update SLOs.

---

## SLO Targets & Error Budgets

| SLO | Target | Window | Error Budget (minutes/month) |
|---|---|---|---|
| Availability | 99.5% | 30 days | 216 minutes (~3.6 hours) |
| Latency P99 | ≥ 99% requests < 200ms | 30 days | 432 minutes |
| Error Rate | < 5% error rate | 30 days | Continuous |
| CPU Saturation | < 80% CPU | 30 days | — |

### Error Budget Calculation

```
Error Budget = (1 - SLO_target) × measurement_window_minutes

Availability:  (1 - 0.995) × 43,200 min = 216 minutes/month
Latency P99:   (1 - 0.990) × 43,200 min = 432 minutes/month
```

---

## Budget Consumption Response Actions

### At 50% Consumption

**Trigger**: Error budget is 50% consumed within the rolling 30-day window.

**Actions**:
1. On-call engineer investigates current burn rate in Grafana SLO dashboard.
2. Engineering team notified in `#DevOps-Alerts` (automatic via Alertmanager `SLOBurnRateSlow`).
3. Review open incidents and recent deployments for contributing causes.
4. Pause non-critical feature deployments for 24 hours if burn rate is accelerating.
5. No customer communication required unless degradation is visible.

**Owner**: On-call SRE / Platform Engineer  
**SLA for response**: Within 4 business hours

---

### At 100% Consumption (Budget Exhausted)

**Trigger**: Error budget fully consumed — SLO is breached for the month.

**Actions**:
1. Immediately halt all non-critical deployments.
2. Convene an emergency postmortem within 24 hours.
3. Identify root cause and implement a reliability improvement sprint.
4. SLO dashboard is reviewed in weekly team sync.
5. Customer communication if availability impact was user-visible.
6. A blameless Post-Incident Review (PIR) is mandatory before resuming the deployment cadence.

**Owner**: Engineering Lead + On-call SRE  
**SLA for response**: Within 1 hour (critical alert fires)

---

## Review Cadence

| Review Type | Frequency | Owner |
|---|---|---|
| Error Budget Status Review | Weekly (Monday) | Engineering Lead |
| SLO Target Review | Quarterly | Engineering + Product |
| Post-incident SLO Audit | After every P1/P2 incident | On-call SRE |

---

## Toil Identification & Automation

Two identified sources of toil and their automation actions:

### Toil 1: Manual SSL Certificate Renewal
- **Current State**: SSL certs renewed manually via Let's Encrypt CLI.
- **Impact**: Risk of expiry if not actioned promptly; ops overhead.
- **Automation**: Deploy `certbot` with auto-renewal cron job. Alert fires at 30 days (`SSLCertExpiryWarning`) and 7 days (`SSLCertExpiryCritical`) to catch failures.

### Toil 2: Manual Deployment Health Checks
- **Current State**: Engineer checks Grafana after every deployment to confirm success.
- **Impact**: Cognitive load; missed failures when no one is available.
- **Automation**: GitHub Actions DORA workflow automatically pushes deployment status. `HighChangeFailureRate` alert fires if CFR exceeds 15%. Automated health check in deploy pipeline with rollback on failure.

---

## Escalation Path

```
Burn Alert Fires
    ↓
On-Call SRE (PagerDuty/Slack)
    ↓ (15 min, no response)
Engineering Lead
    ↓ (30 min, unresolved)
VP Engineering
```
