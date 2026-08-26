# MJ's Cart - Architecture

No payment gateway anywhere in this design. Checkout is Cash-on-Delivery
(COD) only: `order-service` sets `payment_method = "COD"` on every order and
never calls out to a payment provider.

```
Users -> Route 53 (optional) -> AWS ELB -> NGINX Ingress Controller
                                                |
                          +---------------------+---------------------+
                          |                                           |
                   Frontend Service (/)                     API Gateway Service (/api)
                   React + NGINX                             Node.js / Express
                                                                       |
                                    Backend microservices (ClusterIP, Deployments)
        +----------+----------+----------+-----------+----------+
        | Auth     | User     | Product  | Inventory | Cart     |
        +----------+----------+----------+-----------+----------+
        | Order    | Shipping | Notification | Review          |
        +----------+----------+----------+-----------+----------+
                                    |
                     MySQL StatefulSet (PVC)    Redis (cart + product cache)
                                    |
                    Prometheus (scrapes /metrics) -> Grafana
```

## Services

| Service | Owns | Notes |
|---|---|---|
| api-gateway | routing only | proxies `/api/*` to each service; no `/api/payments` route |
| auth-service | `auth_db` | register/login, JWT |
| user-service | `user_db` | profile CRUD |
| product-service | `product_db` | catalog, Redis-cached list |
| inventory-service | `inventory_db` | stock, reserve-on-checkout |
| cart-service | Redis only | per-user cart |
| order-service | `order_db` | checkout orchestration - COD only, no payment call |
| shipping-service | `shipping_db` | shipment + tracking number |
| notification-service | `notification_db` | order notifications |
| review-service | `review_db` | product reviews |

Each service exposes `/health`, `/ready`, and `/metrics` (Prometheus format).
