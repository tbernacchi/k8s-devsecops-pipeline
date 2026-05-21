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
