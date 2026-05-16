# LGTM Observability Stack

> **Production-grade observability and reliability platform** using the full LGTM stack (Loki, Grafana, Tempo, Prometheus) with DORA metrics, SLOs, error budgets, multi-window burn rate alerting, and full Infrastructure as Code.

---

## Quick Start

```bash
# 1. Clone the repo
git clone https://github.com/your-org/lgtm-stack.git
cd lgtm-stack

# 2. Create your environment file
cp .env.example .env
# Edit .env — set SLACK_WEBHOOK_URL, GF_SECURITY_ADMIN_PASSWORD, etc.

# 3. Bring up the full stack (one command)
docker compose up -d

# 4. Verify all 10 services are healthy
docker compose ps
```

**Grafana** is available at `http://localhost:3000` (default: `admin` / `changeme` — change in `.env`).

---

## Stack Components & Port Map

| Service | Port | Description |
|---|---|---|
| **Grafana** | `3000` | Unified observability frontend — dashboards |
| **Prometheus** | `9090` | Metrics collection & storage |
| **Alertmanager** | `9093` | Alert routing & Slack notifications |
| **Loki** | `3100` | Log aggregation |
| **Tempo** | `3200` | Distributed tracing backend |
| **OTel Collector** | `4317` (gRPC), `4318` (HTTP) | Telemetry ingestion gateway |
| **Node Exporter** | `9100` | Host system metrics |
| **Blackbox Exporter** | `9115` | HTTP / SSL probes |
| **Pushgateway** | `9091` | DORA metrics from GitHub Actions |
| **Demo App** | `8080` | OTel-instrumented sample service |

---

## Grafana Dashboards

All dashboards are **provisioned as code** — never via the Grafana UI.

| Dashboard | UID | Purpose |
|---|---|---|
| DORA Metrics | `dora-metrics` | DF, LTC, CFR, MTTR with DORA benchmarks |
| SLO & Error Budget | `slo-error-budget` | Availability SLI gauge, error budget, burn rates |
| Node Exporter | `node-exporter` | CPU, memory, disk I/O, network, load |
| Blackbox Exporter | `blackbox-exporter` | Uptime, HTTP response time, SSL expiry |
| Unified Observability | `unified-observability` | Four Golden Signals + logs + traces correlation |

---

## Alerting

All alert rules are version-controlled YAML files in `prometheus/rules/`:

| Rule File | Alerts |
|---|---|
| `infrastructure.yml` | `HighCPUWarning/Critical`, `HighMemoryWarning/Critical`, `DiskAlmostFullWarning/Critical`, `InstanceDown`, `SSLCertExpiryWarning/Critical`, `HTTPProbeFailure` |
| `slo_burn_rate.yml` | `SLOBurnRateFast` (14×), `SLOBurnRateSlow` (6×), `HighLatencySLOBreach`, `HighErrorRateSLOBreach` |
| `cicd.yml` | `HighChangeFailureRate`, `HighMTTR`, `LowDeploymentFrequency` |

### Slack Integration

All alerts route to `#DevOps-Alerts` via Alertmanager with structured payloads:
- Alert name, severity, instance, description
- Runbook link (clickable)
- Grafana dashboard link
- Status emoji (🔥 firing / ✅ resolved)

Set your `SLACK_WEBHOOK_URL` in `.env` before starting.

---

## DORA Metrics via GitHub Actions

The `.github/workflows/dora_metrics.yml` workflow automatically pushes all four DORA metrics to the Pushgateway on every push to `main`:

| Metric | How measured |
|---|---|
| **Deployment Frequency** | Count of successful pushes to `main` |
| **Lead Time for Changes** | Earliest commit timestamp → workflow completion |
| **Change Failure Rate** | Revert commits detected → marked as `failure` |
| **MTTR** | Time from failure workflow to next success |

**Required GitHub Actions Secrets**:
- `PUSHGATEWAY_URL` — set to `http://<VM-IP>:9091` (output by Terraform)

---

## GCP Terraform Deployment

