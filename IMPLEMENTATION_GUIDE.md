# MJ's Cart — Complete Implementation Guide

**Status:** Production-Ready | **Last Updated:** August 25, 2026

---

## 🚀 Quick Start (Choose Your Path)

### Path 1: Local Development (5 mins)
```bash
# Clone & start
git clone https://github.com/jeevanm84/mjcart-ecommerce-microservices.git
cd mjcart-ecommerce-microservices
docker compose up --build

# Access
Frontend:    http://localhost:3000
API Gateway: http://localhost:8080/health
```

**Prerequisites:** Docker 20.10+, Docker Compose 1.29+

---

### Path 2: Production on Kubernetes (30 mins setup + 15 mins cluster provisioning)
```bash
# 1. Prerequisites check
kops version && kubectl version --client && aws sts get-caller-identity

# 2. Export configuration
export KOPS_STATE_STORE=s3://mjcart-kops-state-$(date +%s)
export CLUSTER_NAME=mjcart.k8s.local
export ZONES=ap-south-1a,ap-south-1b    # Update to your AWS region
export NODE_SIZE=t3.large NODE_COUNT=3 VOLUME_SIZE=50

# 3. Create cluster (~15 mins)
chmod +x scripts/*.sh
./scripts/create-kops-cluster.sh

# 4. Build & push images
./scripts/build-push.sh <your-ecr-uri> latest

# 5. Install Helm add-ons (one-time)
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx -n ingress-nginx --create-namespace

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack -n monitoring --create-namespace -f k8s/values-monitoring.yaml

# 6. Deploy application
./scripts/deploy.sh

# 7. Verify & access
kubectl get pods -n mjcart
kubectl get ingress -n mjcart
kops validate cluster
```

**Prerequisites:** kOps 1.24+, kubectl 1.24+, Helm 3.0+, AWS CLI 2.0+, Terraform 1.0+ (optional)

---

## 📋 Environment Setup

### Local Development (.env or docker-compose.yml)
```bash
DB_HOST=mysql
DB_USER=root
DB_PASSWORD=rootpass
JWT_SECRET=dev-secret-change-me-in-production
REDIS_HOST=redis
PORT=8080  # api-gateway
```

### Kubernetes Production (Secrets & ConfigMap)
```bash
# Edit k8s/secret.yaml with production values
kubectl apply -f k8s/secret.yaml

# Verify
kubectl get secrets -n mjcart
kubectl get configmap -n mjcart
```

**Key Secrets to Configure:**
- `mysql-root-password`: Production-grade MySQL password (generate with `openssl rand -base64 32`)
- `mysql-user`: Application MySQL user (recommend dedicated non-root user)
- `jwt-secret`: JWT signing key (generate with `openssl rand -base64 64`)

