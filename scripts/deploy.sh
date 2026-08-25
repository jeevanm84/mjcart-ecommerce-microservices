#!/bin/bash
# MJ's Cart - apply all Kubernetes manifests in the right order
set -e

echo ">>> Creating namespace"
kubectl apply -f k8s/namespace.yaml

echo ">>> Creating config/secrets"
kubectl apply -f k8s/configmap.yaml
kubectl apply -f k8s/secret.yaml

echo ">>> Creating MySQL init ConfigMap from database/init.sql"
kubectl create configmap mysql-init --from-file=database/init.sql -n mjcart --dry-run=client -o yaml | kubectl apply -f -

echo ">>> Deploying MySQL and Redis"
kubectl apply -f k8s/mysql.yaml
kubectl apply -f k8s/redis.yaml

echo ">>> Waiting for MySQL to be ready (this can take ~60s on first boot)"
kubectl rollout status statefulset/mysql -n mjcart --timeout=180s

echo ">>> Deploying backend microservices (no payment-service, COD checkout only)"
kubectl apply -f k8s/backend.yaml

echo ">>> Deploying frontend"
kubectl apply -f k8s/frontend.yaml

echo ">>> Applying Ingress and HPA"
kubectl apply -f k8s/ingress.yaml
kubectl apply -f k8s/hpa.yaml

echo ">>> Applying ServiceMonitor (requires kube-prometheus-stack already installed)"
kubectl apply -f k8s/monitoring.yaml || echo "Skip if Prometheus Operator CRDs aren't installed yet."

echo ">>> Done. Check status with: kubectl get pods -n mjcart"
