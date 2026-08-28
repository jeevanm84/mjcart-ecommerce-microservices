# MJ's Cart architecture

MJ's Cart is a learning-first, production-style microservices system. It runs the same logical components through Docker Compose locally and Kubernetes for the cluster learning path. Checkout is Cash on Delivery (COD): there is no payment service, payment route, or card-data flow.

Use this document for runtime relationships and design boundaries. Use [Code structure](CODE_STRUCTURE.md) to locate implementation files and [API reference](API.md) for endpoint contracts.

## System context

```mermaid
flowchart TB
    Shopper[Shopper browser]
    Operator[Developer or operator]
    Platform[MJ's Cart platform]
    Registry[Container registry]
    Metrics[Prometheus and Grafana]

    Shopper -->|browse, sign in, cart, COD checkout| Platform
    Operator -->|Compose, scripts, kubectl, kOps| Platform
    Operator -->|build and push images| Registry
    Registry -->|pull versioned images| Platform
    Platform -->|health and Prometheus metrics| Metrics
```

## Runtime architecture

```mermaid
flowchart TB
    Browser[Browser]

    subgraph Edge[Edge and presentation]
        Ingress[NGINX Ingress or localhost ports]
        Frontend[React build served by NGINX]
        Gateway[Node.js API gateway]
    end

    subgraph Domains[Domain services]
        Auth[Auth]
        User[User]
        Product[Product]
        Inventory[Inventory]
        Cart[Cart]
        Order[Order]
        Shipping[Shipping]
        Notification[Notification]
        Review[Review]
    end

    subgraph Data[Data layer]
        MySQL[(MySQL: separate logical databases)]
        Redis[(Redis: carts and product cache)]
    end

    subgraph Ops[Optional observability]
        Prometheus[Prometheus]
        Grafana[Grafana]
    end

    Browser --> Ingress
    Ingress -->|/| Frontend
    Frontend -->|/api/*| Gateway
    Ingress -->|/api/* in Kubernetes| Gateway

    Gateway --> Auth
    Gateway --> User
    Gateway --> Product
    Gateway --> Inventory
    Gateway --> Cart
    Gateway --> Order
    Gateway --> Shipping
    Gateway --> Notification
    Gateway --> Review

    Auth --> MySQL
    User --> MySQL
    Product --> MySQL
    Product --> Redis
    Inventory --> MySQL
    Cart --> Redis
    Order --> MySQL
    Order --> Inventory
    Order --> Shipping
    Order --> Notification
    Shipping --> MySQL
    Notification --> MySQL
    Review --> MySQL

    Prometheus -->|scrape /metrics| Gateway
    Prometheus -->|scrape /metrics| Domains
    Grafana --> Prometheus
```

The frontend NGINX configuration proxies same-origin `/api` calls in the local container. Kubernetes Ingress can route `/` to the frontend and `/api` to the gateway. Domain workloads stay behind ClusterIP services.

## Service ownership

| Component | Owns | Storage | Calls |
|---|---|---|---|
| API gateway | Public routing and gateway metrics | None | All domain services |
| Auth service | Registration, login, JWT creation/validation | `auth_db` | None |
| User service | Customer profiles | `user_db` | None |
| Product service | Catalog and product-list caching | `product_db`, Redis | None |
| Inventory service | Stock and atomic reservation | `inventory_db` | None |
| Cart service | Per-user carts with expiry | Redis | None |
| Order service | COD orders, line items, checkout orchestration | `order_db` | Inventory, Shipping, Notification |
| Shipping service | Shipments and tracking numbers | `shipping_db` | None |
| Notification service | Stored order notifications | `notification_db` | None |
| Review service | Product reviews | `review_db` | None |

Every backend exposes `/health`, `/ready`, and `/metrics`. The gateway has no `/api/payments` mapping, and the order service always persists `payment_method = "COD"`.

## Read request flow

