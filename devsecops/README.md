# DevOps System Design Challenge

The challenge is to build an infrastructure stack that provisions an environment to run a hypothetical REST backend application, with two replicas behind a Load Balancer, and a static frontend application. Both applications must be served under the same domain, but with different URL paths.

## Example

- `mydomain.com/backend`
- `mydomain.com/frontend`

---

# Requirements

- Cloud environment (AWS)
- Basic network infrastructure
- Load Balancer
- Web application: can be any type of application that demonstrates Docker usage and static content
- DNS resolution for the Load Balancer
- Automation of the web application's build process and deployment of all resources in the chosen cloud service
- Detailed documentation and instructions for running in real environments (production and development)

---

# Suggested Technologies

- Docker
- Terraform
- Kubernetes
- GitHub Actions
- Helm

> Note: other tools/solutions are also welcome, as long as they work in a simple and efficient way.

---

# Evaluation Criteria

- Organization
- Documentation quality
- Use of automation tools
- Elegance of the proposed solution
- Simplicity and efficiency
- Security techniques and best practices

---

# Implementation

See [root README](../README.md) for full pipeline documentation, setup guide, and troubleshooting.

## Pipeline overview

11-stage DevSecOps pipeline via GitHub Actions reusable workflow (`reusable-app-pipeline.yml`), shared between frontend (Python) and backend (Go).

| Stage | Name | Runner |
|-------|------|--------|
| 1 | Secret Detection (detect-secrets, Gitleaks, TruffleHog) | `ubuntu-latest` |
| 2 | Unit Tests + Code Quality (pytest / go test, SonarQube) | `ubuntu-latest` |
| 3 | SAST (Semgrep, CodeQL) | `ubuntu-latest` |
| 4 | SCA (Trivy, OWASP DC, Snyk CLI) | `ubuntu-latest` |
| 5 | Build + Sign + Attest (Docker → GHCR, Cosign, SLSA) | `ubuntu-latest` |
| 6 | Deploy Dev *(optional)* | `k8s-system-design` |
| 7 | Deploy Staging *(optional)* | `k8s-system-design` |
| 8 | Smoke Tests | `k8s-system-design` |
| 9 | DAST (OWASP ZAP) | `k8s-system-design` |
| 10 | Policy Gate (Cosign verify) | `k8s-system-design` |
| 11 | Prod Deploy (progressive rollout + auto rollback, manual approval) | `k8s-system-design` |

## Triggering

```bash
# Full pipeline
gh workflow run backend.yml --ref main
gh workflow run frontend.yml --ref main

# Single stage (re-run without repeating full pipeline)
gh workflow run backend.yml --ref main -f run_only_stage=4
gh workflow run frontend.yml --ref main -f run_only_stage=3
```

Or via UI: **Actions → workflow → Run workflow → fill `run_only_stage` (1–11)**.

