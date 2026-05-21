# ArgoCD / Helm

Este diretório centraliza os manifests e charts de plataforma e aplicações Kubernetes.

## Escopo recomendado

- `argocd/`: instalação e configuração do ArgoCD
- `platform/traefik/`: chart/values do Traefik
- `apps/frontend/`: chart/values da aplicação frontend
- `apps/backend/`: chart/values da aplicação backend

## Diretriz

- Não gerenciar Deployments/Services/IngressRoute/ConfigMaps via Terraform.
- Terraform entrega cluster + base cloud.
- ArgoCD aplica e reconcilia tudo dentro do cluster.
