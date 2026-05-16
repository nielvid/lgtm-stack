'use strict';

// ============================================================
// OpenTelemetry SDK initialisation — MUST be first
// ============================================================
const { NodeSDK } = require('@opentelemetry/sdk-node');
const { getNodeAutoInstrumentations } = require('@opentelemetry/auto-instrumentations-node');
const { OTLPTraceExporter } = require('@opentelemetry/exporter-trace-otlp-http');
const { OTLPMetricExporter } = require('@opentelemetry/exporter-metrics-otlp-http');
const { OTLPLogExporter } = require('@opentelemetry/exporter-logs-otlp-http');
const { Resource } = require('@opentelemetry/resources');
const { PeriodicExportingMetricReader } = require('@opentelemetry/sdk-metrics');
const { BatchLogRecordProcessor } = require('@opentelemetry/sdk-logs');
const { ATTR_SERVICE_NAME, ATTR_SERVICE_VERSION } = require('@opentelemetry/semantic-conventions');

const OTEL_ENDPOINT = process.env.OTEL_EXPORTER_OTLP_ENDPOINT || 'http://otel-collector:4318';

const sdk = new NodeSDK({
  resource: new Resource({
    [ATTR_SERVICE_NAME]: 'demo-app',
    [ATTR_SERVICE_VERSION]: '1.0.0',
    'deployment.environment': 'production',
    'cluster': 'lgtm-stack',
  }),
  traceExporter: new OTLPTraceExporter({ url: `${OTEL_ENDPOINT}/v1/traces` }),
  metricReader: new PeriodicExportingMetricReader({
    exporter: new OTLPMetricExporter({ url: `${OTEL_ENDPOINT}/v1/metrics` }),
    exportIntervalMillis: 10_000,
  }),
  logRecordProcessor: new BatchLogRecordProcessor(
    new OTLPLogExporter({ url: `${OTEL_ENDPOINT}/v1/logs` })
  ),
  instrumentations: [
    getNodeAutoInstrumentations({
      '@opentelemetry/instrumentation-http': { enabled: true },
      '@opentelemetry/instrumentation-express': { enabled: true },
    }),
  ],
});

sdk.start();
console.log('OpenTelemetry SDK started — exporting to', OTEL_ENDPOINT);

// Graceful shutdown
process.on('SIGTERM', () => sdk.shutdown().finally(() => process.exit(0)));
process.on('SIGINT',  () => sdk.shutdown().finally(() => process.exit(0)));

// ============================================================
// Prometheus metrics (prom-client) — scraped by Prometheus
// ============================================================
const client = require('prom-client');
const register = new client.Registry();
client.collectDefaultMetrics({ register, prefix: 'demo_app_' });

const httpRequestsTotal = new client.Counter({
  name: 'http_requests_total',
  help: 'Total number of HTTP requests',
  labelNames: ['method', 'path', 'status'],
  registers: [register],
});

const httpRequestDuration = new client.Histogram({
  name: 'http_request_duration_seconds',
  help: 'HTTP request duration in seconds',
  labelNames: ['method', 'path', 'status'],
  buckets: [0.005, 0.01, 0.025, 0.05, 0.1, 0.2, 0.5, 1, 2.5, 5],
  registers: [register],
});

// ============================================================
// Express application
// ============================================================
const express = require('express');
const { trace, context } = require('@opentelemetry/api');

const app  = express();
const PORT = process.env.APP_PORT || 8080;

// ---- Middleware: record metrics & structured logs -----------
app.use((req, res, next) => {
  const start = Date.now();
  res.on('finish', () => {
    const duration = (Date.now() - start) / 1000;
    const labels   = { method: req.method, path: req.route?.path || req.path, status: res.statusCode };

    httpRequestsTotal.inc(labels);
    httpRequestDuration.observe(labels, duration);

    // Structured log with traceId for Loki → Tempo correlation
    const span    = trace.getActiveSpan();
    const traceId = span?.spanContext()?.traceId ?? 'n/a';
    const spanId  = span?.spanContext()?.spanId  ?? 'n/a';

    console.log(JSON.stringify({
      timestamp: new Date().toISOString(),
      level:     res.statusCode >= 500 ? 'ERROR' : 'INFO',
      message:   `${req.method} ${req.path} ${res.statusCode} ${(duration * 1000).toFixed(1)}ms`,
      traceId,
      spanId,
      service_name: 'demo-app',
      method:   req.method,
      path:     req.path,
      status:   res.statusCode,
      duration_ms: (duration * 1000).toFixed(1),
    }));
  });
  next();
});

// ---- Routes ------------------------------------------------

// Health check (used by Blackbox Exporter & Docker healthcheck)
app.get('/health', (_req, res) => {
  res.json({ status: 'ok', timestamp: new Date().toISOString() });
});

// Prometheus metrics endpoint (scraped by Prometheus)
app.get('/metrics', async (_req, res) => {
  res.set('Content-Type', register.contentType);
  res.end(await register.metrics());
});

// Demo endpoint — fast response
app.get('/api/hello', (_req, res) => {
  res.json({ message: 'Hello from the LGTM demo app!', timestamp: new Date().toISOString() });
});

// Demo endpoint — simulates variable latency (P99 stress test)
app.get('/api/data', async (req, res) => {
  const latencyMs = Math.random() < 0.05
    ? Math.floor(Math.random() * 1500) + 500   // 5% of requests: 500–2000ms (slow)
    : Math.floor(Math.random() * 80)            // 95%: 0–80ms (fast)
  ;
  await new Promise(r => setTimeout(r, latencyMs));
  res.json({ data: Array.from({ length: 10 }, (_, i) => ({ id: i, value: Math.random() })) });
});

// Demo endpoint — simulates occasional errors (for error rate SLI)
app.get('/api/items', (req, res) => {
  if (Math.random() < 0.02) {
    // 2% chance of 500 error — keeps error rate below 5% SLO
    return res.status(500).json({ error: 'Internal Server Error', code: 'RANDOM_FAILURE' });
  }
  res.json({ items: ['alpha', 'beta', 'gamma', 'delta'], count: 4 });
});

// Demo endpoint — always errors (for triggering SLO burn in Game Day)
app.get('/api/chaos', (req, res) => {
  const mode = req.query.mode || 'ok';
  if (mode === 'error') return res.status(500).json({ error: 'Chaos mode enabled' });
  if (mode === 'slow')  return new Promise(r => setTimeout(() => { res.json({ ok: true }); r(); }, 3000));
  res.json({ ok: true, mode });
});

// 404 handler
app.use((_req, res) => {
  res.status(404).json({ error: 'Not Found' });
});

// ---- Start -------------------------------------------------
app.listen(PORT, () => {
  console.log(JSON.stringify({
    timestamp: new Date().toISOString(),
    level: 'INFO',
    message: `demo-app listening on port ${PORT}`,
    service_name: 'demo-app',
  }));
});