---

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────┐
│          Frontend (React + NGINX)                   │
│          Replicas: 2 | Port: 3000 (local/80 k8s)   │
└────────────────────┬────────────────────────────────┘
                     │
        ┌────────────┴────────────┐
        ↓                         ↓
    AWS ELB             NGINX Ingress Controller
    (Route 53)          (on kOps: auto-provisioned)
        │                         │
        └────────────┬────────────┘
                     ↓
        ┌────────────────────────┐
        │   API Gateway          │
        │  Node.js/Express       │
        │  Replicas: 2 | Port: 8080
        │  Routes: /api/*        │
        └────────┬───────────────┘
                 │
    ┌────────────┼────────────┬──────────────┬─────────────┐
    ↓            ↓            ↓              ↓             ↓
┌────────┐  ┌───────┐  ┌─────────┐  ┌──────────┐  ┌────────┐
│ Auth   │  │ User  │  │Product  │  │Inventory │  │ Cart   │
│Service │  │Service│  │Service  │  │Service   │  │Service │
│ 4001   │  │ 4002  │  │ 4003    │  │ 4004     │  │ 4005   │
└────────┘  └───────┘  └─────────┘  └──────────┘  └────────┘

    ↓            ↓            ↓              ↓             ↓
┌────────┐  ┌───────┐  ┌─────────┐  ┌──────────┐  ┌────────┐
│ Order  │  │Shipping  │  │Notify  │  │ Review   │  │ Redis  │
│Service │  │Service   │  │Service │  │Service   │  │ Cache  │
│ 4006   │  │ 4007     │  │ 4008   │  │ 4009     │  │ 6379   │
└────────┘  └───────┘  └─────────┘  └──────────┘  └────────┘
                 │
        ┌────────┴────────┐
        ↓                 ↓
    ┌──────────────┐  ┌──────────────┐
    │   MySQL      │  │  Prometheus  │
    │ StatefulSet  │  │  Monitoring  │
    │  (8 dbs)     │  │  + Grafana   │
    └──────────────┘  └──────────────┘
```

**Key Points:**
- **No Payment Service**: Checkout is COD (Cash-on-Delivery) only
- **Database-per-Service**: Each microservice owns its own MySQL database
- **Redis**: Session & cart caching
- **High Availability**: 2 replicas per service, HPA enabled on api-gateway, order-service, product-service
- **Observability**: Prometheus scrapes `/metrics` from all services; Grafana dashboards included

---

## 🔧 Core Services

### 1. Auth Service (Port 4001)
**Responsibility:** JWT-based user registration & login
```bash
POST   /register          # { email, password } → { id, email }
POST   /login            # { email, password } → { token, user }
GET    /verify           # Authorization: Bearer <token> → { valid, decoded }
GET    /health           # Liveness probe
```
**Database:** `auth_db` → `users` table (email, password_hash, role)

### 2. User Service (Port 4002)
**Responsibility:** User profile management
```bash
POST   /profile          # Create user profile
GET    /profile/:user_id # Fetch profile
PUT    /profile/:user_id # Update profile
GET    /health           # Liveness probe
```
**Database:** `user_db` → `profiles` table

### 3. Product Service (Port 4003)
**Responsibility:** Product catalog & categories
```bash
GET    /products         # List all products
GET    /products/:id     # Fetch single product
GET    /categories       # List categories
POST   /products         # Create product (admin)
GET    /health           # Liveness probe
```
**Database:** `product_db` → `products`, `categories` tables

### 4. Inventory Service (Port 4004)
**Responsibility:** Stock levels & reservation
```bash
GET    /stock/:product_id       # Get stock level
POST   /reserve                 # { product_id, quantity } → reserve stock
POST   /release                 # { product_id, quantity } → release reserved stock
GET    /health                  # Liveness probe
```
**Database:** `inventory_db` → `stock` table

### 5. Cart Service (Port 4005)
**Responsibility:** Shopping cart (Redis-backed)
```bash
GET    /cart/:user_id          # Get cart items
POST   /cart/:user_id/add      # { product_id, quantity }
DELETE /cart/:user_id/item/:id # Remove item
GET    /health                 # Liveness probe
```
**Storage:** Redis (key: `cart:{user_id}`)

### 6. Order Service (Port 4006)
**Responsibility:** Order orchestration (COD checkout)
```bash
POST   /orders           # { user_id, items[] } → create order (COD)
GET    /orders/:id       # Fetch order details
GET    /orders/user/:uid # Fetch user's orders
PATCH  /orders/:id/status # Update order status
GET    /health           # Liveness probe
```
**Database:** `order_db` → `orders`, `order_items` tables
**Workflow:** Reserve inventory → Create shipment → Send notification → Mark PLACED

### 7. Shipping Service (Port 4007)
**Responsibility:** Shipment creation & tracking
```bash
POST   /shipments        # { order_id, user_id } → create shipment
GET    /shipments/:id    # Track shipment
PATCH  /shipments/:id/status # Update (PENDING → SHIPPED → DELIVERED)
GET    /health           # Liveness probe
```

### 8. Notification Service (Port 4008)
**Responsibility:** Order notifications (mock/log-based)
```bash
POST   /notify           # { order_id, type, message }
GET    /notifications/:id # Fetch notification
GET    /health           # Liveness probe
```

### 9. Review Service (Port 4009)
**Responsibility:** Product reviews
```bash
POST   /reviews          # { product_id, user_id, rating, comment }
GET    /reviews/:product_id # List reviews for product
GET    /health           # Liveness probe
```
**Database:** `review_db` → `reviews` table

### 10. API Gateway (Port 8080)
**Responsibility:** Central routing layer
```bash
GET    /health           # Route map
# Routes to all 9 services via proxy:
/api/auth/*              → auth-service:4001
/api/users/*             → user-service:4002
/api/products/*          → product-service:4003
/api/categories/*        → product-service:4003
/api/inventory/*         → inventory-service:4004
/api/cart/*              → cart-service:4005
/api/orders/*            → order-service:4006
/api/shipments/*         → shipping-service:4007
/api/notifications/*     → notification-service:4008
/api/reviews/*           → review-service:4009
```

---

## 🗄️ Database Schema

### Databases (Database-per-Service)
1. **auth_db** — User credentials (JWT)
2. **user_db** — User profiles
3. **product_db** — Products & categories
4. **inventory_db** — Stock tracking
5. **order_db** — Orders & order items
6. **review_db** — Product reviews
7. **shipping_db** — (Optional, hardcoded in notification-service for now)

**Init Script:** `database/init.sql` runs automatically on MySQL startup (via ConfigMap in k8s/deploy.sh)

---

## 🐳 Docker Compose (Local Dev)

```bash
docker compose up --build

# Services that start:
mysql:8.0              (port 3306)
redis:7-alpine         (port 6379)
auth-service           (port 4001)
user-service           (port 4002)
product-service        (port 4003)
inventory-service      (port 4004)
cart-service           (port 4005)
order-service          (port 4006)
shipping-service       (port 4007)
notification-service   (port 4008)
review-service         (port 4009)
api-gateway            (port 8080)
frontend               (port 3000)
```

**Logs:**
```bash
docker compose logs -f api-gateway
docker compose logs -f mysql
```

**Tear down:**
```bash
docker compose down -v  # -v removes named volumes (mysql-data)
```

---

## ☸️ Kubernetes Deployment (Production)

### Step 1: Create kOps Cluster
```bash
export KOPS_STATE_STORE=s3://mjcart-kops-state-prod
export CLUSTER_NAME=mjcart.k8s.local
export ZONES=ap-south-1a,ap-south-1b
export NODE_SIZE=t3.large NODE_COUNT=3 VOLUME_SIZE=50

./scripts/create-kops-cluster.sh
# Creates: 1 master, 3 nodes (t3.large, 50GB each)
# Storage: kOps-managed state in S3
```

### Step 2: Install Add-ons
```bash
# NGINX Ingress Controller
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm install ingress-nginx ingress-nginx/ingress-nginx \
  -n ingress-nginx --create-namespace

# Prometheus + Grafana (observability stack)
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm install prometheus prometheus-community/kube-prometheus-stack \
  -n monitoring --create-namespace \
  -f k8s/values-monitoring.yaml
```

### Step 3: Build & Push Container Images
```bash
# Build all 10 services + frontend
./scripts/build-push.sh <your-ecr-uri> latest

# Update image references in k8s/backend.yaml and k8s/frontend.yaml:
# Replace: <YOUR_ECR_OR_REGISTRY> → your-ecr-uri
```

### Step 4: Deploy Application
```bash
./scripts/deploy.sh

# Deployment order:
# 1. Namespace (mjcart)
# 2. ConfigMap + Secrets
# 3. MySQL init ConfigMap
# 4. MySQL StatefulSet + Redis
# 5. Backend microservices (10 services, 2 replicas each)
# 6. Frontend
# 7. Ingress + HPA
# 8. ServiceMonitor (Prometheus)
```

### Step 5: Verify Deployment
```bash
# Check pods
kubectl get pods -n mjcart

# Check services
kubectl get svc -n mjcart

# Check ingress
kubectl get ingress -n mjcart

# Access logs
kubectl logs -f deploy/api-gateway -n mjcart
kubectl logs -f deploy/auth-service -n mjcart

# Port-forward for testing
kubectl port-forward -n mjcart svc/api-gateway 8080:8080 &
curl http://localhost:8080/health
```

### Step 6: Access Application
```bash
# Get ELB hostname
kubectl get svc -n ingress-nginx ingress-nginx-controller

# Update DNS (Route 53 or /etc/hosts)
# Point mjscart.example.com → ELB hostname

# Access via browser
http://mjscart.example.com        # Frontend
http://mjscart.example.com/api    # API Gateway
```

### Step 7: Tear Down
```bash
# Delete application
kubectl delete ns mjcart

# Delete cluster
./scripts/delete-kops-cluster.sh

# Remove kOps state S3 bucket (if no longer needed)
aws s3 rm s3://mjcart-kops-state-prod --recursive
aws s3api delete-bucket --bucket mjcart-kops-state-prod
```

---

## 📊 Monitoring & Observability

### Prometheus
- **Scrape Targets:** All 10 services expose `/metrics` (Prometheus format)
- **Retention:** 15 days (default)
- **Dashboards:** Available in Grafana

**Access Prometheus:**
```bash
kubectl port-forward -n monitoring svc/prometheus-operated 9090:9090 &
# http://localhost:9090
```

### Grafana
- **Pre-installed Dashboards:**
  - Kubernetes Cluster Monitoring
  - Node Exporter (system metrics)
  - Prometheus (scrape stats)

**Access Grafana:**
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80 &
# http://localhost:3000
# Default credentials: admin / prom-operator
```

### Custom Metrics (Examples)
- `http_requests_total` — Total HTTP requests per service
- `http_request_duration_seconds` — Latency histogram
- `mysql_connections_active` — Active DB connections
- `redis_connected_clients` — Connected Redis clients

---

## 🔐 Security Best Practices

### Local Development
⚠️ **NOT for production** — uses weak secrets
```bash
JWT_SECRET=dev-secret-change-me-in-production
DB_PASSWORD=rootpass  # Placeholder
```

### Production (Kubernetes)
✅ **Recommended:**
```bash
# 1. Generate strong secrets
openssl rand -base64 32 > /tmp/jwt-secret.txt
openssl rand -base64 32 > /tmp/db-password.txt

# 2. Create secret
kubectl create secret generic mjcart-secrets \
  --from-literal=jwt-secret=$(cat /tmp/jwt-secret.txt) \
  --from-literal=mysql-root-password=$(cat /tmp/db-password.txt) \
  --from-literal=mysql-user=mjcart_app \
  -n mjcart

# 3. Rotate secrets periodically
# Use AWS Secrets Manager or HashiCorp Vault for production

# 4. Enable Network Policies
# kubectl apply -f k8s/network-policies.yaml  # (Create if needed)

# 5. Enable Pod Security Policies
# kubectl label ns mjcart pod-security.kubernetes.io/enforce=baseline
```

### TLS/HTTPS
```bash
# Install cert-manager
helm repo add jetstack https://charts.jetstack.io
helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace

# Create ClusterIssuer (Let's Encrypt)
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: your-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
      - http01:
          ingress:
            class: nginx
EOF

# Update ingress.yaml with certificate annotation
kubectl annotate ingress mjcart-ingress -n mjcart \
  cert-manager.io/cluster-issuer=letsencrypt-prod \
  --overwrite
```

---

## 🚦 Health Checks & Probes

### Liveness Probe
Checks if service is alive; restarts pod if fails.
```yaml
livenessProbe:
  httpGet: { path: /health, port: 4001 }
  initialDelaySeconds: 15
  periodSeconds: 20
  timeoutSeconds: 5
  failureThreshold: 3
```

### Readiness Probe
Checks if service is ready to receive traffic.
```yaml
readinessProbe:
  httpGet: { path: /health, port: 4001 }
  initialDelaySeconds: 8
  periodSeconds: 10
  timeoutSeconds: 3
  failureThreshold: 3
```

### Testing Health
```bash
curl -X GET http://localhost:4001/health
curl -X GET http://localhost:8080/health | jq
```

---

## 📈 Autoscaling (HPA)

**Configured in k8s/hpa.yaml:**
- **api-gateway:** Min 2 → Max 5 replicas (CPU 70% threshold)
- **order-service:** Min 2 → Max 4 replicas (CPU 70% threshold)
- **product-service:** Min 2 → Max 3 replicas (CPU 70% threshold)

**View HPA status:**
```bash
kubectl get hpa -n mjcart
kubectl describe hpa api-gateway -n mjcart

# Manual scaling
kubectl scale deploy/api-gateway --replicas=3 -n mjcart
```

---

## 🧪 Testing

### Unit Tests (Per Service)
```bash
cd services/auth-service
npm test
```

### Integration Tests (Local)
```bash
docker compose up --build
# Wait for all services to be healthy
curl http://localhost:8080/health

# Test auth flow
curl -X POST http://localhost:8080/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'

curl -X POST http://localhost:8080/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"password123"}'
```

### Load Testing (K6 or Apache Bench)
```bash
# Install k6: https://k6.io/docs/getting-started/installation/
k6 run scripts/load-test.js

# Or use Apache Bench
ab -n 1000 -c 10 http://localhost:8080/health
```

---

## 🐛 Troubleshooting

### Pod Won't Start (CrashLoopBackOff)
```bash
kubectl describe pod <pod-name> -n mjcart
kubectl logs <pod-name> -n mjcart
# Common: DB password mismatch, insufficient resources, DNS issues
```

### Database Connection Errors
```bash
# Verify MySQL is running
kubectl get statefulsets -n mjcart
kubectl logs mysql-0 -n mjcart

# Check database contents
kubectl exec -it mysql-0 -n mjcart -- mysql -u root -p'<password>' -e "SHOW DATABASES;"
```

### Service-to-Service Communication Fails
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
nslookup auth-service.mjcart.svc.cluster.local

# Test connectivity
curl http://auth-service:4001/health
```

### Ingress Not Working
```bash
kubectl get ingress -n mjcart
kubectl describe ingress mjcart-ingress -n mjcart
# Check ELB hostname matches DNS
kubectl get svc -n ingress-nginx ingress-nginx-controller
```

---

## 📝 Deployment Checklist

### Pre-Deployment
- [ ] Clone repository
- [ ] Review architecture diagram
- [ ] Set environment variables (KOPS_STATE_STORE, CLUSTER_NAME, etc.)
- [ ] Verify AWS credentials: `aws sts get-caller-identity`
- [ ] Create S3 bucket for kOps state
- [ ] Verify node sizing (t3.large minimum recommended)

### During Deployment
- [ ] Run `./scripts/create-kops-cluster.sh` (wait ~15 mins)
- [ ] Verify cluster: `kops validate cluster`
- [ ] Install Helm add-ons (NGINX Ingress, Prometheus)
- [ ] Build & push Docker images
- [ ] Run `./scripts/deploy.sh`
- [ ] Verify pods: `kubectl get pods -n mjcart`

### Post-Deployment
- [ ] Test health endpoints
- [ ] Test auth flow (register → login → verify)
- [ ] Access Grafana dashboards
- [ ] Configure DNS (Route 53) for Ingress hostname
- [ ] Enable HTTPS (cert-manager + Let's Encrypt)
- [ ] Set up backup strategy (RDS snapshots or velero)

### Production Readiness
- [ ] Rotate secrets (use AWS Secrets Manager)
- [ ] Enable Pod Security Policies
- [ ] Configure Network Policies
- [ ] Enable audit logging
- [ ] Set resource limits & requests correctly
- [ ] Configure PDB (Pod Disruption Budgets)
- [ ] Set up alert rules in Prometheus
- [ ] Document runbook for common failures
- [ ] Test disaster recovery (cluster re-creation)

---

## 📚 Additional Resources

- **Architecture:** See `README.md`
- **API Documentation:** (Add OpenAPI/Swagger spec later)
- **DevOps Guide:** See `scripts/` directory
- **Kubernetes Manifests:** See `k8s/` directory
- **Database Schema:** See `database/init.sql`
- **kOps Documentation:** https://kops.sigs.k8s.io/
- **Kubernetes Best Practices:** https://kubernetes.io/docs/concepts/

---

## 🎯 Next Steps

1. **Test locally:** `docker compose up --build`
2. **Review architecture:** Read `README.md`
3. **Set up Kubernetes:** Follow **Path 2** above
4. **Monitor deployment:** Check `kubectl logs` and Grafana dashboards
5. **Add CI/CD:** Create `.github/workflows/` for automated testing & deployment
6. **API Documentation:** Add OpenAPI spec for frontend developers

---

**Questions?** Check logs, verify health endpoints, or review error messages in pod descriptions.

**Need to scale?** Update `k8s/hpa.yaml` or manually scale with `kubectl scale deploy/<service> --replicas=N -n mjcart`.

**Ready to go live?** Ensure all security best practices are in place, test disaster recovery, and document operational procedures.

