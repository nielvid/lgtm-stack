# DORA Four Golden Signals — SLI Definitions

## Overview

This document defines the four Service Level Indicators (SLIs) for the LGTM stack demo application, each expressed as a PromQL ratio. These SLIs form the basis of the SLOs in `slo_definitions.md`.

---

## 1. Latency (Request Duration)

**Definition**: Proportion of requests served within the latency threshold.

### SLI PromQL

```promql
# P99 latency (seconds) — SLO: < 200ms
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket{job="demo-app"}[5m])) by (le)
)

# Ratio: requests completing within 200ms
sum(rate(http_request_duration_seconds_bucket{job="demo-app",le="0.2"}[5m]))
/
sum(rate(http_request_duration_seconds_count{job="demo-app"}[5m]))
```

**Separate Successful vs Error Latency:**

```promql
# Successful requests only
histogram_quantile(0.99,
  sum(rate(http_request_duration_seconds_bucket{job="demo-app",status!~"5.."}[5m])) by (le)
)
```

---

## 2. Traffic (Request Rate)

**Definition**: Rate of requests received per second, indicating service demand.

### SLI PromQL

```promql
# Requests per second
sum(rate(http_requests_total{job="demo-app"}[2m]))

# By status code breakdown
sum(rate(http_requests_total{job="demo-app"}[2m])) by (status)

# By HTTP method
sum(rate(http_requests_total{job="demo-app"}[2m])) by (method)
```

---

## 3. Errors (Error Rate)

**Definition**: Ratio of failed requests (HTTP 5xx) to total requests.

### SLI PromQL

```promql
# Error ratio (SLO: < 5% errors)
sum(rate(http_requests_total{job="demo-app",status=~"5.."}[5m]))
/
sum(rate(http_requests_total{job="demo-app"}[5m]))

# Availability (inverse error ratio) — used as the primary SLO SLI
sum(rate(http_requests_total{job="demo-app",status!~"5.."}[5m]))
/
sum(rate(http_requests_total{job="demo-app"}[5m]))
```

---

## 4. Saturation (Resource Utilization)

**Definition**: How close the system is to its capacity limits.

### CPU Saturation PromQL

```promql
# CPU usage percentage
100 - (avg by(instance)(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100)

# Ratio form (SLO: < 80%)
avg(rate(node_cpu_seconds_total{mode!="idle"}[5m]))
/
(count(node_cpu_seconds_total{mode="idle"}) without (mode))
```

### Memory Saturation PromQL

```promql
# Memory usage percentage
(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100

# Ratio form (SLO: < 85%)
1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)
```

### Disk Saturation PromQL

```promql
# Disk usage percentage
(1 - (node_filesystem_avail_bytes{fstype!~"tmpfs|fuse.lxcfs"}
     / node_filesystem_size_bytes{fstype!~"tmpfs|fuse.lxcfs"})) * 100
```

---

## Recording Rules

The following recording rules (in `prometheus/rules/slo_burn_rate.yml`) pre-compute the availability SLI at multiple windows:

| Rule Name | Window | Purpose |
|---|---|---|
| `job:http_request_success:ratio_rate5m` | 5m | Fast burn detection |
| `job:http_request_success:ratio_rate30m` | 30m | Slow burn detection |
| `job:http_request_success:ratio_rate1h` | 1h | SLO compliance view |
| `job:http_request_success:ratio_rate6h` | 6h | Trend analysis |
