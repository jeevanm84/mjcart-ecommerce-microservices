#!/bin/bash
# MJ's Cart - kOps cluster creation
# IMP: use bigger nodes - t3.large (or larger) with 50GB disks. This platform
# runs 10 backend microservices + MySQL + Redis + NGINX Ingress + Prometheus/Grafana
# on top, so undersized nodes will get you CrashLoopBackOff / Pending pods from
# resource pressure, not application bugs.
set -e

: "${KOPS_STATE_STORE:?Set KOPS_STATE_STORE, e.g. export KOPS_STATE_STORE=s3://mjcart-kops-state-<yourid>}"

CLUSTER_NAME="${CLUSTER_NAME:-mjcart.k8s.local}"   # .k8s.local = gossip-based, no Route53 domain needed
ZONES="${ZONES:-ap-south-1a,ap-south-1b}"
NODE_SIZE="${NODE_SIZE:-t3.large}"
MASTER_SIZE="${MASTER_SIZE:-t3.large}"
NODE_COUNT="${NODE_COUNT:-3}"
VOLUME_SIZE="${VOLUME_SIZE:-50}"

echo ">>> Creating kOps state store bucket (idempotent, skips if it already exists)"
STATE_BUCKET=$(echo "$KOPS_STATE_STORE" | sed 's|s3://||')
aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null || aws s3 mb "s3://$STATE_BUCKET"
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled

echo ">>> Creating cluster spec: $CLUSTER_NAME"
kops create cluster \
  --cluster-name="$CLUSTER_NAME" \
  --zones="$ZONES" \
  --node-count="$NODE_COUNT" \
  --node-size="$NODE_SIZE" \
  --master-size="$MASTER_SIZE" \
  --master-count=1 \
  --node-volume-size="$VOLUME_SIZE" \
  --master-volume-size="$VOLUME_SIZE" \
  --networking=calico \
  --iam-role admin

echo ">>> Provisioning cluster on AWS (this takes ~10-15 min)"
kops update cluster --name "$CLUSTER_NAME" --yes

echo ">>> Waiting for cluster to validate"
kops validate cluster --name "$CLUSTER_NAME" --wait 15m

echo ">>> Cluster ready. Checking default StorageClass (needed by k8s/mysql.yaml):"
kubectl get storageclass
echo ">>> If no StorageClass named 'kops-csi-1-21' (or similar) shows as (default),"
echo ">>> edit k8s/mysql.yaml's storageClassName to match what's listed above."
