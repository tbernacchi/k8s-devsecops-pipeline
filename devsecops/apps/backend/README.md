# Backend (Go)

Aplicacao REST de usuarios (CRUD) em Go.

## Pre-requisitos

- Go 1.21+
- PostgreSQL acessivel

## Variaveis de ambiente

- `DB_WRITE_DSN` (obrigatoria)
- `DB_READ_DSN` (opcional; se nao informar, usa o valor de `DB_WRITE_DSN`)

Exemplo:

```bash
export DB_WRITE_DSN="postgres://system-design:system-design@localhost:5432/system-design?sslmode=disable" # pragma: allowlist secret
export DB_READ_DSN="postgres://system-design:system-design@localhost:5432/system-design?sslmode=disable" # pragma: allowlist secret
```

## Rodar localmente

No diretorio `devsecops/backend`:

```bash
go mod download
go run main.go
```

A API sobe em `http://localhost:8080`.

## Observability (Prometheus)

ServiceMonitor at `devsecops/k8s/apps/backend/service-monitor.yaml` is created but **not deployed**.
To enable app-level metric scraping:

1. Expose `/metrics` via `prometheus/client_golang`:

```go
import "github.com/prometheus/client_golang/prometheus/promhttp"

http.Handle("/metrics", promhttp.Handler())
```

2. Confirm Helm release name matches:

```bash
helm list -n monitoring  # release name must be prometheus-stack
```

3. Deploy:

```bash
kubectl apply -f devsecops/k8s/apps/backend/service-monitor.yaml
kubectl get servicemonitor -n app-backend
```

> **Note:** automatic rollback via AnalysisTemplate does **not** depend on this ServiceMonitor —
> it uses Traefik metrics (`traefik_service_requests_total`). ServiceMonitor is optional and
> enables dashboards with internal app metrics (DB latency, goroutines, custom business metrics).

## Endpoints principais

- `GET /healthz`
- `GET /users`
- `GET /users/{id}`
- `POST /users`
- `PUT /users/{id}`
- `DELETE /users/{id}`

## Rodar com Docker

No diretorio `devsecops/backend`:

```bash
docker build -t backend:local .
docker run --rm -p 8080:8080 \
  -e DB_WRITE_DSN="postgres://system-design:system-design@host.docker.internal:5432/system-design?sslmode=disable" \ # pragma: allowlist secret
  -e DB_READ_DSN="postgres://system-design:system-design@host.docker.internal:5432/system-design?sslmode=disable" \ # pragma: allowlist secret
  backend:local
```
