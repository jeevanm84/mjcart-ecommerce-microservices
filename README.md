# MJ's Cart - E-Commerce Microservices Platform

**Author:** MJ (Jeevan Kumar Mamuduri) - [github.com/jeevanm84](https://github.com/jeevanm84)
**Payment gateway:** None, by design. Checkout is Cash-on-Delivery (COD) only.
**Cluster:** kOps (self-managed Kubernetes on EC2), not EKS.

## Generate the project

This README ships alongside `create-mjcart.sh`, the script that generates
everything below from scratch:

```bash
export DOCKER_USER=jeevanm84
export IMAGE_TAG=v1
export NAMESPACE=mjcart
./create-mjcart.sh
cd mjcart-ecommerce-microservices
```

## Services (no payment-service)

api-gateway, auth-service, user-service, product-service, inventory-service,
cart-service, order-service, shipping-service, notification-service,
review-service, frontend. Each backend service exposes `/health`, `/ready`,
and `/metrics`. See `docs/ARCHITECTURE.md` and `docs/API.md` for details.

## Run locally (Docker required)

```bash
# 1. Start MySQL + Redis
docker run -d --name mysql -e MYSQL_ROOT_PASSWORD=ChangeMe_RootPass123 -p 3306:3306 -v $PWD/database/init.sql:/docker-entrypoint-initdb.d/init.sql mysql:8.0
docker run -d --name redis -p 6379:6379 redis:7-alpine

# 2. Run each service (separate terminals), e.g.
cd services/auth-service && npm install && MYSQL_HOST=localhost MYSQL_PASSWORD=ChangeMe_RootPass123 JWT_SECRET=mjcart-jwt-secret-change-me node server.js

# 3. Run the frontend
cd frontend && npm install && npm run dev
```

## Deploy on kOps

IMP: give the nodes a bigger instance type (`t3.large`+) with 50GB disks -
this platform runs 10 backend services + MySQL + Redis + NGINX Ingress +
Prometheus/Grafana on top.

```bash
# 1. Create the cluster
export KOPS_STATE_STORE=s3://mjcart-kops-state-<your-unique-suffix>
./scripts/create-kops-cluster.sh

# 2. Build & push images
export DOCKER_USER=jeevanm84
export IMAGE_TAG=v1
./scripts/build-push.sh

# 3. Install NGINX Ingress + (optional) Prometheus stack
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace

# 4. Deploy the platform
./scripts/deploy.sh

# 5. Verify
./scripts/verify.sh
kubectl get ingress -n mjcart
```

## Teardown

```bash
./scripts/delete-kops-cluster.sh
```

## Resume Summary

Built and deployed MJ's Cart, a production-style e-commerce microservices
platform on a self-managed Kubernetes cluster (kOps) using React, Node.js,
MySQL, Redis, Docker, NGINX Ingress, Prometheus, and Grafana. Implemented an
API Gateway pattern to route frontend requests to 9 independent backend
microservices (Auth, User, Product, Inventory, Cart, Order, Shipping,
Notification, Review). Deployed MySQL as a StatefulSet with persistent
storage and Redis for cart/session caching and product-list caching.
Configured Kubernetes Deployments, Services, Secrets, ConfigMaps, Ingress,
readiness/liveness probes, resource limits, and Prometheus metrics on every
service. Deliberately excluded a payment gateway - checkout is
Cash-on-Delivery only, keeping the platform out of PCI card-data scope.

## Interview Explanation

In this project I designed a real-time e-commerce microservices application
called MJ's Cart. The user reaches the React frontend through an AWS load
balancer and an NGINX Ingress Controller running on a kOps-managed
Kubernetes cluster. The frontend calls backend APIs through an API Gateway,
which proxies traffic to independent microservices, each with its own MySQL
database and its own health/readiness/metrics endpoints. The Order Service
coordinates with Inventory, Shipping, and Notification services to complete
checkout - there is no Payment Service in this design, so an order is
placed as Cash-on-Delivery immediately after stock is reserved. The whole
platform is monitored with Prometheus and Grafana.
