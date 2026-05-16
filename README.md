# LGTM Observability Stack

> **Production-grade observability and reliability platform** using the full LGTM stack (Loki, Grafana, Tempo, Prometheus) with DORA metrics, SLOs, error budgets, multi-window burn rate alerting, and full Infrastructure as Code on GCP.
>
> **All services run as native Linux binaries managed by systemd — no Docker or container runtime is used.**

---

## Deployment (One Command via Terraform)

```bash
cd terraform

# Authenticate with GCP
gcloud auth application-default login

# Initialise
terraform init

# Preview what will be created
terraform plan \
  -var="project_id=your-gcp-project-id" \
  -var="zone=us-central1-a" \
  -var="ssh_pub_key_path=~/.ssh/id_rsa.pub"

# Apply — provisions VM, installs all binaries, starts all services via systemd
terraform apply \
  -var="project_id=your-gcp-project-id" \
  -var="zone=us-central1-a" \
  -var="ssh_pub_key_path=~/.ssh/id_rsa.pub"
```

After `terraform apply` completes, the startup script runs automatically and:
1. Downloads all service binaries (Prometheus, Loki, Tempo, Grafana, Node Exporter, Blackbox Exporter, Alertmanager, OTel Collector, Pushgateway)
2. Installs them as systemd services under dedicated system users
3. Copies all configs from the repo to their system paths
4. Enables and starts all 10 services

**Terraform outputs:**
```
vm_external_ip  = "35.x.x.x"
grafana_url     = "http://35.x.x.x:3000"
pushgateway_url = "http://35.x.x.x:9091"
ssh_command     = "ssh ubuntu@35.x.x.x"
```

---

## First-Time Setup After Deploy

```bash
# SSH into the VM
ssh ubuntu@<VM-IP>

# Edit the environment file with real secrets
sudo nano /opt/lgtm-stack/.env
# Set: SLACK_WEBHOOK_URL, GF_SECURITY_ADMIN_PASSWORD

# Restart affected services after env changes
sudo systemctl restart alertmanager grafana-server
```

---

## Verify All Services Are Running

```bash
# Check status of all services at once
sudo systemctl status prometheus alertmanager loki tempo \
  otelcol-contrib node-exporter blackbox-exporter pushgateway \
  grafana-server demo-app

# Individual health checks
curl http://localhost:9090/-/healthy       # Prometheus
curl http://localhost:3100/ready           # Loki
curl http://localhost:3200/ready           # Tempo
curl http://localhost:3000/api/health      # Grafana
curl http://localhost:9091/-/healthy       # Pushgateway
curl http://localhost:8080/health          # Demo app
curl "http://localhost:9115/probe?target=https://example.com&module=http_2xx"

# View logs for any service
sudo journalctl -u prometheus -f
sudo journalctl -u loki -f
sudo journalctl -u demo-app -f
```

---

## Stack Components & Port Map

| Service | Port | Systemd Unit | Description |
|---|---|---|---|
| **Grafana** | `3000` | `grafana-server` | Unified observability frontend |
| **Prometheus** | `9090` | `prometheus` | Metrics collection & storage |
| **Alertmanager** | `9093` | `alertmanager` | Alert routing & Slack notifications |
| **Loki** | `3100` | `loki` | Log aggregation |
| **Tempo** | `3200` | `tempo` | Distributed tracing backend |
| **OTel Collector** | `4317` (gRPC), `4318` (HTTP) | `otelcol-contrib` | Telemetry ingestion gateway |
| **Node Exporter** | `9100` | `node-exporter` | Host system metrics |
| **Blackbox Exporter** | `9115` | `blackbox-exporter` | HTTP / SSL probes |
| **Pushgateway** | `9091` | `pushgateway` | DORA metrics from GitHub Actions |
| **Demo App** | `8080` | `demo-app` | OTel-instrumented sample service |

---

## Service Management

```bash
# Start / stop / restart any service
sudo systemctl start prometheus
sudo systemctl stop loki
sudo systemctl restart alertmanager

# Reload Prometheus config without restart (hot-reload)
sudo systemctl reload prometheus
# or: curl -X POST http://localhost:9090/-/reload

# Check service logs
sudo journalctl -u tempo --since "1 hour ago"
sudo journalctl -u otelcol-contrib -n 100

# Restart all LGTM services
for svc in prometheus alertmanager loki tempo otelcol-contrib \
           node-exporter blackbox-exporter pushgateway grafana-server demo-app; do
  sudo systemctl restart "$svc"
done
```

---

## Grafana Dashboards

All dashboards are **provisioned as code** — never via the Grafana UI.
Config files live in `/etc/grafana/provisioning/` on the VM (copied from the repo).

