# Frontend (Python/Flask)

Interface web simples para criar usuarios no backend.

## Pre-requisitos

- Python 3.10+ (ou compativel com suas libs)
- Backend rodando e acessivel

## Variaveis de ambiente

- `BACKEND_HOST` (obrigatoria)
- `BACKEND_PORT` (obrigatoria)

Exemplo:

```bash
export BACKEND_HOST=localhost
export BACKEND_PORT=8080
```

## Rodar localmente

No diretorio `devsecops/frontend/src/frontend`:

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt
BACKEND_HOST=localhost BACKEND_PORT=8080 python frontend.py
```

A aplicacao sobe em `http://localhost:8000`.

## Observability (Prometheus)

ServiceMonitor at `devsecops/k8s/apps/frontend/service-monitor.yaml` is created but **not deployed**.
To enable app-level metric scraping:

1. Expose `/metrics` via `prometheus_client`:

```python
from prometheus_client import make_wsgi_app, Counter, Histogram
from werkzeug.middleware.dispatcher import DispatcherMiddleware

app.wsgi_app = DispatcherMiddleware(app.wsgi_app, {"/metrics": make_wsgi_app()})
```

2. Confirm Helm release name matches:

```bash
helm list -n monitoring  # release name must be prometheus-stack
```

3. Deploy:

```bash
kubectl apply -f devsecops/k8s/apps/frontend/service-monitor.yaml
kubectl get servicemonitor -n app-frontend
```

> **Note:** automatic rollback via AnalysisTemplate does **not** depend on this ServiceMonitor —
> it uses Traefik metrics (`traefik_service_requests_total`). ServiceMonitor is optional and
> enables dashboards with internal app metrics (request duration, error counters, custom business metrics).

## Healthcheck

- `GET /healthz`

## Rodar com Docker

No diretorio `devsecops/frontend`:

```bash
docker build -t frontend:local .
docker run --rm -p 8000:8000 \
  -e BACKEND_HOST=host.docker.internal \
  -e BACKEND_PORT=8080 \
  frontend:local
```
