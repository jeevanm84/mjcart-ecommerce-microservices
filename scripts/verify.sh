#!/bin/bash
set -euo pipefail
NAMESPACE="mjcart"
kubectl get pods -n $NAMESPACE
kubectl get endpoints api-gateway auth-service product-service notification-service -n $NAMESPACE
kubectl logs -n $NAMESPACE deploy/api-gateway --tail=30 || true
kubectl exec -it deploy/redis -n $NAMESPACE -- redis-cli DEL products:list || true