| Dashboard | UID | Purpose |
|---|---|---|
| DORA Metrics | `dora-metrics` | DF, LTC, CFR, MTTR with DORA benchmarks |
| SLO & Error Budget | `slo-error-budget` | Availability SLI gauge, error budget, burn rates |
| Node Exporter | `node-exporter` | CPU, memory, disk I/O, network, load |
| Blackbox Exporter | `blackbox-exporter` | Uptime, HTTP response time, SSL expiry |
| Unified Observability | `unified-observability` | Four Golden Signals + logs + traces correlation |

---

## Alerting

All alert rules live in `/etc/prometheus/rules/` on the VM (versioned in `prometheus/rules/`):

| Rule File | Alerts |
|---|---|
| `infrastructure.yml` | `HighCPUWarning/Critical`, `HighMemoryWarning/Critical`, `DiskAlmostFullWarning/Critical`, `InstanceDown`, `SSLCertExpiryWarning/Critical`, `HTTPProbeFailure` |
| `slo_burn_rate.yml` | `SLOBurnRateFast` (14×), `SLOBurnRateSlow` (6×), `HighLatencySLOBreach`, `HighErrorRateSLOBreach` |
| `cicd.yml` | `HighChangeFailureRate`, `HighMTTR`, `LowDeploymentFrequency` |

### Slack Integration

All alerts route to `#DevOps-Alerts`. Set `SLACK_WEBHOOK_URL` in `/opt/lgtm-stack/.env`.

Test the alert pipeline:
```bash
curl -X POST http://localhost:9093/api/v1/alerts \
  -H 'Content-Type: application/json' \
  -d '[{"labels":{"alertname":"TestAlert","severity":"warning"},"annotations":{"summary":"Pipeline test"}}]'
```

---

## DORA Metrics via GitHub Actions

`.github/workflows/dora_metrics.yml` pushes all four DORA metrics to the Pushgateway on every push to `main`.

**Required GitHub Actions Secret**: `PUSHGATEWAY_URL` = `http://<VM-IP>:9091` (shown in `terraform apply` output).

| Metric | How measured |
|---|---|
| **Deployment Frequency** | Count of successful pushes to `main` |
| **Lead Time for Changes** | Earliest commit timestamp → workflow completion |
| **Change Failure Rate** | Revert commits detected → marked as `failure` |
| **MTTR** | Time from failure workflow to next success |

---

## SLI / SLO Definitions

See [`docs/sli_slo_definitions.md`](docs/sli_slo_definitions.md) for full PromQL definitions.

| SLO | Target | Window |
|---|---|---|
| Availability | ≥ 99.5% | 30 days |
| Latency P99 | < 200ms | 30 days |
| Error Rate | < 5% | Rolling |
| CPU Saturation | < 80% | — |

---

## Error Budget Policy

See [`docs/error_budget_policy.md`](docs/error_budget_policy.md).

| Consumption | Action |
|---|---|
| 50% | Investigate burn rate; pause non-critical deploys if accelerating |
| 100% | Halt all deployments; mandatory blameless PIR within 24h |

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

## Repository Structure

```
lgtm-stack/
├── .env.example                # Environment variables template
├── .github/workflows/
│   └── dora_metrics.yml        # DORA metrics → Pushgateway on push to main
├── prometheus/                 # Scrape config + 3 alert rule files
├── alertmanager/               # Routing config + Slack templates
├── loki/                       # Log aggregation config
├── tempo/                      # Tracing backend config
├── otel-collector/             # Telemetry collector config
├── blackbox/                   # HTTP / SSL probe modules
├── grafana/provisioning/       # 5 dashboards + datasources (all IaC)
├── systemd/                    # Systemd unit files for all 9 services
├── app/                        # OTel-instrumented Node.js demo service
├── runbooks/                   # 9 alert runbooks (Markdown)
├── docs/                       # SLI/SLO, error budget policy, PIR
├── terraform/                  # GCP Terraform + startup bootstrap script
└── README.md
```

---

## Updating Configuration

After changing any config file in the repo, push to `main` then on the VM:

```bash
cd /opt/lgtm-stack && sudo git pull origin main

# Re-apply configs and reload
sudo cp prometheus/prometheus.yml /etc/prometheus/prometheus.yml
sudo cp prometheus/rules/*.yml /etc/prometheus/rules/
sudo systemctl reload prometheus

sudo cp loki/loki-config.yaml /etc/loki/loki-config.yaml
sudo systemctl restart loki

# Grafana dashboards (auto-reload every 30s, or force)
sudo cp grafana/provisioning/dashboards/*.json /etc/grafana/provisioning/dashboards/
sudo systemctl restart grafana-server
```
