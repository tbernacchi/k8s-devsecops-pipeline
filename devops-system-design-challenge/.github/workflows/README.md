# GitHub Actions Reusable Workflows

This directory uses a reusable pipeline pattern to avoid duplication between app workflows.

## Files

- `reusable-app-pipeline.yml`: shared CI/CD pipeline with security checks, image build/signing, deploy stages, DAST, policy gate, and prod rollout.
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
- `snyk_action`: Snyk action to run (language-specific action).
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

## Add a new app in 5 steps

1. Create a new caller workflow in `.github/workflows/<app>.yml`.
2. Configure `on.push.paths` and `on.pull_request.paths` for the new app folder.
3. Add one job using `uses: ./.github/workflows/reusable-app-pipeline.yml`.
4. Pass all required `with` inputs for that app.
5. Use `secrets: inherit`.

## Example caller skeleton

```yaml
name: Worker Secure Pipeline

on:
  push:
    paths:
      - "apps/worker/**"
      - "infra/**"
      - ".github/workflows/worker.yml"
      - ".github/workflows/reusable-app-pipeline.yml"
  pull_request:
    paths:
      - "apps/worker/**"
      - "infra/**"
      - ".github/workflows/worker.yml"
      - ".github/workflows/reusable-app-pipeline.yml"

jobs:
  worker:
    uses: ./.github/workflows/reusable-app-pipeline.yml
    with:
      app_name: worker
      app_path: apps/worker
      dockerfile_path: apps/worker/Dockerfile
      codeql_language: go
      snyk_action: snyk/actions/golang@master
      dependency_file: apps/worker/go.mod
      deploy_name: worker
      container_name: worker
      route_prefix: /worker
    secrets: inherit
```

## Notes

- Keep app-specific logic in callers only if strictly necessary.
- Keep all shared quality/security/deploy gates in the reusable workflow.
- When changing stage behavior, change the reusable workflow once instead of updating every app workflow.
