# k8s-devsecops-pipeline

Practice repository for **System Design**, **Software Architecture**, and **DevSecOps**.

## devsecops/

The main focus of this repo is a **production-grade DevSecOps pipeline** built with GitHub Actions, targeting a Python frontend and Go backend deployed on a self-hosted K3s cluster (Raspberry Pi 4, ARM64).

### Pipelines

Three independent pipelines, all using a shared reusable workflow:

| Pipeline | File | Trigger paths |
|----------|------|---------------|
| Frontend | `frontend.yml` | `devsecops/apps/frontend/**` |
| Backend | `backend.yml` | `devsecops/apps/backend/**` |
| Infra | `infra.yml` | `devsecops/infra/**`, `devsecops/k8s/**` |

### App pipeline — 10 stages

| Stage | Name | Tools | Runner |
|-------|------|-------|--------|
| 1 | Secret Detection | detect-secrets, Gitleaks, TruffleHog | `ubuntu-latest` |
| 2 | Unit Tests + Code Quality | pytest / go test, SonarQube Quality Gate | `ubuntu-latest` |
| 3 | SAST | Semgrep, CodeQL | `ubuntu-latest` |
| 4 | SCA | Trivy (fs), OWASP Dependency Check, Snyk CLI | `ubuntu-latest` |
| 5 | Build + Sign + Attest | Docker buildx → GHCR, Cosign (keyless), SLSA provenance | `ubuntu-latest` |
| 6 | Deploy Dev *(optional)* | kubectl + smoke test (port-forward → healthz) | `k8s-system-design` |
| 7 | Deploy Staging *(optional)* | kubectl + smoke test (port-forward → healthz) | `k8s-system-design` |
| 8 | DAST | OWASP ZAP | `k8s-system-design` |
| 9 | Policy Gate | Cosign signature verify | `k8s-system-design` |
| 10 | Prod Deploy | Argo Rollouts canary (20%→50%→100%), Prometheus error-rate analysis, auto rollback (manual approval) | `k8s-system-design` |

Stages 1–5 run on GitHub-hosted AMD64 runners. Stages 6–10 run on a self-hosted ARC runner inside the K3s cluster (ARM64).

**Deploy flags** — Stages 6 and 7 are skipped by default. Pass `deploy_dev: true` or `deploy_staging: true` via `workflow_dispatch` inputs or in the caller's `with:` block to enable. Stages 8–10 always run on `main`.

**Single-stage dispatch** — Pass `run_only_stage: N` (1–10) to run only that stage. Empty (default) = full pipeline. Useful to re-run a failing stage without repeating the entire pipeline from scratch.

### Canary deployment (Stage 10)

Prod deploy uses **Argo Rollouts** with Traefik weighted traffic splitting. No app code changes needed — Prometheus scrapes `traefik_service_requests_total` metrics at the ingress level.

```
new image pushed
  → 20% canary traffic
  → AnalysisRun: error rate < 5% over 3×60s ? → promote to 50%
  → AnalysisRun: error rate < 5% over 3×60s ? → promote to 100%
  → any check fails → Argo auto-rollback, pipeline exits non-zero
```

Manifests: `devsecops/k8s/apps/{backend,frontend}/`
- `rollout.yaml` — Rollout CRD (replaces Deployment)
- `services.yaml` — stable + canary ClusterIP services
- `traefik-service.yaml` — TraefikService weighted split
- `ingress-route.yaml` — IngressRoute → TraefikService
- `analysis-template.yaml` — Prometheus error-rate query

### Infra pipeline — 2 stages

| Stage | Name | Tools |
|-------|------|-------|
| 1 | Secret Detection | detect-secrets, Gitleaks, TruffleHog |
| 2 | IaC Scanning | Checkov, tfsec, Conftest OPA, Kyverno |

### Container registry

Images pushed to GitHub Container Registry (GHCR):
```
ghcr.io/tbernacchi/k8s-devsecops-pipeline-frontend:<git-sha>
ghcr.io/tbernacchi/k8s-devsecops-pipeline-backend:<git-sha>
```

### Slack notifications

