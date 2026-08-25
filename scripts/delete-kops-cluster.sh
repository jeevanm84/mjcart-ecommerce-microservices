#!/bin/bash
# Tear down the kOps cluster and its AWS resources (nodes, ELBs, etc).
# Does NOT delete the S3 state store bucket itself.
set -e
: "${KOPS_STATE_STORE:?Set KOPS_STATE_STORE first}"
CLUSTER_NAME="${CLUSTER_NAME:-mjcart.k8s.local}"

echo ">>> Deleting Kubernetes workloads first (releases ELBs/EBS volumes cleanly)"
kubectl delete namespace mjcart --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace ingress-nginx --ignore-not-found

echo ">>> Deleting kOps cluster: $CLUSTER_NAME"
kops delete cluster --name "$CLUSTER_NAME" --yes
