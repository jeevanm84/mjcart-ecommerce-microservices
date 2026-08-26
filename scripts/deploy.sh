#!/bin/bash
set -euo pipefail
NAMESPACE="mjcart"
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/mysql-secret.yaml
kubectl apply -f k8s/mysql-configmap.yaml
kubectl apply -f k8s/mysql.yaml
kubectl apply -f k8s/redis.yaml
kubectl rollout status statefulset/mysql -n $NAMESPACE --timeout=180s
kubectl apply -f k8s/backend.yaml
kubectl apply -f k8s/frontend.yaml
kubectl apply -f k8s/ingress.yaml
echo ">>> Optional: apply k8s/hpa.yaml and k8s/monitoring-optional.yaml once metrics-server / Prometheus Operator are installed"
kubectl get pods -n $NAMESPACE
kubectl get svc -n $NAMESPACE
kubectl get ingress -n $NAMESPACE
