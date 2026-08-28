# CloudCart E-Commerce Microservices — Interview Explanation & Demo Guide

**Project Name:** CloudCart E-Commerce Microservices Platform  
**Designed By:** [@jeevanm84](https://github.com/jeevanm84)
**GitHub:** https://github.com/jeevanm84/mjcart-ecommerce-microservices

---

## 📖 Interview Explanation (1-2 minutes)

"I designed and deployed **CloudCart**, a production-style e-commerce microservices platform on Kubernetes. Here's the complete flow:

### Architecture Overview

**User Journey:**
1. User accesses the **React frontend** through an **AWS Load Balancer**
2. Traffic passes through **NGINX Ingress Controller** (managed by kOps)
3. Requests are routed to:
   - `/` → Frontend Service (React + Nginx UI)
   - `/api/*` → API Gateway (Node.js/Express)

### Microservices Architecture

The **API Gateway** acts as a central routing layer that proxies all backend requests to 11 independent microservices:

**Core Services:**
- **Auth Service** — User registration and JWT-based login
- **User Service** — User profile management
- **Product Service** — Product catalog with Redis caching
- **Inventory Service** — Stock levels and reservation
- **Cart Service** — Redis-backed shopping cart
- **Order Service** — Order orchestration (coordinates with Payment, Shipping, Notification)
- **Payment Service** — Mock payment processing
- **Shipping Service** — Shipment creation and tracking
- **Notification Service** — Order notifications
- **Review Service** — Product reviews and ratings

### Database & Cache

- **MySQL StatefulSet** — 8 separate databases following database-per-service pattern
- **Redis** — Session storage and product catalog caching
- **Persistent Storage** — MySQL uses EBS volumes via Persistent Volume Claims

### Kubernetes Deployment

**Platform:** kOps self-managed Kubernetes on AWS EC2  
**Cluster Setup:**
- 1 Master node (t3.large, 50GB)
- 3 Worker nodes (t3.large, 50GB each)
- Full IAM admin role

**Kubernetes Resources:**
- **Deployments** — 11 microservices, 2 replicas each
- **StatefulSet** — MySQL with persistent storage
- **Services** — ClusterIP for internal routing
- **ConfigMap** — Non-sensitive configuration
- **Secret** — Sensitive data (passwords, JWT)
- **Ingress** — NGINX-based routing
- **PVC/EBS** — Persistent storage
- **HPA** — Auto-scaling based on CPU

### Complex Workflow: Order Placement

1. User adds products to cart (stored in Redis)
2. User initiates checkout
3. Order Service receives request
4. **Inventory Service** — Reserves stock
5. **Payment Service** — Processes payment
6. **Shipping Service** — Creates shipment
7. **Notification Service** — Sends confirmation
8. Response returned to frontend

### Monitoring & Observability

- **Prometheus** — Scrapes `/metrics` from all services
- **Grafana** — Visualizes metrics with dashboards
- **PrometheusRule** — Automated alerts for failures

### Key Technologies

- Frontend: React, Vite, Nginx
- Backend: Node.js, Express
- Database: MySQL 8.0, Redis 7
- Container: Docker
- Orchestration: Kubernetes (kOps)
- Monitoring: Prometheus, Grafana

This setup demonstrates enterprise-grade microservices architecture with proper separation of concerns, high availability, monitoring, and DevOps best practices."

---

## 🎬 Demo Flow (20 Steps)

### Prerequisites

```bash
export APP_URL=http://$(kubectl get svc -n ingress-nginx ingress-nginx-controller -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
```

### Step 1-2: Architecture & Register User (3 mins)

```bash
# Show architecture diagram
curl -X POST $APP_URL/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "MJ",
    "email": "mj@cloudcart.com",
    "password": "password123"
  }' | jq '.'
```

### Step 3-4: Login & Browse Products (2 mins)

```bash
TOKEN=$(curl -s -X POST $APP_URL/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "mj@cloudcart.com",
    "password": "password123"
  }' | jq -r '.token')

curl $APP_URL/api/products | jq '.[0:3]'
```

### Step 5-6: Check Inventory & Add to Cart (2 mins)

```bash
curl $APP_URL/api/inventory/1

curl -X POST $APP_URL/api/cart/add \
  -H "Content-Type: application/json" \
  -d '{
    "userId": 1,
    "productId": 1,
    "name": "Laptop Pro 15",
    "price": 89999,
    "quantity": 1
  }' | jq '.'
```

### Step 7-8: Successful & Failed Orders (3 mins)

```bash
# Success (card 1111)
curl -X POST $APP_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": 1, "items": [{"productId": 1, "name": "Laptop", "price": 89999, "quantity": 1}], "cardNumber": "1111"}' | jq '.'

# Failure (card 0000)
curl -X POST $APP_URL/api/orders \
  -H "Content-Type: application/json" \
  -d '{"userId": 1, "items": [{"productId": 2, "name": "Mouse", "price": 1499, "quantity": 1}], "cardNumber": "0000"}' | jq '.'
```

### Step 9-10: Check Data (MySQL & Redis) (3 mins)

```bash
# MySQL
kubectl exec -it mysql-0 -n ecommerce -- mysql -uroot -proot123 -e "USE order_db; SELECT * FROM orders;"

# Redis
kubectl exec -it deploy/redis -n ecommerce -- redis-cli KEYS \*
```

### Step 11-13: Kubernetes Resources (3 mins)

```bash
kubectl get pods -n ecommerce
kubectl get svc -n ecommerce
kubectl get ingress -n ecommerce
```

### Step 14-15: Logs (2 mins)

```bash
kubectl logs -n ecommerce deploy/api-gateway --tail=20
kubectl logs -n ecommerce deploy/order-service --tail=20
```

### Step 16-17: Prometheus & Grafana (3 mins)

```bash
# Port forward Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090 --address 0.0.0.0 &

# Port forward Grafana
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80 --address 0.0.0.0 &

# Open browser: http://KOPS_IP:9090 and http://KOPS_IP:3000
```

### Step 18: Generate Load (2 mins)

```bash
for i in {1..50}; do
  curl -s $APP_URL/api/products > /dev/null
  echo "Request $i"
done

# Watch metrics spike in Prometheus
```

### Step 19: Kill & Recover Pod (2 mins)

```bash
# Kill a pod
kubectl delete pod <product-service-pod> -n ecommerce

# Watch replacement
kubectl get pods -n ecommerce -w | grep product-service
```

### Step 20: Scale Service (1 min)

```bash
kubectl scale deployment/product-service -n ecommerce --replicas=5
kubectl get pods -n ecommerce | grep product-service
```

---

## 🎤 Key Points to Emphasize

✅ **Microservices** — 11 independent services  
✅ **Kubernetes** — Self-healing, auto-scaling  
✅ **High Availability** — 2+ replicas, health checks  
✅ **Observable** — Prometheus + Grafana  
✅ **Persistent** — MySQL StatefulSet with EBS  
✅ **Complex Workflows** — Order Service coordination  
✅ **Production-Ready** — Proper error handling, logging, monitoring  

---

## ❓ Common Interview Questions

**Q: Why Kubernetes?**
A: "Self-healing, auto-scaling, automated deployments, and resource management out of the box."

**Q: How do you handle service failures?**
A: "Health checks, readiness probes, automatic restarts, and API Gateway retry logic."

**Q: How do you scale under load?**
A: "HPA auto-scales pods based on CPU. Redis caches frequently accessed data."

**Q: How do you monitor?**
A: "Prometheus scrapes metrics every 15s. Grafana visualizes. PrometheusRule creates alerts."

**Q: How do you persist data?**
A: "MySQL StatefulSet with Persistent Volumes backed by AWS EBS."

---

**Total Demo Time: 30-45 minutes**

For complete setup instructions, see CLOUDCART_SETUP_GUIDE.md
