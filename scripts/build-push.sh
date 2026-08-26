#!/bin/bash
set -euo pipefail
DOCKER_USER="${DOCKER_USER:-jeevanm84}"
IMAGE_TAG="${IMAGE_TAG:-v1}"
SERVICES=(api-gateway auth-service user-service product-service inventory-service cart-service order-service shipping-service notification-service review-service)
for svc in "${SERVICES[@]}"; do
  echo "Building $svc"
  docker build --no-cache -t "$DOCKER_USER/mjcart-$svc:$IMAGE_TAG" "services/$svc"
  docker push "$DOCKER_USER/mjcart-$svc:$IMAGE_TAG"
done
echo "Building frontend"
docker build --no-cache -t "$DOCKER_USER/mjcart-frontend:$IMAGE_TAG" frontend
docker push "$DOCKER_USER/mjcart-frontend:$IMAGE_TAG"
