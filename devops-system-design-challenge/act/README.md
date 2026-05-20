# Running GitHub Actions locally with `act`

This guide explains how to run this repository workflows locally using [`act`](https://github.com/nektos/act).

## Prerequisites

- Docker running locally
- `act` installed
- Run commands from the **git repository root**:

```bash
cd /Users/tadeu/projects/system-design-2026
```

> Note for Apple Silicon (M1/M2/M3): always use `--container-architecture linux/amd64`.

---

## 1) Set secrets

Create a local secrets file:

```bash
cat > .secrets.act <<'EOF'
GITHUB_TOKEN=ghp_xxx
SONAR_TOKEN=sonar_xxx
SONAR_HOST_URL=https://your-sonarqube.example.com
SNYK_TOKEN=snyk_xxx

DEV_KUBECONFIG_B64=
STAGING_KUBECONFIG_B64=
PROD_KUBECONFIG_B64=
STAGING_BASE_URL=https://staging.example.com
PROD_BASE_URL=https://prod.example.com
EOF
```

Optional quality-of-life (avoid repeating architecture flag every time):

```bash
export ACT_CONTAINER_ARCH=linux/amd64
```

---

## 2) Test frontend pipeline

```bash
act pull_request \
  -W .github/workflows/frontend.yml \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

---

## 3) Test backend pipeline

```bash
act pull_request \
  -W .github/workflows/backend.yml \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

---

## 4) Test as `push` on `main`

Create a push event payload:

```bash
cat > act/event-main.json <<'EOF'
{
  "ref": "refs/heads/main"
}
EOF
```

Run frontend workflow as push:

```bash
act push \
  -W .github/workflows/frontend.yml \
  -e act/event-main.json \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

Run backend workflow as push:

```bash
act push \
  -W .github/workflows/backend.yml \
  -e act/event-main.json \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

---

## Run specific jobs

List available jobs first:

```bash
act -W .github/workflows/frontend.yml -l
act -W .github/workflows/backend.yml -l
```

Run only one caller job:

```bash
act pull_request \
  -W .github/workflows/frontend.yml \
  -j frontend \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

```bash
act pull_request \
  -W .github/workflows/backend.yml \
  -j backend \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

### Run a specific stage from the reusable workflow

You can run the reusable workflow directly and select one job with `-j`:

```bash
act workflow_call \
  -W .github/workflows/reusable-app-pipeline.yml \
  -j stage2_sast \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

```bash
act workflow_call \
  -W .github/workflows/reusable-app-pipeline.yml \
  -j stage4_container_iac_scanning \
  --secret-file .secrets.act \
  --container-architecture linux/amd64
```

If your local `act` version has limited `workflow_call` support, run the caller workflow job (`frontend` or `backend`) instead.
