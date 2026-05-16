# Runbook: HighChangeFailureRate

**Alert Name**: `HighChangeFailureRate`  
**Severity**: Warning  
**Threshold**: CFR > 15% over 7 days  
**Runbook Owner**: Platform SRE  
**Last Updated**: 2024-12-01

---

## Alert Description

More than 15% of deployments in the past 7 days have resulted in a failure or rollback, exceeding the DORA medium-performer threshold. This indicates an unstable deployment pipeline or insufficient pre-deployment testing.

**DORA Benchmarks**:
- Elite: < 5% CFR
- High: 5–10%
- Medium: 10–15%
- Low: > 15% ← **Alert fires here**

---

## Likely Causes

1. Insufficient test coverage — bugs reaching production that automated tests should catch.
2. Missing staging/pre-production environment — changes go directly to production.
3. Large, infrequent deployments ("big bang" releases) increasing blast radius.
4. Lack of feature flags — unable to decouple deploy from release.
5. Manual deployment steps prone to human error.

---

## Investigation Steps

### Step 1 — Review recent failed deployments

Open **Grafana → DORA Metrics dashboard**:
- Check "Deployment Frequency Trend" panel: are failures clustered around specific dates?
- Which deployments were marked as `status="failure"` in Pushgateway?

```bash
# Query Pushgateway for recent failures
curl -s http://localhost:9091/metrics | grep cicd_deployments_total
```

### Step 2 — Identify pattern in failures

Review GitHub Actions workflow runs:
- Go to `https://github.com/<org>/<repo>/actions`
- Filter by "failed" status
- Look for common failure modes: test failures, build errors, deployment script issues

```bash
# Check git log for reverts (each revert = CFR event)
git log --oneline --all | grep -i revert | head -10
```

### Step 3 — Assess pipeline coverage

```bash
# Check what tests run in the pipeline
cat .github/workflows/*.yml | grep -E "test|lint|check"

# Are there staging checks before production deploy?
grep -i "staging\|canary\|smoke" .github/workflows/*.yml
```

---

## Resolution

| Root Cause | Resolution |
|---|---|
| Low test coverage | Add unit + integration tests; enforce coverage thresholds in CI |
| No staging env | Create a staging environment; deploy to staging before prod |
| Big-bang releases | Break into smaller, more frequent deployments |
| No feature flags | Implement feature flags (LaunchDarkly, Unleash, env vars) |
| Manual steps | Automate all deployment steps; remove human intervention |

---

## Escalation

- Review CFR weekly in Engineering sync.
- If CFR exceeds 30%, pause all new feature deployments until root cause is addressed.
- Document a reliability improvement sprint if CFR remains elevated for 2+ weeks.
