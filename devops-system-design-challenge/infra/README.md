# Infraestrutura AWS (Terraform + ArgoCD)

Esta estrutura separa recursos **globais** (fora da VPC) dos recursos **regionais** (dentro da VPC) e mantém workloads Kubernetes fora do Terraform, gerenciados por ArgoCD/Helm.

## Estrutura

- `infra/modules/vpc`: VPC, subnets public/private, IGW, NAT, route tables
- `infra/modules/eks`: EKS cluster, node group, OIDC provider, security groups
- `infra/modules/ecr`: repositórios ECR (frontend/backend)
- `infra/modules/dns`: Route 53, ACM, alias para ALB
- `infra/modules/iam`: IAM para bootstrap, GitHub Actions OIDC, node profile e policies
- `infra/live/dev/global`: recursos globais (IAM, S3/DynamoDB state, ECR, DNS)
- `infra/live/dev/eks`: recursos regionais (VPC + EKS)
- `infra/helm`: ArgoCD e aplicações Kubernetes via Helm

## Observações importantes

- Recursos fora da VPC: IAM, S3, DynamoDB, ECR e Route53.
- `k8s-apps` não é gerenciado por Terraform nesta base. O deploy deve ser feito via ArgoCD em `infra/helm`.
- O redirecionamento HTTP -> HTTPS normalmente é configurado no ALB/Ingress Controller (Traefik ou ALB Controller), não no Route53.

## Pronto para AWS real ou emulador

Os stacks em `infra/bootstrap`, `infra/live/dev/global` e `infra/live/dev/eks` já aceitam:

- credenciais e profile AWS (`aws_profile`, `aws_access_key_id`, `aws_secret_access_key`)
- flags para ambiente emulado (`aws_skip_credentials_validation`, `aws_skip_metadata_api_check`, `aws_skip_requesting_account_id`, `aws_s3_use_path_style`)
- endpoints customizados por serviço via `aws_endpoints` (ex.: LocalStack/FLOCI)

Assim você troca de backend cloud para emulador só por `tfvars`, sem refatorar módulos.