```bash
cd terraform

# Authenticate with GCP
gcloud auth application-default login

# Initialise
terraform init

# Review the plan
terraform plan \
  -var="project_id=your-gcp-project-id" \
  -var="zone=us-central1-a" \
  -var="ssh_pub_key_path=~/.ssh/id_rsa.pub"

# Apply — creates the VM, firewall rules, and bootstraps the stack
terraform apply \
  -var="project_id=your-gcp-project-id" \
  -var="zone=us-central1-a" \
  -var="ssh_pub_key_path=~/.ssh/id_rsa.pub"

# Outputs after apply:
# vm_external_ip     = "35.x.x.x"
# grafana_url        = "http://35.x.x.x:3000"
# pushgateway_url    = "http://35.x.x.x:9091"
# ssh_command        = "ssh ubuntu@35.x.x.x"
```

Update `terraform/startup.sh` with your actual repo URL before applying.

---

## SLI / SLO Definitions

See [`docs/sli_slo_definitions.md`](docs/sli_slo_definitions.md) for full PromQL definitions of the Four Golden Signals.

| SLO | Target | Window |
|---|---|---|
| Availability | ≥ 99.5% | 30 days |
| Latency P99 | < 200ms | 30 days |
| Error Rate | < 5% | Rolling |
| CPU Saturation | < 80% | — |

---

## Error Budget Policy

See [`docs/error_budget_policy.md`](docs/error_budget_policy.md) for the full policy.

| Consumption | Action |
|---|---|
| 50% | Investigate burn rate; pause non-critical deploys if accelerating |
| 100% | Halt all deployments; mandatory blameless PIR within 24h |

**Review cadence**: Weekly status, quarterly SLO target review.

---

## Runbooks

| Alert | Runbook |
|---|---|
| `HighCPU` | [runbooks/high_cpu.md](runbooks/high_cpu.md) |
| `HighMemory` | [runbooks/high_memory.md](runbooks/high_memory.md) |
| `DiskAlmostFull` | [runbooks/disk_almost_full.md](runbooks/disk_almost_full.md) |
| `InstanceDown` / `HTTPProbeFailure` | [runbooks/instance_down.md](runbooks/instance_down.md) |
| `SSLCertExpiry` | [runbooks/ssl_expiry.md](runbooks/ssl_expiry.md) |
| `SLOBurnRateFast` | [runbooks/slo_burn_fast.md](runbooks/slo_burn_fast.md) |
| `SLOBurnRateSlow` | [runbooks/slo_burn_slow.md](runbooks/slo_burn_slow.md) |
| `HighChangeFailureRate` | [runbooks/high_cfr.md](runbooks/high_cfr.md) |
| `HighMTTR` | [runbooks/high_mttr.md](runbooks/high_mttr.md) |

---

## Toil Reduction

Two sources of toil identified and automated:

1. **SSL Certificate Renewal** — `SSLCertExpiryWarning` fires at 30 days, `SSLCertExpiryCritical` at 7 days, giving time for Certbot auto-renewal to catch failures before expiry.
2. **Manual Deployment Health Checks** — GitHub Actions DORA workflow auto-publishes deployment status; `HighChangeFailureRate` alert catches pipeline instability automatically.

---

## Repository Structure

```
lgtm-stack/
├── docker-compose.yml          # Full 10-service stack
├── .env.example                # Environment variables template
├── .github/workflows/
│   └── dora_metrics.yml        # DORA metrics → Pushgateway
├── prometheus/                 # Scrape configs + 3 alert rule files
├── alertmanager/               # Routing config + Slack templates
├── loki/                       # Log aggregation config
├── tempo/                      # Tracing backend config
├── otel-collector/             # Telemetry collector config
├── blackbox/                   # HTTP / SSL probe modules
├── grafana/provisioning/       # 5 dashboards + datasources (IaC)
├── app/                        # OTel-instrumented demo service
├── runbooks/                   # 9 alert runbooks (Markdown)
├── docs/                       # SLI/SLO, error budget policy, PIR
├── terraform/                  # GCP Terraform (VM + firewall)
└── README.md
```

---

## Verification

After `docker compose up -d`, run:

```bash
# All services healthy
docker compose ps

# Individual health checks
curl http://localhost:9090/-/healthy       # Prometheus
curl http://localhost:3100/ready           # Loki
curl http://localhost:3200/ready           # Tempo
curl http://localhost:3000/api/health      # Grafana
curl http://localhost:9091/-/healthy       # Pushgateway
curl http://localhost:8080/health          # Demo app
curl "http://localhost:9115/probe?target=https://example.com&module=http_2xx"  # Blackbox

# Test alert pipeline
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Test"}}]'
```