```mermaid
sequenceDiagram
    actor Shopper
    participant UI as React + NGINX
    participant Gateway as API gateway
    participant Product as Product service
    participant Redis
    participant MySQL

    Shopper->>UI: Open product page
    UI->>Gateway: GET /api/products
    Gateway->>Product: GET /products
    Product->>Redis: Read cached product list
    alt Cache hit
        Redis-->>Product: Products
    else Cache miss
        Product->>MySQL: SELECT products
        MySQL-->>Product: Rows
        Product->>Redis: Cache serialized list
    end
    Product-->>Gateway: JSON products
    Gateway-->>UI: JSON products
    UI-->>Shopper: Render product cards
```

## Checkout sequence and failure boundary

```mermaid
sequenceDiagram
    actor Shopper
    participant UI as React storefront
    participant Gateway as API gateway
    participant Order as Order service
    participant Inventory as Inventory service
    participant OrderDB as order_db
    participant Shipping as Shipping service
    participant Notify as Notification service
    participant Cart as Cart service

    Shopper->>UI: Place order (COD)
    UI->>Gateway: POST /api/orders
    Gateway->>Order: POST /orders
    loop Every cart item
        Order->>Inventory: Reserve quantity
        Inventory-->>Order: Reserved
    end
    Order->>OrderDB: Insert order and line items
    Order->>Shipping: Create shipment
    Shipping-->>Order: Tracking data
    Order->>Notify: Store ORDER_PLACED notification
    Notify-->>Order: Stored
    Order-->>UI: 201 order result
    UI->>Cart: Clear cart through gateway
    UI-->>Shopper: Success screen
```

This is a deliberately synchronous teaching implementation, not an atomic distributed transaction. If inventory succeeds and a later call fails, automatic compensation is not implemented. A production evolution would introduce idempotency keys, an outbox, asynchronous events, retries with backoff, a checkout saga, and compensating inventory release.

## Local and Kubernetes mapping

| Concern | Docker Compose | Kubernetes |
|---|---|---|
| Definition | `docker-compose.yml` | `k8s/*.yaml` |
| Discovery | Compose service names | Kubernetes Services and cluster DNS |
| External entry | Frontend `:3000`, gateway `:8080` | Ingress routes `/` and `/api` |
| MySQL persistence | Named `mysql-data` volume | StatefulSet/PVC |
| Configuration | `.env` and service environment | ConfigMaps, Secrets, workload environment |
| Health | Compose dependency health checks | Liveness/readiness probes |
| Verification | `scripts/verify-local.sh` | `scripts/verify.sh` |
| Lifecycle | `make up/down/clean` | Deploy and Kubernetes/kOps lifecycle scripts |

## Delivery flow

```mermaid
flowchart LR
    Code[Feature branch] --> PR[Pull request]
    PR --> CI[Validate project]
    CI --> Review[Review and resolved conversations]
    Review --> Main[Squash or rebase to main]
    Main --> Target{Learning target}
    Target -->|Local| Compose[Docker Compose build]
    Target -->|Kubernetes| Build[Build and push service images]
    Compose --> LocalVerify[Local smoke verification]
    Build --> Deploy[Apply manifests]
    Deploy --> ClusterVerify[Cluster verification]
    ClusterVerify --> Observe[Prometheus and Grafana]
```

The protected `main` ruleset requires the `Validate project` check, linear history, resolved conversations, and pull requests. Operational deployment remains deliberate rather than automatic because the Kubernetes path can create billable AWS resources.

## Security and trust boundaries

- The browser should reach backend domains only through the API gateway.
- JWT issuance exists, but most domain routes do not yet enforce authorization; this is an explicit teaching boundary.
- Local `.env` values and Kubernetes sample Secrets are development examples, not production secret management.
- MySQL databases are logically separated, but share one server in the learning topology.
- Inter-service traffic is plain HTTP inside the learning network.
- The system stores no card data because checkout is COD only.
- Kubernetes and kOps scripts can create real resources; follow [RUNBOOK.md](RUNBOOK.md) and verify the active AWS account first.

## Production evolution

An enterprise implementation would add schema validation, authorization middleware, migrations, per-service database infrastructure, TLS, managed secrets, rate limiting, traces, centralized logs, circuit breakers, idempotency, saga/outbox messaging, autoscaling, disruption budgets, network policies, backups, disaster recovery, and automated unit/integration/contract tests.