Every security tool failure posts to the `k8s-devsecops-pipe` Slack channel with:
- Which stage and which tool failed
- Last 25 lines of the tool's output (ANSI stripped)
- Direct link to the GitHub Actions run

Each stage posts to the same channel using Block Kit format with explicit mrkdwn rendering.

Stages 1–5 (app pipeline) and Stages 1–2 (infra pipeline) all have per-tool notifications.

### Stack

- **Apps**: Python/Flask (frontend), Go/Gin (backend)
- **Registry**: GitHub Container Registry (GHCR)
- **Cluster**: K3s on Raspberry Pi 4 (ARM64), 3 nodes
- **Ingress**: Traefik with IngressRoute CRDs
- **Runners**: Actions Runner Controller (ARC) — `k8s-system-design` scale set
- **Security**: Cosign keyless signing, SLSA provenance, OWASP ZAP DAST, SonarCloud

---

## Setup guide

Everything below is required to run the pipeline end-to-end. Follow in order.

---

### 1. GitHub — Workflow permissions

The pipeline pushes images to GHCR (GitHub Container Registry). Without write permissions the push fails with `403 Forbidden`.

**Settings → Actions → General → Workflow permissions → Read and write → Save**

---

### 2. GitHub — Repository secrets

Secrets shared across all pipeline runs. Not tied to any specific environment.

**Settings → Secrets and variables → Actions → New repository secret**

| Secret | Value | Why |
|--------|-------|-----|
| `SONAR_TOKEN` | Token from SonarCloud | Authenticates SonarQube scan in stage 2 |
| `SONAR_HOST_URL` | `https://sonarcloud.io` | Scanner endpoint |
| `SNYK_TOKEN` | Token from Snyk | Authenticates Snyk CLI in stage 4 |
| `NVD_API_KEY` | Key from nvd.nist.gov | Speeds up OWASP DC NVD database updates (optional but strongly recommended) |
| `SLACK_WEBHOOK_K8S_DEVSECOPS` | Incoming Webhook URL from Slack | Posts failure notifications to `k8s-devsecops-pipe` channel |
| `DEV_KUBECONFIG_B64` | `cat ~/.kube/config \| base64 -w0` | kubectl access to dev cluster in stage 6 |
| `STAGING_KUBECONFIG_B64` | `cat ~/.kube/config \| base64 -w0` | kubectl access to staging cluster in stage 7 |
| `STAGING_BASE_URL` | `https://traefik.mykubernetes.com` | Base URL for smoke tests (stage 8) and DAST (stage 9) |
| `PROD_KUBECONFIG_B64` | `cat ~/.kube/config \| base64 -w0` | kubectl access to prod cluster in stage 7 |
| `PROD_BASE_URL` | base URL of the prod cluster ingress | DAST target URL in stage 8 |
| `DB_WRITE_DSN` | `postgres://user:pass@host:5432/db?sslmode=disable` | Backend PostgreSQL write DSN — pipeline creates k8s Secret `backend-db` in `app-backend` before deploy |

