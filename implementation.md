# implementation.md

## Overview

This document details the step-by-step process for building a production-grade observability and reliability platform using the LGTM stack (Loki, Grafana, Tempo, Prometheus), DORA metrics, SLOs, and full Infrastructure as Code (IaC) practices. It covers deployment, configuration, alerting, dashboards, incident management, and documentation requirements.

---

## 1. Deploy & Harden the Full LGTM Observability Stack

### 1.1. Stack Components

- **Prometheus**: Metrics collection and storage.
- **Loki**: Log aggregation and querying.
- **Tempo**: Distributed tracing backend.
- **Grafana**: Unified observability frontend.
- **Node Exporter**: System-level metrics (CPU, RAM, Disk, Network I/O).
- **Blackbox Exporter**: Uptime, HTTP response time, SSL expiry probing.
- **Alertmanager**: Dedicated alerting component.
- **OpenTelemetry Collector**: Ships logs to Loki, receives traces for Tempo.
- **Instrumented Service**: At least one service emits traces via OpenTelemetry.

### 1.2. Deployment Requirements

- **No container runtime** (Docker, Podman, etc.) is used. All services run directly on the host OS as native Linux binaries managed by **systemd** with `Restart=always` policies.
- Each service runs under its own dedicated non-root system user for security isolation.
- **Infrastructure as Code (IaC)**: All provisioning and configuration must be managed by Terraform. A single startup script installs all binaries, writes systemd unit files, and starts all services automatically on first boot. No manual steps allowed.
- All configuration files (Prometheus scrape configs, Alertmanager, Grafana dashboards, alert rules, systemd unit files, etc.) must be version-controlled.
- Document a single command to deploy the full stack via Terraform in the README (`terraform apply`).

### 1.3. Data Collection & Exporters

- Prometheus scrapes Node Exporter (15s interval) and Blackbox Exporter.
- Prometheus ingests CI/CD metrics from GitHub Actions.
- OpenTelemetry Collector ingests application/system logs into Loki and receives traces for Tempo.
- Set and document retention periods for metrics and logs.

---

## 2. Define the Four Golden Signals as SLIs

### 2.1. Golden Signals

- **Latency**: Request duration (separate successful/error).
- **Traffic**: Requests per second, connections, or jobs processed.
- **Errors**: Rate of failed requests (5xx, wrong content, timeouts).
- **Saturation**: Resource utilization (CPU, memory, disk, connection pool).

### 2.2. SLI Definition

- For each signal, write a PromQL expression producing a ratio or rate.
- Document each SLI and its PromQL in a dedicated markdown file.

---

## 3. Define SLOs & Error Budgets

### 3.1. SLO Targets

- For each SLI, define a Service Level Objective (SLO) target (e.g., 99.5% availability over 30 days).
- Document the rationale for each SLO.

### 3.2. Error Budgets

- Calculate error budget: (1 - SLO target) x measurement window.
- Build Grafana panels for error budget remaining and burn rate.
- Write and version-control an Error Budget Policy: actions at 50%/100% consumption, ownership, review cadence.

---

## 4. DORA Metrics & CI/CD Observability

### 4.1. DORA Metrics

- **Deployment Frequency (DF)**: How often deployments occur; classify per DORA benchmarks.
- **Lead Time for Changes (LTC)**: Time from commit to production, with sub-intervals.
- **Change Failure Rate (CFR)**: Percentage of failed/rolled-back deployments.
- **Mean Time to Restore (MTTR)**: Time from alert to resolution.

### 4.2. CI/CD Integration

- Connect Prometheus to GitHub Actions for CI/CD metrics.
- Alert on CFR and MTTR SLO breaches.
- Identify and document at least two sources of toil; propose and implement automation.

---

## 5. Build Grafana Dashboards (Provisioned as Code)

### 5.1. Dashboard Requirements

- **DORA Metrics Dashboard**: DF, LTC, CFR, MTTR, benchmarks, trends.
- **SLO & Error Budget Dashboard**: SLI vs. SLO gauges, error budget, burn rate, compliance history.
- **Node Exporter Dashboard**: CPU, memory, disk I/O, network I/O, load averages.
- **Blackbox Exporter Dashboard**: Uptime, HTTP response time, SSL expiry, probe success.
- **Unified Observability Dashboard**: Correlate metrics, logs, and traces; enable drill-down from metrics to logs (Loki) to traces (Tempo).

