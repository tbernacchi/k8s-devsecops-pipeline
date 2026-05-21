# k8s-devsecops-pipeline

Practice repository for **System Design**, **Software Architecture**, and **DevSecOps**.

## devsecops/

The main focus of this repo is a **production-grade DevSecOps pipeline** built with GitHub Actions, targeting a Python frontend and Go backend deployed on a self-hosted K3s cluster (Raspberry Pi 4, ARM64).

### Pipeline overview (12 stages)

| Stage | Name | Runner |
|-------|------|--------|
| 1 | Secret Detection (Gitleaks, TruffleHog, detect-secrets) | `ubuntu-latest` |
| 2 | Unit Tests + SonarCloud Quality Gate | `ubuntu-latest` |
| 3 | SAST — Semgrep + CodeQL | `ubuntu-latest` |
| 4 | SCA — Trivy, OWASP Dependency Check, Snyk | `ubuntu-latest` |
| 5 | Container + IaC Scanning — Trivy image, Checkov, tfsec, Kyverno | `ubuntu-latest` |
| 6 | Build + Sign + Attest — GHCR, Cosign (keyless), SLSA provenance | `ubuntu-latest` |
| 7 | Deploy Dev | `k8s-system-design` |
| 8 | Deploy Staging | `k8s-system-design` |
| 9 | Smoke Tests | `k8s-system-design` |
| 10 | DAST — OWASP ZAP | `k8s-system-design` |
| 11 | Policy Gate — Cosign signature verification | `k8s-system-design` |
| 12 | Prod Deploy — progressive rollout + auto rollback (manual approval) | `k8s-system-design` |

Stages 1–6 run on GitHub-hosted AMD64 runners. Stages 7–12 run on a self-hosted ARC runner inside the K3s cluster (ARM64) to reach the local network.

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
| `SONAR_TOKEN` | Token from SonarCloud | Authenticates the SonarCloud scan in stage 2 |
| `SONAR_HOST_URL` | `https://sonarcloud.io` | Tells the scanner where to send results |
| `SNYK_TOKEN` | Token from Snyk | Authenticates Snyk dependency scan in stage 4 |
| `DEV_KUBECONFIG_B64` | `cat ~/.kube/config \| base64 -w0` | kubectl access to dev cluster in stage 7 |
| `STAGING_KUBECONFIG_B64` | `cat ~/.kube/config \| base64 -w0` | kubectl access to staging cluster in stage 8 |
| `STAGING_BASE_URL` | `https://traefik.mykubernetes.com` | Base URL used by smoke tests (stage 9) and DAST (stage 10) |

**Getting SONAR_TOKEN:**
1. Log in at [sonarcloud.io](https://sonarcloud.io) with your GitHub account
2. My Account → Security → Generate Token → type `ci` → Generate
3. Copy the token

**Getting SNYK_TOKEN:**
1. Log in at [app.snyk.io](https://app.snyk.io) with your GitHub account
2. Account Settings → Auth Token → click to show → copy

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

Stages 7–12 run on `k8s-system-design`, an Actions Runner Controller (ARC) scale set installed in the K3s cluster. These stages need direct access to the cluster network (`192.168.1.x`) and the Traefik ingress (`traefik.mykubernetes.com`) — reachable only from within the cluster.

See [gh-runner/README.md](gh-runner/README.md) for full install instructions.

**Quick check:**
```bash
kubectl get autoscalingrunnerset -n arc-runners
# NAME                MINIMUM RUNNERS   MAXIMUM RUNNERS
# k8s-system-design   0                 3
```

---

### 9. Cluster — GHCR image pull

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

### 10. SonarCloud — project setup

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

**Stage 12 — manual approval required.**
GitHub sends an email when the pipeline reaches prod deploy.
**Actions → the run → Review deployments → Approve and deploy**

---

### Troubleshooting

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