**Getting SONAR_TOKEN:**
1. Log in at [sonarcloud.io](https://sonarcloud.io) with your GitHub account
2. My Account → Security → Generate Token → type `ci` → Generate
3. Copy the token

**Getting SNYK_TOKEN:**
1. Log in at [app.snyk.io](https://app.snyk.io) with your GitHub account
2. Account Settings → Auth Token → click to show → copy

**Getting NVD_API_KEY:**
1. Go to [nvd.nist.gov/developers/request-an-api-key](https://nvd.nist.gov/developers/request-an-api-key)
2. Enter your email — key is delivered immediately
3. Without this key, OWASP DC downloads 350k+ CVE records without rate limiting (very slow)

**Getting SLACK_WEBHOOK_K8S_DEVSECOPS:**
1. In Slack: Apps → search "Incoming WebHooks" → Add to Slack
2. Choose channel `k8s-devsecops-pipe` (create it first if needed)
3. Click **Add Incoming WebHooks integration**
4. Copy the Webhook URL (`https://hooks.slack.com/services/...`)
5. No OAuth tokens or Client ID/Secret needed — the URL itself is the credential

**Generating kubeconfig in base64:**
```bash
cat ~/.kube/config | base64 -w0
# paste the output as the secret value
```

> The kubeconfig must point to a cluster reachable by the ARC runner (stages 7–12 run inside the cluster itself, so `localhost` or internal cluster IPs work).

---

### 3. GitHub — Environment secrets (production)

Environment secrets are isolated — only jobs that declare `environment: production` can read them. Stage 12 (prod deploy) is the only job using this environment.

**Settings → Environments → New environment → name it `production` → Configure environment**

Add the following secrets under **Environment secrets**:

| Secret | Value | Why |
|--------|-------|-----|
| `PROD_KUBECONFIG_B64` | `cat ~/.kube/config \| base64 -w0` | kubectl access to prod cluster in stage 12 |
| `PROD_BASE_URL` | `https://traefik.mykubernetes.com` | Health check URL after prod deploy |

> **Why separate from repository secrets?** If an attacker compromises an earlier stage (1–11), they cannot read `PROD_KUBECONFIG_B64`. It only becomes available after a human explicitly approves the deployment.

---

### 4. GitHub — Production environment: required reviewers

Stage 12 pauses and waits for human approval before deploying to production. This is the manual gate that prevents automated deployments from reaching prod without oversight.

**Settings → Environments → production → Required reviewers → add your GitHub username → Save protection rules**

> This option only appears on **public repositories** or repositories on GitHub Pro/Team/Enterprise. If your repo is private on the free plan, make it public or upgrade.

When the pipeline reaches stage 12, GitHub sends an email notification. To approve:
**Actions → the running workflow → Review deployments → Approve and deploy**

---

### 5. GitHub — Branch protection (main)

Simulates a medium/large team environment where direct pushes to `main` are not allowed and all changes must go through a reviewed pull request with a passing pipeline.

**Settings → Branches → Add classic branch protection rule**

| Setting | Value | Why |
|---------|-------|-----|
| Branch name pattern | `main` | Protects only the main branch |
| Require a pull request before merging | ✅ | No direct pushes to main |
| Required approvals | 1 | At least one reviewer must approve |
| Dismiss stale reviews on new commits | ✅ | A new push invalidates previous approval |
| Require review from Code Owners | ✅ | Enforces `.github/CODEOWNERS` |
| Require approval of most recent push | ✅ | The person who pushed can't self-approve |
| Require status checks to pass | ✅ | Pipeline must pass before merge |
| Require branches to be up to date | ✅ | Branch must be current with main |
| Require linear history | ✅ | Only squash or rebase merges — clean git log |
| Require signed commits | ✅ | All commits must be GPG or SSH signed |
| Block force pushes | ✅ | No `git push --force` on main |
| Restrict deletions | ✅ | No one can delete main |
| Do not allow bypassing | ❌ | Leave unchecked on solo projects — otherwise you lock yourself out without a second reviewer |

**Adding status checks after first pipeline run:**

Status checks only appear after the pipeline runs at least once. After the first run:
1. Go to **Settings → Branches → main → Edit**
2. Under **Require status checks** → search for `frontend` and `backend`
3. Select both → Save

Or via CLI:
```bash
gh api repos/OWNER/REPO/branches/main/protection \
  --method PUT \
  --field 'required_status_checks={"strict":true,"checks":[{"context":"frontend"},{"context":"backend"}]}' \
  --field enforce_admins=false \
  --field 'required_pull_request_reviews={"required_approving_review_count":1,"dismiss_stale_reviews":true,"require_code_owner_reviews":true,"require_last_push_approval":true}' \
  --field restrictions=null
```

---

### 6. CODEOWNERS

`.github/CODEOWNERS` defines who must review PRs touching specific paths. Already committed in this repo.

```
* @tbernacchi                          # all files
.github/workflows/ @tbernacchi         # pipeline changes
devsecops/apps/frontend/ @tbernacchi   # frontend app
devsecops/apps/backend/ @tbernacchi    # backend app
devsecops/infra/ @tbernacchi           # infrastructure
```

> On a solo project, use **Settings → Branches → main → Allow specified actors to bypass required pull requests** and add your username. This lets you merge when you don't have a second reviewer available during development.

---

### 7. Workflow permissions in caller workflows

GitHub Actions reusable workflows do **not** inherit permissions from the called workflow — the **caller** must explicitly declare every permission the entire pipeline needs.

Both `frontend.yml` and `backend.yml` declare:

```yaml
permissions:
  contents: read          # checkout code
  security-events: write  # CodeQL uploads SARIF results (stage 3)
  packages: write         # push image to GHCR (stage 6)
  id-token: write         # Cosign keyless signing via OIDC (stage 6)
  attestations: write     # SLSA provenance attestation (stage 6)
```

Without these, GitHub blocks the pipeline with errors like:
```
The nested job 'stage3_sast' is requesting 'security-events: write',
but is only allowed 'security-events: none'.
```

---

### 8. Cluster — ARC self-hosted runner

Stages 6–10 run on `k8s-system-design`, an Actions Runner Controller (ARC) scale set installed in the K3s cluster. These stages need direct access to the cluster network (`192.168.1.x`) and the Traefik ingress — reachable only from within the cluster.

See [gh-runner/README.md](gh-runner/README.md) for full install instructions.

**Quick check:**
```bash
kubectl get autoscalingrunnerset -n arc-runners
# NAME                MINIMUM RUNNERS   MAXIMUM RUNNERS
# k8s-system-design   0                 3
```

**Deploy order — backend first:**

The frontend depends on the backend (`BACKEND_HOST`/`BACKEND_PORT`). Always trigger or merge backend changes before frontend so the backend service is reachable when the frontend starts.

**Parallelism — single runner = serialized jobs:**

The `k8s-system-design` runner processes one job at a time. When both frontend and backend pipelines trigger simultaneously (e.g. on a change to `reusable-app-pipeline.yml`), all jobs that require the self-hosted runner are queued and run in series — total time = frontend + backend combined.

To run both pipelines in parallel, register a second runner in the same scale set:
```bash
# scale up the runner set to 2 replicas
kubectl patch autoscalingrunnerset k8s-system-design \
  -n arc-runners \
  --type=merge \
  -p '{"spec":{"minRunners":0,"maxRunners":2}}'
```

With two runners, Stage 6+ of frontend and backend can execute concurrently.

---

### 9. Cluster — Traefik metrics + Prometheus + Argo Rollouts

Required for Stage 10 canary deploy. One-time setup.

**Step 1 — Enable Traefik Prometheus metrics:**
```bash
kubectl apply -f devsecops/k8s/traefik/helmchartconfig.yaml
# Traefik restarts and exposes /metrics on :9100
```

**Step 2 — Deploy Prometheus:**
```bash
kubectl apply -f devsecops/k8s/prometheus/
# Scrapes Traefik pods via Kubernetes SD
# Accessible at prometheus.monitoring.svc.cluster.local:9090
```

**Step 3 — Install Argo Rollouts:**
```bash
# Check if already installed
kubectl get namespace argo-rollouts 2>/dev/null && kubectl get deployment argo-rollouts -n argo-rollouts 2>/dev/null

# If not installed:
kubectl create namespace argo-rollouts
kubectl apply -n argo-rollouts -f https://github.com/argoproj/argo-rollouts/releases/latest/download/install.yaml

# Apply Traefik plugin config (ARM64 binary)
kubectl apply -f devsecops/k8s/argo-rollouts/traefik-plugin-config.yaml
```

**Step 4 — Apply app manifests (first deploy only):**
```bash
kubectl create namespace app-backend 2>/dev/null || true
kubectl create namespace app-frontend 2>/dev/null || true
kubectl apply -f devsecops/k8s/apps/backend/
kubectl apply -f devsecops/k8s/apps/frontend/
```

**Verify:**
```bash
kubectl get rollout -n app-backend
kubectl get rollout -n app-frontend
kubectl get analysistemp -n app-backend
kubectl get pods -n monitoring    # prometheus running
kubectl get pods -n argo-rollouts # controller running
```

---

### 10. Cluster — PostgreSQL (CloudNativePG)

The backend requires a PostgreSQL database managed by CloudNativePG in the `postgres` namespace.

**One-time setup — create user and database:**
```bash
# create user
kubectl exec -n postgres cnpg-cluster-1 -- psql -U postgres \
  -c "CREATE USER \"system-design\" WITH PASSWORD 'system-design';"

# create database
kubectl exec -n postgres cnpg-cluster-1 -- \
  createdb -U postgres -O "system-design" "system-design"

# verify
kubectl exec -n postgres cnpg-cluster-1 -- psql -U postgres -c "\du"
kubectl exec -n postgres cnpg-cluster-1 -- psql -U postgres -c "\l" | grep system-design
```

**Services available in `postgres` namespace:**

| Service | Purpose |
|---------|---------|
| `cnpg-cluster-rw` | Read-write (primary) — use for `DB_WRITE_DSN` |
| `cnpg-cluster-ro` | Read-only (replicas) — use for `DB_READ_DSN` |
| `clube-pooler` | PgBouncer connection pooler |

**DSN format (cross-namespace FQDN):**
```
postgres://system-design:system-design@cnpg-cluster-rw.postgres.svc.cluster.local:5432/system-design?sslmode=disable
```

**One-time manual secret creation** (before first pipeline run):
```bash
kubectl create secret generic backend-db \
  --from-literal=DB_WRITE_DSN='postgres://system-design:system-design@cnpg-cluster-rw.postgres.svc.cluster.local:5432/system-design?sslmode=disable' \
  -n app-backend
```

After that, **the pipeline recreates/updates it automatically** on every deploy via `--dry-run=client | kubectl apply` — idempotent, no manual step needed again.

**Test connectivity from within the cluster:**
```bash
kubectl run pg-test --image=postgres:15 --restart=Never -n app-backend \
  --env="PGPASSWORD=system-design" --rm -it -- \
  psql "postgres://system-design@cnpg-cluster-rw.postgres.svc.cluster.local:5432/system-design?sslmode=disable" \
  -c "\conninfo"
```

---

### 11. Cluster — GHCR image pull

After stage 6 pushes the image to `ghcr.io`, the cluster needs credentials to pull it during deploy.

**Option A — configure containerd on each node (no Kubernetes secret):**
```bash
# on each node: 192.168.1.106, 192.168.1.105, 192.168.1.103
sudo tee /etc/rancher/k3s/registries.yaml <<EOF
configs:
  "ghcr.io":
    auth:
      username: YOUR_GITHUB_USERNAME
      password: YOUR_GITHUB_PAT  # needs read:packages scope
EOF

sudo systemctl restart k3s        # master node
sudo systemctl restart k3s-agent  # worker nodes
```

**Option B — make GitHub packages public:**
GitHub → your package → Settings → Make public. No authentication needed.

---

### 12. SonarCloud — project setup

The pipeline uses `projectKey=tbernacchi_frontend` and `tbernacchi_backend`.

1. Log in at [sonarcloud.io](https://sonarcloud.io) with GitHub
2. Create organization `tbernacchi` (or use existing)
3. Either create the projects manually or enable **Auto-provision** in org settings so SonarCloud creates them on first scan

---

### Triggering the pipeline

**Manual trigger:**
```bash
gh workflow run frontend.yml   # frontend only
gh workflow run backend.yml    # backend only
```

**Run a single stage** — useful when a specific stage fails and you don't want to repeat the full pipeline:
```bash
gh workflow run backend.yml --ref main -f run_only_stage=4   # SCA only
gh workflow run frontend.yml --ref main -f run_only_stage=3  # SAST only
```

Or via the UI: **Actions → Backend/Frontend Secure Pipeline → Run workflow → fill `run_only_stage`**.

Stages that run cleanly in isolation:

| Stages | Works standalone? | Note |
|--------|-------------------|------|
| 1–4 | ✅ | code analysis, no external deps |
| 5 | ✅ | builds from scratch |
| 8 | ✅ | DAST hits staging URL, needs staging deployed |
| 6, 7, 9, 10 | ⚠️ | require `image_ref`/`digest` output from Stage 5 — run stage 5 first |

**Automatic trigger on push** — paths configured in each workflow:
- `devsecops/apps/frontend/**` → triggers `frontend.yml`
- `devsecops/apps/backend/**` → triggers `backend.yml`
- `.github/workflows/reusable-app-pipeline.yml` → triggers both

**Monitor:**
```bash
gh run list --workflow=frontend.yml   # list runs + IDs
gh run watch                          # live output
gh run view <run-id> --log            # full log
gh run view <run-id> --log-failed     # failed steps only
```

**Stage 11 — manual approval required.**
GitHub sends an email when the pipeline reaches prod deploy.
**Actions → the run → Review deployments → Approve and deploy**

---

### Troubleshooting

#### Stage 4 — OWASP DC NVD cache

OWASP Dependency Check downloads the full NVD CVE database (~352k records) on first run. Without caching this takes 15–30 minutes and may hit rate limits.

The pipeline caches `~/.owasp-dc` using `actions/cache@v4` with a daily key:
```
owasp-dc-Linux-2026-05-21   ← restored same day
owasp-dc-Linux-             ← fallback: most recent day
```

The cache directory is mounted into the OWASP DC container:
```bash
-v "$HOME/.owasp-dc:/usr/share/dependency-check/data"
```

`chmod 777 ~/.owasp-dc` is required — the container runs as `dependencycheck` (UID 1000), not the runner user.

With `NVD_API_KEY` set, delta updates take seconds. Without it, even cached runs may re-download large batches.

#### Stage 4 — Snyk Python environment

`snyk/actions/python@master` is a Docker action — it runs in an isolated container and does not inherit packages installed by prior `pip install` steps on the runner.

Solution: Snyk CLI is installed via `npm install -g snyk` and runs directly on the Ubuntu runner, where pip packages from the `Install deps` step are available. `--skip-unresolved` is passed to handle any transitive packages that can't be resolved without a full virtual environment.

#### Stage 1 — detect-secrets false positives

`detect-secrets` uses keyword heuristics — any line containing `secret`, `password`, `key` next to a value triggers a finding, regardless of context.

**Excluded from scanning** (configured in `reusable-app-pipeline.yml`):

```
README.md / **/README.md   — documentation only, no real credentials
*.example / *.tfvars.example — placeholder values for LocalStack/local dev
```

These files are excluded via the `exclude` regex in the detect-secrets hook config so the scanner focuses on source code and workflow files where real secrets could land.

**False positives in scanned files** — suppress inline with `# pragma: allowlist secret`:

| File | Trigger | Fix applied |
|------|---------|-------------|
| `frontend.yml`, `backend.yml` | `secrets: inherit` | `# pragma: allowlist secret` on that line |

```bash
# pragma: allowlist secret — use only on confirmed false positives, never on real credentials
secrets: inherit # pragma: allowlist secret
```

#### Stage 1 — caller workflow permissions

GitHub reusable workflows do not inherit permissions. The caller (`frontend.yml`, `backend.yml`) must explicitly declare every permission the entire pipeline needs:

```
Error: The nested job 'stage3_sast' is requesting 'security-events: write',
but is only allowed 'security-events: none'.
```

Fix: add `permissions` block to both caller workflows:

```yaml
permissions:
  contents: read
  security-events: write  # CodeQL SARIF upload (stage 3)
  packages: write          # GHCR push (stage 6)
  id-token: write          # Cosign OIDC keyless signing (stage 6)
  attestations: write      # SLSA provenance (stage 6)
```

---

### Reference docs

| Document | Description |
|----------|-------------|
| [`docs/vault-eso-tradeoffs.html`](devsecops/docs/vault-eso-tradeoffs.html) | When to use HashiCorp Vault + External Secrets Operator vs GitHub Secrets |
| [`docs/pipeline-runner-strategy.html`](devsecops/docs/pipeline-runner-strategy.html) | Runner split rationale, trade-offs, ArgoCD + Argo Rollouts integration path |
| [`gh-runner/README.md`](gh-runner/README.md) | ARC self-hosted runner install instructions |

---

## System Design studies

- Scalability, availability, and consistency fundamentals
- Distributed systems modeling
- Architectural trade-off discussions
- Design challenges and exercises
