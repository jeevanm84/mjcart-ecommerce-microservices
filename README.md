# mjcart-ecommerce-microservices

Microservices e-commerce demo (mjcart) focused on AWS & DevOps practices: Docker, Terraform, CI/CD with GitHub Actions. This repository contains examples and orchestration for running a small e‑commerce system with multiple services, infrastructure-as-code, and CI workflows.

## Tech stack
- Containerization: Docker, Docker Compose
- Infrastructure: Terraform (AWS examples)
- CI/CD: GitHub Actions (build, test, terraform checks, optional ECR push)
- Languages/frameworks: (fill in per-service; e.g., Node.js / Spring Boot / Python)

## What you'll find here
- /services - microservices (APIs, workers, etc.)
- /infrastructure - Terraform code for AWS resources
- /deploy - Docker Compose and Kubernetes manifests (if included)
- CI workflows under .github/workflows to build images and run Terraform checks

## Quick start (Docker Compose)
1. Clone the repo:

   git clone https://github.com/jeevanm84/mjcart-ecommerce-microservices.git
   cd mjcart-ecommerce-microservices

2. Start with Docker Compose (if docker-compose.yml is present):

   docker-compose up --build

3. Visit the running services at the ports defined in the compose file (e.g., http://localhost:8080)

## Terraform quick-run (local)
1. Install Terraform 1.0+ and configure your AWS credentials (via environment or ~/.aws/credentials).
2. Initialize and plan:

   cd infrastructure
   terraform init
   terraform plan

Note: production deployments require reviewing resources, IAM policies, and costs.

## CI/CD
- `.github/workflows/terraform.yml` runs Terraform fmt/validate/plan on pushes to main.
- `.github/workflows/docker-build.yml` builds Docker images and can push to ECR if secrets are configured.

## AWS & DevOps notes
- To enable pushing images to ECR, add the following repository secrets: `AWS_ACCOUNT_ID`, `AWS_REGION`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `ECR_REPOSITORY`.
- Use GitHub Environments and branch protection rules for safer main deployments.

## Contributing
Contributions are welcome. Please open issues for bugs or feature requests, and consider adding small incremental PRs.

## License
This repository is licensed under the MIT License - see LICENSE for details.

---

If you'd like, I can: (a) inspect your local zip and prepare a service-by-service README, (b) add sample Terraform modules for a minimal AWS setup, or (c) prepare demo Docker Compose files. Tell me which and I’ll proceed.