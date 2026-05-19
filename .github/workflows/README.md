# GitHub Actions Reusable Workflows

This repository uses a reusable pipeline pattern to avoid duplication between app workflows.

## Files

- `reusable-app-pipeline.yml`: shared CI/CD pipeline with security checks, SonarQube scan + quality gate, Kyverno policy-as-code validation, image build/signing, deploy stages, DAST, policy gate, and prod rollout.
- `frontend.yml`: caller workflow for the frontend app.
- `backend.yml`: caller workflow for the backend app.

## How the reusable workflow works

The shared workflow is triggered by `workflow_call` and receives app-specific inputs.
Each caller workflow only defines:

- trigger paths
- values for inputs
- `secrets: inherit`

## Reusable workflow inputs

- `app_name`: app identifier used in image naming.
- `app_path`: app source directory.
- `dockerfile_path`: Dockerfile path for the app.
- `codeql_language`: language used by CodeQL (for example `python` or `go`).
- `dependency_file`: dependency manifest used by Snyk.
- `deploy_name`: Kubernetes deployment name.
- `container_name`: container name inside the deployment.
- `route_prefix`: URL prefix used by DAST and smoke checks (for example `/frontend`).

## Required secrets

The reusable workflow expects these secrets in the repository/environment:

- `GITHUB_TOKEN` (automatic in Actions)
- `SONAR_TOKEN`
- `SONAR_HOST_URL`
- `SNYK_TOKEN`
- `DEV_KUBECONFIG_B64`
- `STAGING_KUBECONFIG_B64`
- `PROD_KUBECONFIG_B64`
- `STAGING_BASE_URL`
- `PROD_BASE_URL`

## Policy as Code (Kyverno)

The reusable workflow includes a Kyverno policy-as-code step during container/IaC scanning.

- It scans Kubernetes YAML files under `devops-system-design-challenge/infra/helm/**` and `devops-system-design-challenge/k8s/**`.
- It currently enforces baseline checks like:
  - `runAsNonRoot: true`
  - `readOnlyRootFilesystem: true` for containers
- If no Kubernetes manifests are found, the Kyverno step is skipped automatically.
