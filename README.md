# MJ's Cart — E-Commerce Microservices Platform

**Author:** MJ (Jeevan Kumar Mamuduri) — [github.com/jeevanm84](https://github.com/jeevanm84)
**Project type:** Full-stack Kubernetes-based microservices project
**Payment gateway:** None. Checkout is Cash-on-Delivery (COD) only — there is no
payment-service, no card data, and no payment provider integration anywhere in
this codebase, on purpose.

---

## Architecture Flow

```
Users
  |
Route 53 (optional)
  |
AWS Load Balancer
  |
NGINX Ingress Controller
  |
        +-------------------+-------------------+
        |                                       |
  Frontend Service (/)                   API Gateway Service (/api)
  React + NGINX, 2 replicas              Node.js/Express, 2 replicas
        |                                       |
                                    Backend Microservices (ClusterIP, 2 replicas each)
                    +------------+------------+------------+------------+
                    | Auth       | User       | Product    | Inventory  | Cart (Redis)
                    +------------+------------+------------+------------+
                    | Order      | Shipping   | Notification | Review   |
                    +------------+------------+------------+------------+
                                       |
                        MySQL StatefulSet (PVC/EBS)   Redis (cart + caching)
                                       |
                          Prometheus (scrapes /metrics) -> Grafana dashboards
```

## Main Microservices

| Service | Responsibility |
|---|---|
| Auth Service | User registration and login (JWT) |
| User Service | User profile management |
| Product Service | Product catalog, categories |
| Inventory Service | Stock levels, reservation at checkout |
| Cart Service | Cart storage using Redis |
| Order Service | Order orchestration — **COD checkout, no payment gateway** |
| Shipping Service | Shipment creation and tracking |
| Notification Service | Order notifications (mock/log-based) |
| Review Service | Product reviews |
| API Gateway | Central routing layer (`/api/*` → microservice) |
| Frontend | React + NGINX UI |

There is intentionally **no Payment Service** and no `/api/payments` route in the
API Gateway. `order-service` marks every order `payment_method: "COD"` and never
touches card data, a payment SDK, or a webhook.

## Technologies Used

- Kubernetes on AWS EC2, provisioned and managed with **kOps**
- NGINX Ingress Controller
- Frontend: React (Vite) + NGINX
- Backend: Node.js / Express
- MySQL (StatefulSet, database-per-service)
- Redis (cart storage + caching)
- Docker (containerized)
- Prometheus + Grafana (monitoring)
- ConfigMap / Secret for configuration
- PVC (EBS gp3) for persistent storage
- HPA for autoscaling api-gateway, order-service, product-service

## Repo Structure

```
mjcart-ecommerce-microservices/
├── README.md
├── docker-compose.yml          # local dev, no k8s needed
├── database/init.sql           # schema + seed data, no payment tables
├── frontend/                   # React (Vite) + NGINX
├── services/                   # 10 backend microservices (no payment-service)
│   ├── api-gateway/
│   ├── auth-service/
│   ├── user-service/
│   ├── product-service/
│   ├── inventory-service/
│   ├── cart-service/
│   ├── order-service/
│   ├── shipping-service/
│   ├── notification-service/
│   └── review-service/
├── k8s/
│   ├── namespace.yaml
│   ├── configmap.yaml
│   ├── secret.yaml
│   ├── mysql.yaml               # StatefulSet + headless Service + PVC
│   ├── redis.yaml
│   ├── backend.yaml              # Deployment+Service for all 10 backend services
│   ├── frontend.yaml
│   ├── ingress.yaml
│   ├── hpa.yaml
│   ├── monitoring.yaml           # ServiceMonitor
│   └── values-monitoring.yaml    # kube-prometheus-stack helm values
└── scripts/
    ├── create-kops-cluster.sh
    ├── delete-kops-cluster.sh
    ├── build-push.sh
    └── deploy.sh
```

## Run Locally (no Kubernetes needed)

```bash
docker compose up --build
# frontend:    http://localhost:3000
# api-gateway: http://localhost:8080/health
```

## Deploy on kOps (self-managed Kubernetes on EC2)

This project is built for **kOps**, not EKS — you own the control plane, node
sizing, and networking directly. IMP: give the nodes a bigger instance type
(`t3.large` or larger) with 50GB disks — this platform runs 10 backend
services + MySQL + Redis + NGINX Ingress + Prometheus/Grafana on top, so
undersized nodes will show `Pending`/`CrashLoopBackOff` from resource
pressure, not application bugs.

### 0. Prerequisites

```bash
# kops, kubectl, helm, aws-cli, docker installed and on PATH
kops version
kubectl version --client
aws sts get-caller-identity   # confirms your AWS creds/account
```

### 1. Create the kOps cluster

```bash
export KOPS_STATE_STORE=s3://mjcart-kops-state-<your-unique-suffix>
export CLUSTER_NAME=mjcart.k8s.local   # gossip-based - no Route 53 domain required
export ZONES=ap-south-1a,ap-south-1b   # pick your region's AZs
export NODE_SIZE=t3.large
export MASTER_SIZE=t3.large
export NODE_COUNT=3
export VOLUME_SIZE=50

./scripts/create-kops-cluster.sh
```
This provisions the master + worker ASGs, waits for `kops validate cluster`,
and prints the cluster's default StorageClass — check `k8s/mysql.yaml`
matches it (kOps doesn't ship a fixed StorageClass name the way EKS does).

### 2. Build & push service images

```bash
./scripts/build-push.sh <your-registry> latest
```
Then replace `<YOUR_ECR_OR_REGISTRY>` in `k8s/backend.yaml` and
`k8s/frontend.yaml` with your actual registry.

### 3. Install NGINX Ingress + Prometheus stack (one-time, via Helm)

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace
# On kOps this creates a classic AWS ELB automatically - grab its hostname:
kubectl get svc -n ingress-nginx ingress-nginx-controller

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f k8s/values-monitoring.yaml
```

### 4. Deploy the platform

```bash
./scripts/deploy.sh
```

### 5. Verify

```bash
kubectl get pods -n mjcart
kubectl get svc -n mjcart
kubectl get ingress -n mjcart
kops validate cluster
```

### 6. Tear down (when you're done)

```bash
./scripts/delete-kops-cluster.sh
```

## Important Commands

```bash
# Cluster & namespace
kubectl create namespace mjcart
kubectl get all -n mjcart

# Services & ingress
kubectl get svc -n mjcart
kubectl get ingress -n mjcart

# Pods & deployments
kubectl get pods -n mjcart
kubectl get deploy -n mjcart

# Logs & debug
kubectl logs deploy/api-gateway -n mjcart
kubectl logs deploy/auth-service -n mjcart
kubectl describe pod <pod-name> -n mjcart

# Database access
kubectl exec -it mysql-0 -n mjcart -- mysql -u root -p
```

## Resume Summary

Built and deployed MJ's Cart, a production-style e-commerce microservices
platform on Kubernetes using React, Node.js, MySQL, Redis, Docker, NGINX
Ingress, Prometheus, and Grafana. Implemented an API Gateway pattern to route
frontend requests to 9 independent backend microservices (Auth, User, Product,
Inventory, Cart, Order, Shipping, Notification, Review). Deployed MySQL as a
StatefulSet with persistent storage and Redis for cart/session caching.
Configured Kubernetes Deployments, Services, Secrets, ConfigMaps, Ingress,
readiness/liveness probes, resource limits, and HPA. Designed checkout as
Cash-on-Delivery only — deliberately excluded a payment gateway to keep the
platform free of PCI-scope card-data handling.

## Interview Explanation

In this project I designed a real-time e-commerce microservices application
called MJ's Cart. The user accesses the React frontend through an AWS Load
Balancer and NGINX Ingress. The frontend calls backend APIs through an API
Gateway, which routes traffic to independent microservices. Each microservice
is independently deployable and communicates with MySQL or Redis as needed.
The Order Service coordinates with Inventory, Shipping, and Notification
services to complete the order flow — there's no Payment Service in this
design, so checkout is Cash-on-Delivery only and the order is placed directly
once stock is reserved. The entire platform runs on Kubernetes and is
monitored using Prometheus and Grafana.
