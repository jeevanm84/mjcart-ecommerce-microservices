#!/bin/bash
# MJ's Cart - build & push all service images
# Usage: ./build-push.sh <your-registry>   e.g. ./build-push.sh 123456789012.dkr.ecr.ap-south-1.amazonaws.com
set -e

REGISTRY="${1:?Usage: ./build-push.sh <registry, e.g. your-ecr-url or dockerhub-username>}"
TAG="${2:-latest}"

SERVICES=(api-gateway auth-service user-service product-service inventory-service cart-service order-service shipping-service notification-service review-service)

echo ">>> Building frontend"
docker build -t "$REGISTRY/frontend:$TAG" ./frontend
docker push "$REGISTRY/frontend:$TAG"

for svc in "${SERVICES[@]}"; do
  echo ">>> Building $svc"
  docker build -t "$REGISTRY/$svc:$TAG" "./services/$svc"
  docker push "$REGISTRY/$svc:$TAG"
done

echo ">>> All images built and pushed to $REGISTRY with tag $TAG"
echo ">>> Now update the 'image:' field in k8s/*.yaml to match, then: kubectl apply -f k8s/"
