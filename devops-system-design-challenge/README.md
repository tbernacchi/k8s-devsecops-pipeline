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

