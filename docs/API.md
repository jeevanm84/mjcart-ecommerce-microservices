# API reference

Use `http://localhost:3000/api` when running the full Compose application through the frontend proxy, or `http://localhost:8080/api` to call the published API gateway directly.

Requests and responses use JSON unless noted. This teaching API has intentionally simplified authorization: registration and login produce JWTs, but most domain routes do not yet enforce them.

## Gateway route map

| Public prefix | Service | Purpose |
|---|---|---|
| `/api/auth` | Auth | Register, login, validate token |
| `/api/users` | User | Profiles |
| `/api/products` | Product | Catalog |
| `/api/inventory` | Inventory | Stock and reservation |
| `/api/cart` | Cart | Redis-backed carts |
| `/api/orders` | Order | COD checkout and history |
| `/api/shipping` | Shipping | Shipments |
| `/api/notifications` | Notification | Stored notifications |
| `/api/reviews` | Review | Product reviews |

There is deliberately no payments route. Every order uses Cash on Delivery (COD).

## Auth

| Method | Path | Body or header | Result |
|---|---|---|---|
| `POST` | `/api/auth/register` | `name`, `email`, `password` | Creates user and returns JWT |
| `POST` | `/api/auth/login` | `email`, `password` | Returns JWT and user |
| `GET` | `/api/auth/validate` | `Authorization: Bearer <token>` | Decodes a valid JWT |

```bash
curl --request POST http://localhost:3000/api/auth/register \
  --header 'Content-Type: application/json' \
  --data '{"name":"Demo User","email":"demo@example.com","password":"demo-password"}'
```

## Users

| Method | Path | Body | Result |
|---|---|---|---|
| `GET` | `/api/users/:userId` | — | Profile or `null` |
| `PUT` | `/api/users/:userId` | `name`, `phone`, `address`, `city`, `country` | Creates or replaces profile fields |

## Products

| Method | Path | Body | Result |
|---|---|---|---|
| `GET` | `/api/products` | — | Product list; cached in Redis |
| `GET` | `/api/products/:id` | — | One product or `404` |
| `POST` | `/api/products` | `name`, `description`, `category`, `price`, `image_url` | Creates a product |

Creating a product does not automatically create inventory. The current admin UI calls Product and Inventory in sequence.

## Inventory

| Method | Path | Body | Result |
|---|---|---|---|
| `GET` | `/api/inventory/:productId` | — | Quantity; returns zero for an unknown product |
| `POST` | `/api/inventory/upsert` | `productId`, `quantity` | Creates or updates quantity |
| `POST` | `/api/inventory/reserve` | `productId`, `quantity` | Atomically reduces stock when sufficient |

```bash
curl --request POST http://localhost:3000/api/inventory/reserve \
  --header 'Content-Type: application/json' \
  --data '{"productId":1,"quantity":1}'
```

## Cart

| Method | Path | Body | Result |
|---|---|---|---|
| `GET` | `/api/cart/:userId` | — | Cart array |
| `POST` | `/api/cart/add` | `userId`, `productId`, `name`, `price`, `quantity` | Updated cart |
| `POST` | `/api/cart/clear` | `userId` | Clears cart |

Carts expire from Redis after 24 hours.

## Orders

| Method | Path | Body | Result |
|---|---|---|---|
| `POST` | `/api/orders` | `userId`, non-empty `items` | Reserves stock and creates COD order |
| `GET` | `/api/orders/:userId` | — | User order history |
| `GET` | `/api/orders/detail/:orderId` | — | Order and line items |

```bash
curl --request POST http://localhost:3000/api/orders \
  --header 'Content-Type: application/json' \
  --data '{
    "userId": 1,
    "items": [
      {"productId": 1, "name": "Laptop Pro 15", "price": 89999, "quantity": 1}
    ]
  }'
```

The response includes `paymentMethod: "COD"`. The current synchronous flow is:

1. reserve every item through Inventory;
2. create the order and line items in MySQL;
3. request a shipment;
4. store a notification.

This is not an atomic distributed transaction. The [advanced learning path](LEARNING_PATHS.md#experienced-production-readiness-review) identifies compensation and idempotency as production extensions.

## Shipping

| Method | Path | Body | Result |
|---|---|---|---|
| `POST` | `/api/shipping/create` | `orderId` | Creates or updates shipment and tracking number |
| `GET` | `/api/shipping/:orderId` | — | Shipment or `null` |

## Notifications

| Method | Path | Body | Result |
|---|---|---|---|
| `POST` | `/api/notifications/send` | `userId`, `type`, `message` | Stores notification |
| `GET` | `/api/notifications` | — | Latest 50 notifications |

## Reviews

| Method | Path | Body | Result |
|---|---|---|---|
| `POST` | `/api/reviews` | `productId`, `userId`, `rating`, `comment` | Creates review |
| `GET` | `/api/reviews/product/:productId` | — | Reviews newest first |

## Operational endpoints

Every backend service exposes these paths directly inside its container and Kubernetes Service:

| Path | Purpose |
|---|---|
| `/health` | Process liveness |
| `/ready` | Dependency readiness where applicable |
| `/metrics` | Prometheus text metrics |

The API gateway's operational endpoints are available at `http://localhost:8080/health`, `/ready`, and `/metrics` in the local Compose environment.

## Common errors

| Status | Meaning in this project |
|---|---|
| `400` | Required input missing or insufficient stock |
| `401` | Invalid credentials or JWT |
| `404` | Product not found |
| `409` | Email already registered |
| `500` | Service or database operation failed |
| `502` | Gateway could not reach a target service |
