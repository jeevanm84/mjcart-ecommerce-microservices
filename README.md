<div align="center">

# MJ's Cart

### A learning-first e-commerce microservices platform

Build, run, observe, and deploy a complete React + Node.js system with an API gateway, nine domain services, MySQL, Redis, Docker Compose, Kubernetes, and Prometheus.

[![CI](https://github.com/jeevanm84/mjcart-ecommerce-microservices/actions/workflows/ci.yml/badge.svg)](https://github.com/jeevanm84/mjcart-ecommerce-microservices/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-2563eb.svg)](LICENSE)
[![GitHub stars](https://img.shields.io/github/stars/jeevanm84/mjcart-ecommerce-microservices?style=social)](https://github.com/jeevanm84/mjcart-ecommerce-microservices/stargazers)

[Quick start](#quick-start) · [Learning paths](#choose-your-learning-path) · [Architecture](docs/ARCHITECTURE.md) · [API reference](docs/API.md) · [Contributing](CONTRIBUTING.md)

</div>

> [!NOTE]
> This is an educational, production-style reference project—not a production-ready commerce system. Checkout uses Cash on Delivery (COD); the project never accepts or stores card data.

## Why this project exists

Most microservices examples show isolated snippets. MJ's Cart shows how the pieces fit together: a browser request crosses NGINX and an API gateway, reaches independently deployable services, changes state in MySQL or Redis, and exposes health and Prometheus endpoints for operations.

You can use it to:

- learn microservices locally with one Docker Compose command;
- practice API gateway, database-per-service, caching, and orchestration patterns;
- study Docker and Kubernetes manifests from a working example;
- prepare a system-design or DevOps walkthrough;
- contribute approachable improvements to an open-source project.

## Quick start

### Prerequisites

- Git
- Docker Desktop or Docker Engine with Compose v2
- 6 GB or more of memory available to Docker
- `curl` for the optional smoke test

### Run the complete application

```bash
git clone https://github.com/jeevanm84/mjcart-ecommerce-microservices.git
cd mjcart-ecommerce-microservices
cp .env.example .env
docker compose up --build -d
```

Wait until MySQL finishes its first-time initialization, then open:

- Storefront: <http://localhost:3000>
- API gateway: <http://localhost:8080>
- Product API: <http://localhost:3000/api/products>

Verify the important paths:

```bash
./scripts/verify-local.sh
```

Stop the application without losing local database data:

```bash
docker compose down
```

For logs, resets, troubleshooting, and the manual-development workflow, see the [complete getting-started guide](docs/GETTING_STARTED.md).

## Choose your learning path

| Experience | Start here | What you will learn |
|---|---|---|
| Beginner | [Run your first order](docs/GETTING_STARTED.md#your-first-guided-demo) | Containers, API calls, logs, and service boundaries |
| Intermediate | [Trace a checkout](docs/LEARNING_PATHS.md#intermediate-trace-a-checkout) | Gateway routing, Redis, MySQL, and service-to-service calls |
| Experienced | [Production-readiness review](docs/LEARNING_PATHS.md#experienced-production-readiness-review) | Reliability gaps, security boundaries, observability, and scaling trade-offs |

## Architecture at a glance

```mermaid
flowchart LR
    U[Browser] --> F[React + NGINX]
    F -->|/api/*| G[API Gateway]
    G --> A[Auth]
    G --> P[Product]
    G --> C[Cart]
    G --> O[Order]
    G --> X[Other domain services]
    A --> M[(MySQL)]
    P --> M
    P --> R[(Redis)]
    C --> R
    O --> M
    O --> I[Inventory]
    O --> S[Shipping]
    O --> N[Notification]
```

The gateway exposes nine domain APIs. Every backend includes `/health`, `/ready`, and `/metrics` endpoints. The [architecture guide](docs/ARCHITECTURE.md) explains ownership, request flows, data boundaries, and deliberate trade-offs.

## Services

| Component | Responsibility | Data store |
|---|---|---|
| `frontend` | Storefront and project UI | — |
| `api-gateway` | Routes `/api/*` requests | — |
| `auth-service` | Registration, login, JWT validation | MySQL |
| `user-service` | Customer profiles | MySQL |
| `product-service` | Product catalog and list caching | MySQL + Redis |
| `inventory-service` | Stock lookup and reservation | MySQL |
| `cart-service` | Expiring customer carts | Redis |
| `order-service` | COD checkout orchestration | MySQL |
| `shipping-service` | Shipment creation and tracking | MySQL |
| `notification-service` | Stored order notifications | MySQL |
| `review-service` | Product reviews | MySQL |

## Repository map

```text
.
├── frontend/          React storefront served by NGINX
├── services/          API gateway and domain services
├── database/          Local MySQL bootstrap data
├── k8s/               Kubernetes workloads and infrastructure
├── scripts/           Build, deploy, verify, and cluster helpers
├── docs/              Guided learning and technical reference
├── docker-compose.yml Complete local environment
└── Makefile            Friendly shortcuts for common tasks
```

## Common commands

```bash
make help      # discover commands
make up        # build and start everything
make status    # inspect containers
make logs      # follow all logs
make verify    # run local smoke checks
make down      # stop and preserve data
make clean     # stop and delete local data
```

## Kubernetes deployment

The repository includes a self-managed Kubernetes path using kOps on AWS. It creates real cloud resources and can incur charges. Read the [deployment runbook](docs/RUNBOOK.md) before running any cluster script.

## Project status and boundaries

MJ's Cart demonstrates infrastructure and integration patterns in compact code. Important production concerns—authorization enforcement, input schemas, migrations, distributed transactions, retries, tracing, TLS, secret management, automated tests, and high availability—remain intentional extension points. See the [experienced learning path](docs/LEARNING_PATHS.md#experienced-production-readiness-review).

## Contributing

Contributions from first-time and experienced contributors are welcome. Start with [CONTRIBUTING.md](CONTRIBUTING.md), use the issue templates, and keep each pull request focused. Please follow the [Code of Conduct](CODE_OF_CONDUCT.md) and report vulnerabilities through [SECURITY.md](SECURITY.md).

## Author

Created and maintained by [Jeevan Kumar Mamuduri (@jeevanm84)](https://github.com/jeevanm84). If this project helps you, consider starring it, sharing what you learned, or contributing an improvement.

## License

Released under the [MIT License](LICENSE).
