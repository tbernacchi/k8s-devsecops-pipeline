# GitHub Actions Runner (ARC) — system-design-2026

Self-hosted runner for the `system-design-2026` pipeline, running inside the K3s cluster via [Actions Runner Controller (ARC)](https://github.com/actions/actions-runner-controller).

## Why a self-hosted runner?

The pipeline is split across two runner types:

| Stages | Runner | Reason |
|--------|--------|--------|
| 1–6 (secret scan, tests, SAST, SCA, container scan, build) | `ubuntu-latest` | Downloads AMD64 binaries (`conftest`, `kyverno`). No cluster access needed. |
| 7–12 (deploy dev/staging/prod, smoke tests, DAST, policy gate) | `k8s-system-design` | Must reach `192.168.1.106:6443` and `traefik.mykubernetes.com`. Only uses `kubectl`, `cosign`, `curl` — all ARM64 compatible. |

## Prerequisites

ARC controller already installed in the cluster:

```bash
helm list -n arc-controller
# NAME  CHART                                  VERSION
# arc   gha-runner-scale-set-controller-0.13.1
```

**Important:** the runner scale set chart version must match the controller version (`0.13.1`).

## GitHub PAT

The runner authenticates via a Kubernetes secret named `github-pat`.

Required PAT scopes:
- `repo` — full repository access
- `workflow` — update GitHub Actions workflows

Create the secret (if it doesn't exist):

```bash
kubectl create secret generic github-pat \
  --from-literal=github_token=<YOUR_PAT> \
  -n arc-runners
```

## Install

```bash
helm upgrade --install k8s-system-design \
  oci://ghcr.io/actions/actions-runner-controller-charts/gha-runner-scale-set \
  --version 0.13.1 \
  -n arc-runners \
  --set githubConfigUrl="https://github.com/tbernacchi/system-design-2026" \
  --set githubConfigSecret=github-pat \
  --set minRunners=0 \
  --set maxRunners=3
```

## Verify

```bash
# runner scale set registered
kubectl get autoscalingrunnerset -n arc-runners

# listener pod running
kubectl get pods -n arc-controller | grep k8s-system-design
```

Expected output:
```
NAME                MINIMUM RUNNERS   MAXIMUM RUNNERS   CURRENT RUNNERS
k8s-system-design   0                 3                 0
```

Runner pods spin up on demand when a workflow job is queued and terminate after the job completes (`minRunners: 0`).

## Usage in workflows

```yaml
jobs:
  deploy:
    runs-on: k8s-system-design
```

## Uninstall

```bash
helm uninstall k8s-system-design -n arc-runners
```
