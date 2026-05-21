# system-design-2026

Practice repository for **System Design**, **Software Architecture**, and **DevSecOps**.

## devops-system-design-challenge

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

### Reference docs

| Document | Description |
|----------|-------------|
| [`docs/vault-eso-tradeoffs.html`](devops-system-design-challenge/docs/vault-eso-tradeoffs.html) | When to use HashiCorp Vault + External Secrets Operator vs GitHub Secrets |
| [`docs/pipeline-runner-strategy.html`](devops-system-design-challenge/docs/pipeline-runner-strategy.html) | Runner split rationale, trade-offs, ArgoCD + Argo Rollouts integration path |
| [`gh-runner/README.md`](gh-runner/README.md) | ARC self-hosted runner install instructions |

## System Design studies

- Scalability, availability, and consistency fundamentals
- Distributed systems modeling
- Architectural trade-off discussions
- Design challenges and exercises
