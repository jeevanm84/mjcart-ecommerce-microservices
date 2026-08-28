# CloudCart E-Commerce Microservices — Complete Setup Guide

**Project:** CloudCart E-Commerce Microservices Platform  
**Designed By:** [@jeevanm84](https://github.com/jeevanm84)
**Status:** Production-Ready | **Last Updated:** August 26, 2026

---

## ⚠️ IMPORTANT: Machine Sizing for kOps & Nodes

```bash
# Use BIGGER machines for Master and Worker Nodes
# Minimum: t3.large (2 vCPU, 8GB RAM, 50GB storage)
# Recommended: t3.xlarge or larger for production

kOps Master:    t3.large with 50GB volume
kOps Nodes:     t3.large with 50GB volumes (3-5 nodes)
kOps Role:      admin (full IAM permissions)
```

**Why larger machines?** CloudCart runs:
- 11 backend microservices (2 replicas each)
- MySQL StatefulSet
- Redis
- NGINX Ingress Controller
- Prometheus + Grafana

Undersized nodes (t2.micro/small) will result in `CrashLoopBackOff` and `Pending` pods due to resource constraints, NOT application bugs.

---

## 🚀 Quick Start Paths

### Path 1: Local Development (Docker Compose) — 5 mins

```bash
# Clone repository
git clone https://github.com/jeevanm84/mjcart-ecommerce-microservices.git
cd mjcart-ecommerce-microservices

# Start all services
docker compose up --build

# Access Application
Frontend:    http://localhost:3000
API Gateway: http://localhost:8080/health
```

**Prerequisites:** Docker 20.10+, Docker Compose 1.29+

---

### Path 2: Production on Kubernetes (kOps) — 30 mins setup + 15 mins cluster

```bash
# 1. Prerequisites
kops version && kubectl version --client && aws sts get-caller-identity

# 2. Set environment variables (MUST use t3.large or bigger!)
export KOPS_STATE_STORE=s3://cloudcart-kops-state-prod
export CLUSTER_NAME=cloudcart.k8s.local
export ZONES=ap-south-1a,ap-south-1b
export NODE_SIZE=t3.large              # ⚠️ IMPORTANT: t3.large minimum
export MASTER_SIZE=t3.large
export NODE_COUNT=3
export VOLUME_SIZE=50

# 3. Create cluster (~15 mins)
chmod +x scripts/*.sh
./scripts/create-kops-cluster.sh

# 4. Build & push Docker images
./scripts/build-push.sh <your-registry> v1

# 5. Install NGINX Ingress
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace

# 6. Install Prometheus + Grafana
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace -f k8s/values-monitoring.yaml

# 7. Deploy CloudCart
./scripts/deploy.sh

# 8. Verify
kubectl get pods -n ecommerce
```

**Prerequisites:** kOps 1.24+, kubectl 1.24+, Helm 3.0+, AWS CLI 2.0+

---

## 📋 Architecture Overview

```
Browser
   ↓
AWS Load Balancer
   ↓
NGINX Ingress Controller
   ↓
   ├── Frontend (React + Nginx)
   └── API Gateway (Node.js/Express)
       ├── Auth Service (JWT)
       ├── User Service
       ├── Product Service (+ Redis cache)
       ├── Inventory Service
       ├── Cart Service (Redis-backed)
       ├── Order Service
       ├── Payment Service
       ├── Shipping Service
       ├── Notification Service
       └── Review Service
       
Data Layer:
├── MySQL StatefulSet (8 databases)
└── Redis (cart + product cache)

Monitoring:
├── Prometheus
└── Grafana
```

---

## 🏗️ Database Schema

CloudCart uses **database-per-service** pattern with 8 MySQL databases:

1. **auth_db** — User credentials & JWT
2. **user_db** — User profiles & addresses
3. **product_db** — Product catalog
4. **inventory_db** — Stock levels
5. **order_db** — Orders & order items
6. **payment_db** — Payment transactions
7. **shipping_db** — Shipment tracking
8. **notification_db** — Order notifications
9. **review_db** — Product reviews

All initialized automatically via `database/init.sql`

---

## 🔧 Core Microservices

### 1. API Gateway (Port 3000)
Routes all `/api/*` requests to backend services
```bash
/api/auth/*           → Auth Service
/api/users/*          → User Service
/api/products/*       → Product Service
/api/inventory/*      → Inventory Service
/api/cart/*           → Cart Service
/api/orders/*         → Order Service
/api/payments/*       → Payment Service
/api/shipping/*       → Shipping Service
/api/notifications/*  → Notification Service
/api/reviews/*        → Review Service
```

### 2. Auth Service (Port 3000)
JWT-based user authentication
```bash
POST   /auth/register    # { name, email, password }
POST   /auth/login       # { email, password }
GET    /auth/validate    # Verify JWT token
GET    /health           # Health check
GET    /metrics          # Prometheus metrics
```

### 3. Product Service (Port 3000)
Product catalog with Redis caching
```bash
GET    /products         # List all products (cached)
GET    /products/:id     # Get single product
POST   /products         # Create product (admin)
GET    /metrics          # Prometheus metrics
```

### 4. Inventory Service (Port 3000)
Stock management & reservation
```bash
GET    /inventory/:productId       # Get stock level
POST   /inventory/reserve          # Reserve stock
POST   /inventory/upsert           # Update inventory
```

### 5. Cart Service (Port 3000)
Redis-backed shopping cart
```bash
GET    /cart/:userId              # Get cart items
POST   /cart/add                  # Add to cart
POST   /cart/clear                # Clear cart
```

### 6. Order Service (Port 3000)
Order orchestration & payment coordination
```bash
POST   /orders                    # Create order (COD or paid)
GET    /orders/:orderId           # Get order details
```

### 7. Payment Service (Port 3000)
Mock payment processing
```bash
POST   /payments/pay              # Process payment
```

### 8. Shipping Service (Port 3000)
Shipment creation & tracking
```bash
POST   /shipping/create           # Create shipment
GET    /shipping/:shipmentId      # Track shipment
```

### 9. Notification Service (Port 3000)
Order notifications
```bash
POST   /notifications/send        # Send notification
GET    /notifications/:id         # Get notification
```

### 10. Review Service (Port 3000)
Product reviews
```bash
POST   /reviews                   # Add review
GET    /reviews/product/:id       # Get reviews for product
```

### 11. Frontend (Port 3000)
React + Nginx UI
- Product browsing & filtering
- Search functionality
- Shopping cart
- Order placement
- Payment flow
- User registration & login
- Reviews & ratings

---

## 📊 Testing CloudCart

### Test Endpoints with curl

**Get Products:**
```bash
export APP_URL=http://$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl $APP_URL/api/products
```

**Register User:**
```bash
curl -X POST $APP_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MJ",
    "email": "mj@cloudcart.com",
    "password": "password123"
  }'
```

**Login:**
```bash
curl -X POST $APP_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "mj@cloudcart.com",
    "password": "password123"
  }'
```

**Add to Cart:**
```bash
curl -X POST $APP_URL/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productId": 1,
    "name": "Laptop Pro 15",
    "price": 89999,
    "quantity": 1
  }'
```

**Place Order (Payment Success):**
```bash
curl -X POST $APP_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "items": [
      {
        "productId": 1,
        "name": "Laptop Pro 15",
        "price": 89999,
        "quantity": 1
      }
    ],
    "cardNumber": "1111"
  }'
```

**Place Order (Payment Failure):**
```bash
curl -X POST $APP_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "items": [
      {
        "productId": 2,
        "name": "Wireless Mouse",
        "price": 1499,
        "quantity": 1
      }
    ],
    "cardNumber": "0000"
  }'
```

---

## 🗄️ Database Access

**Get MySQL Password:**
```bash
kubectl get secret cloudcart-secrets -n ecommerce \
  -o jsonpath="{.data.MYSQL_ROOT_PASSWORD}" | base64 -d
echo
```

**Connect to MySQL:**
```bash
kubectl exec -it mysql-0 -n ecommerce -- \
  mysql -uroot -p<password>
```

**Check Databases:**
```sql
SHOW DATABASES;
USE product_db;
SELECT * FROM products;
USE order_db;
SELECT * FROM orders;
SELECT * FROM order_items;
USE payment_db;
SELECT * FROM payments;
```

**Check Redis:**
```bash
kubectl exec -it deploy/redis -n ecommerce -- redis-cli
```

```
KEYS *
GET cart:1
HGETALL cart:1
```

---

## 📊 Monitoring with Prometheus & Grafana

### Access Prometheus

```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 --address 0.0.0.0

# http://KOPS_IP:9090
```

**Useful Queries:**
```
up{namespace="ecommerce"}
api_gateway_http_requests_total
product_service_http_requests_total
order_service_orders_created_total
payment_service_success_total
payment_service_failed_total
sum(rate(api_gateway_http_requests_total[2m]))
```

### Access Grafana

```bash
kubectl get secret -n monitoring kube-prometheus-stack-grafana \
  -o jsonpath="{.data.admin-password}" | base64 -d
echo

# Default username: admin
# Use decoded password above
```

**Port Forward:**
```bash
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 --address 0.0.0.0

# http://KOPS_IP:3000
```

---

## 🛠️ Useful Kubernetes Commands

**Cluster & Namespace:**
```bash
kubectl get nodes
kubectl get all -n ecommerce
```

**Services & Ingress:**
```bash
kubectl get svc -n ecommerce
kubectl describe ingress cloudcart-ingress -n ecommerce
kubectl get svc -n ingress-nginx
```

**Pods & Deployments:**
```bash
kubectl get pods -n ecommerce -o wide
kubectl get deploy -n ecommerce
kubectl describe pod <pod-name> -n ecommerce
```

**Logs & Debug:**
```bash
kubectl logs -n ecommerce deploy/api-gateway
kubectl logs -n ecommerce deploy/product-service -f
kubectl logs -n ecommerce deploy/order-service --tail=50
```

**Restart & Scale:**
```bash
kubectl rollout restart deployment/product-service -n ecommerce
kubectl scale deployment/api-gateway -n ecommerce --replicas=3
kubectl rollout status deployment/product-service -n ecommerce
```

---

## 🐛 Troubleshooting

### Pods in CrashLoopBackOff or Pending

**Check if nodes are too small:**
```bash
kubectl get nodes -o wide
kubectl describe nodes

# If CPU/Memory low, scale nodes to t3.large or larger
```

**Check pod logs:**
```bash
kubectl describe pod <pod-name> -n ecommerce
kubectl logs <pod-name> -n ecommerce
```

### MySQL Not Initializing

**Reset MySQL (WARNING: deletes data):**
```bash
kubectl delete statefulset mysql -n ecommerce
kubectl delete pvc mysql-data-mysql-0 -n ecommerce
kubectl apply -f k8s/mysql.yaml
```

### Frontend/API Not Responding

**Check Ingress:**
```bash
kubectl get ingress -n ecommerce
kubectl describe ingress cloudcart-ingress -n ecommerce
```

---

## ✅ Production Readiness Checklist

- [ ] Use t3.large or bigger instances for kOps nodes
- [ ] Set 50GB+ storage for all nodes
- [ ] Generate strong secrets (not dev defaults)
- [ ] Configure DNS (Route 53) for Ingress hostname
- [ ] Enable HTTPS with cert-manager + Let's Encrypt
- [ ] Set up backup strategy (MySQL snapshots or Velero)
- [ ] Enable Pod Security Policies
- [ ] Configure Network Policies
- [ ] Set resource limits & requests
- [ ] Test disaster recovery

---

**For detailed demo flow and interview explanation, see CLOUDCART_INTERVIEW_EXPLANATION.md**
