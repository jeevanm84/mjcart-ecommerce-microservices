# Getting started

This guide takes you from a clean machine to a working order flow. The Docker Compose path is the recommended starting point because it runs the same service boundaries without requiring a cloud account or Kubernetes cluster.

## 1. Check the prerequisites

```bash
git --version
docker --version
docker compose version
curl --version
```

Docker must be running. Allocate at least 6 GB of memory because the stack starts MySQL, Redis, a frontend, an API gateway, and nine domain services.

## 2. Clone and configure

```bash
git clone https://github.com/jeevanm84/mjcart-ecommerce-microservices.git
cd mjcart-ecommerce-microservices
cp .env.example .env
```

The checked-in defaults are for local learning only. Change `JWT_SECRET` in `.env` if the environment is shared with anyone else.

## 3. Start the platform

```bash
docker compose up --build -d
docker compose ps
```

The first start downloads base images, builds eleven application images, and initializes the databases. This can take several minutes. Follow progress with:

```bash
docker compose logs -f mysql api-gateway frontend
```

Press `Ctrl+C` to stop following logs; the containers continue running.

## 4. Verify the platform

```bash
./scripts/verify-local.sh
```

Expected result:

```text
Frontend                OK
API gateway             OK
Product catalog         OK
Inventory               OK

All local smoke checks passed.
```

If the check runs before MySQL is ready, wait 20 seconds and retry. See [Troubleshooting](#troubleshooting) if it still fails.

## Your first guided demo

1. Open <http://localhost:3000>.
2. Choose **Login**, keep or replace the sample values, and select **Register**.
3. Open a product and choose **Add to Cart**.
4. Select **Place Order (COD)**.
5. Open **Orders** to see the stored order.

That single flow crosses the frontend, API gateway, Auth, Product, Inventory, Cart, Order, Shipping, and Notification services. MySQL stores durable records, while Redis stores the cart and product-list cache.

## Explore with the API

List products:

```bash
curl --silent http://localhost:3000/api/products
```

Check stock:

```bash
curl --silent http://localhost:3000/api/inventory/1
```

Register a disposable local user:

```bash
curl --request POST http://localhost:3000/api/auth/register \
  --header 'Content-Type: application/json' \
  --data '{"name":"Demo User","email":"demo@example.com","password":"demo-password"}'
```

The complete route list and request bodies are in the [API reference](API.md).

## Observe the system

View service logs:

```bash
docker compose logs -f api-gateway order-service inventory-service
```

Inspect a Prometheus endpoint through the directly published gateway:

```bash
curl --silent http://localhost:8080/metrics
```

Inspect data directly for learning purposes:

```bash
docker compose exec mysql mysql -uroot -prootpass -e 'SELECT * FROM order_db.orders;'
docker compose exec redis redis-cli KEYS 'cart:*'
```

Do not use broad Redis `KEYS` scans in production; this command is safe here only because the local dataset is tiny.

## Stop or reset

Preserve database data:

```bash
docker compose down
```

Delete containers and the local MySQL volume for a completely fresh start:

```bash
docker compose down --volumes
```

## Troubleshooting

### Port already in use

Check whether ports `3000`, `3306`, `6379`, or `8080` are already occupied. Stop the conflicting process or change the host-side port in `docker-compose.yml`.

### A service cannot connect to MySQL

```bash
docker compose ps mysql
docker compose logs mysql
docker compose logs auth-service
```

If an older volume was created with different credentials, reset it with `docker compose down --volumes`, then start again. This deletes local demo data.

### The UI opens but API calls fail

```bash
curl --verbose http://localhost:3000/api/products
docker compose logs frontend api-gateway product-service
```

The frontend's NGINX server proxies `/api/*` to `api-gateway:3000`. A `502` usually means the gateway or target service is still starting.

### Rebuild one component

```bash
docker compose up --build -d frontend
docker compose up --build -d product-service
```

## Develop without containers

Running every service manually is useful when debugging but requires local MySQL and Redis instances. Each backend uses port `3000` by default, so assign unique `PORT` values and update the gateway target URLs. For most contributors, run MySQL and Redis with Compose and start only the service being edited on the host.

Continue with the [learning paths](LEARNING_PATHS.md) or [contribution guide](../CONTRIBUTING.md).
