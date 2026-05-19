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
export DB_WRITE_DSN="postgres://system-design:system-design@localhost:5432/system-design?sslmode=disable"
export DB_READ_DSN="postgres://system-design:system-design@localhost:5432/system-design?sslmode=disable"
```

## Rodar localmente

No diretorio `devops-system-design-challenge/backend`:

```bash
go mod download
go run main.go
```

A API sobe em `http://localhost:8080`.

## Endpoints principais

- `GET /healthz`
- `GET /users`
- `GET /users/{id}`
- `POST /users`
- `PUT /users/{id}`
- `DELETE /users/{id}`

## Rodar com Docker

No diretorio `devops-system-design-challenge/backend`:

```bash
docker build -t backend:local .
docker run --rm -p 8080:8080 \
  -e DB_WRITE_DSN="postgres://system-design:system-design@host.docker.internal:5432/system-design?sslmode=disable" \
  -e DB_READ_DSN="postgres://system-design:system-design@host.docker.internal:5432/system-design?sslmode=disable" \
  backend:local
```