### 5.2. Provisioning

- All dashboards must be provisioned via JSON or YAML files, never via the Grafana UI.
- Store all dashboard files in version control.

### 5.3. Drill-Down Configuration

- Configure Grafana derived fields in Loki for clickable trace IDs linking to Tempo.
- Ensure users can trace from a metric spike to logs to traces to the responsible service/endpoint.

---

## 6. Configure the Alerting System

### 6.1. Alert Rules

- All alert rules must be in version-controlled YAML files.
- **Infrastructure Alerts**: CPU, memory, disk, downtime, with warning/critical/recovery thresholds.
- **SLO Burn Rate Alerts**: Multi-window (fast/slow burn), with durations to prevent flapping.
- **CI/CD Alerts**: CFR and MTTR SLO breaches.

### 6.2. Alertmanager Configuration

- Route alerts by service and severity.
- Inhibition rules to suppress noise when a host is unreachable.
- Document silencing configuration.

### 6.3. Slack Integration

- All alerts route to #DevOps-Alerts.
- Structured payloads: alert name/severity, host, metric value, Grafana link, runbook link, status.
- Use Alertmanager templates for formatting.

---

## 7. Incident Management & Runbooks

### 7.1. Runbooks

- For every alert, write a Markdown runbook: alert description, likely causes, first 3 investigation steps, resolution, rollback/escalation guidance.

### 7.2. Post-Incident Review (PIR)

- Simulate or document one incident: timeline, root cause, impact, detection/response gaps, action items with owners/due dates.

---

## 8. Game Day: Chaos & Failure Simulation

### 8.1. Scenarios

- **Deployment Failure**: Trigger a failed deployment, observe DORA/CFR alert, document timeline.
- **Latency Injection**: Simulate high latency, observe SLI/SLO/burn rate/alert/trace.
- **Resource Pressure**: Simulate CPU/memory pressure, confirm alert sequence and recovery.

### 8.2. Documentation

- Screenshot every step: trigger, degradation, alert, trace, recovery.

---

## 9. Documentation & Submission

### 9.1. Blog Post

- Cover all setup steps, rationale, screenshots of dashboards, alert rules, Alertmanager config, Slack notifications, Game Day, and runbook.
- Explain LGTM stack choice, SLI/SLO/error budget philosophy, DORA metrics, burn rate alerting, and toil reduction.

### 9.2. GitHub Repository Structure

- **/terraform/**: All IaC — GCP Compute Engine VM, firewall rules, startup bootstrap script.
- **/prometheus/**: prometheus.yml, alert rules, SLO definitions.
- **/alertmanager/**: Alertmanager config and Slack templates.
- **/grafana/**: Provisioned dashboard JSON/YAML files and datasource configs.
- **/loki/**: Loki configuration.
- **/tempo/**: Tempo configuration.
- **/otel-collector/**: OpenTelemetry Collector configuration.
- **/blackbox/**: Blackbox Exporter probe modules.
- **/systemd/**: Systemd unit files for all 9 services.
- **/app/**: OpenTelemetry-instrumented Node.js demo service.
- **/runbooks/**: Markdown runbooks for each alert.
- **/docs/**: SLI/SLO definitions, error budget policy, PIR.
- **README.md**: Error budget policy, dashboard guide, Terraform deployment guide.

### 9.3. Evidence Screenshots

- All LGTM components running.
- SLO & Error Budget dashboard.
- DORA metrics dashboard.
- Node Exporter and Blackbox dashboards.
- Unified log & trace correlation.
- Alert rules and Alertmanager config.
- Slack notifications (firing/resolved).
- Game Day scenario sequences.

### 9.4. Reliability Documentation

- Four Golden Signals SLI definitions (with PromQL).
- SLO targets and rationale.
- Error budget calculations and policy.
- Runbooks for all alerts.
- One blameless PIR.

---

## 10. Verification

- All components must be reproducible via IaC (Terraform) — `terraform apply` provisions and starts the full stack.
- All services must be running as **systemd services** — verify with `systemctl status <service>`.
- All dashboards and alert rules must be version-controlled.
- All alerts must route to Slack with structured payloads.
- Drill-down from metrics to logs to traces must be functional.
- All documentation, runbooks, and evidence must be present in the repository.

---

**End of implementation.md**
