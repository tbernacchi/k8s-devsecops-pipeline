# k6 — Load Tests

Performance tests targeting the frontend and backend services via Traefik Gateway.

## Prerequisite

```bash
brew install k6
```

## Scripts

| Script | Type | VUs | Duration | Purpose |
|--------|------|-----|----------|---------|
| `smoke.js` | Smoke | 1 | 1m | Validate endpoints respond, confirm Prometheus metrics appear |
| `load.js` | Load | 20→50 | ~16m | Golden signals benchmark under normal/elevated load |

## Run

```bash
cd devsecops/tests/k6

# smoke first — always
k6 run smoke.js

# load after smoke passes
k6 run load.js

# override target cluster
k6 run smoke.js -e BASE_URL=https://traefik.mykubernetes.com
```

After each run, open the HTML report:
```bash
open smoke-summary.html
open load-summary.html
```

## Golden signals — Prometheus queries

After running the load test, validate metrics in Prometheus (`https://traefik.mykubernetes.com/prometheus`):

**Traffic (requests/s):**
```promql
rate(traefik_service_requests_total{service=~"frontend-stable.*|backend-stable.*"}[2m])
```

**Error rate:**
```promql
rate(traefik_service_requests_total{service=~"frontend-stable.*|backend-stable.*",code=~"5.."}[2m])
/
rate(traefik_service_requests_total{service=~"frontend-stable.*|backend-stable.*"}[2m])
```

**Latency p99:**
```promql
histogram_quantile(0.99,
  rate(traefik_service_request_duration_seconds_bucket{service=~"frontend-stable.*|backend-stable.*"}[2m])
)
```

**Saturation — memory available:**
```promql
node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
```

## Thresholds

| Signal | Threshold |
|--------|-----------|
| Latency p95 | < 2000ms |
| Latency p99 | < 5000ms |
| Error rate | < 1% |
| Per-endpoint p95 | < 1000ms |
