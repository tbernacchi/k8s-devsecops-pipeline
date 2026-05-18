# Hotmart DevOps Challenge

O desafio consiste em construir uma stack de infraestrutura que provisione um ambiente para rodar uma aplicação backend REST hipotética, com duas réplicas respondendo em um Load Balancer, e uma aplicação frontend estática, ambas respondendo pelo mesmo domínio, porém com paths (URL) distintos.

## Exemplo

- `meudominio.com/backend`
- `meudominio.com/frontend`

---

# Requisitos

- Ambiente Cloud (AWS)
- Infraestrutura básica de rede
- Load Balancer
- Aplicação Web: pode ser qualquer tipo de aplicação que demonstre a utilização de Docker e conteúdo estático
- Resolução de DNS para o Load Balancer
- Automatização do processo de build da Aplicação Web e implantação de todos os recursos no serviço cloud utilizado
- Documentação detalhada e instruções para execução em ambiente real (produção e desenvolvimento)

---

# Tecnologias sugeridas

- Docker
- Terraform
- Kubernetes
- GitHub Actions
- Helm

> OBS: outras ferramentas/soluções também são bem-vindas, desde que funcionem de forma simples e eficiente.

---

# Será avaliado

- Organização
- Qualidade da documentação
- Uso de ferramentas de automatização
- Elegância na solução proposta
- Simplicidade e eficiência
- Técnicas e boas práticas de segurança

