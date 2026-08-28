# Learning paths

Use these paths as workshops, interview preparation, or contribution roadmaps. Each path starts from the Docker Compose environment in [Getting started](GETTING_STARTED.md).

## Beginner: understand the moving parts

Goal: connect visible UI actions to containers and stored data.

1. Run the platform and complete the guided order demo.
2. Run `docker compose ps` and match each container to the [service table](../README.md#services).
3. Follow gateway logs while loading the product page.
4. Stop `product-service`, reload the page, and observe the failure.
5. Restart it with `docker compose up -d product-service`.
6. Read one small service such as `services/inventory-service/server.js`.

You should be able to explain the difference between a frontend, gateway, service, database, container, and health endpoint.

## Intermediate: trace a checkout

Goal: understand synchronous orchestration and data ownership.

1. Follow `api-gateway`, `order-service`, `inventory-service`, `shipping-service`, and `notification-service` logs.
2. Place an order from the UI.
3. Read the `POST /orders` handler and draw the call sequence.
4. Query `order_db.orders`, `order_db.order_items`, `shipping_db.shipments`, and `notification_db.notifications`.
5. Inspect the remaining product quantity in `inventory_db.inventory`.
6. Consider what happens if shipping fails after stock is reserved.

Suggested contribution: add request validation, a focused automated test, or compensation for partial checkout failures.

## Experienced: production-readiness review

Goal: turn the compact teaching system into an explicit engineering assessment.

Evaluate these areas:

| Area | Current teaching implementation | Production direction |
|---|---|---|
| Identity | JWT creation and validation endpoint | Gateway authorization, rotation, claims policy |
| Input safety | Handwritten required-field checks | Schemas, limits, normalization, consistent errors |
| Transactions | Synchronous checkout orchestration | Idempotency, saga/compensation, durable events |
| Reliability | Basic health/readiness probes | Timeouts, retries with budgets, circuit breaking |
| Data | Shared MySQL server, separate schemas | Independent lifecycle, migrations, backups, replicas |
| Observability | Prometheus metrics and logs | Correlation IDs, structured logs, traces, SLOs |
| Security | Kubernetes Secret example | External secret manager, TLS, network policy, RBAC |
| Delivery | Build/deploy shell scripts | Immutable tags, provenance, scanning, staged delivery |
| Scale | One replica per workload | HPA, disruption budgets, capacity tests |

Suggested contribution: open a design issue before making a cross-cutting change. Explain the failure mode, proposed boundary, migration path, and verification strategy.

## Interview walkthrough

Use this five-part structure:

1. **Problem:** a learning platform that demonstrates a complete commerce flow.
2. **Boundaries:** gateway plus nine domain services with owned schemas.
3. **Critical flow:** reserve inventory, store a COD order, create shipping, send notification.
4. **Operations:** probes, resource limits, metrics, NGINX Ingress, kOps deployment.
5. **Trade-offs:** synchronous calls and simplified security keep the example understandable but expose clear production extension points.

Avoid describing the repository as production-ready. “Production-style educational reference” is accurate and gives you space to discuss how you would harden it.
