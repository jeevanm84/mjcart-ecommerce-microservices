#!/bin/bash
# MJ's Cart - kOps cluster creation.
# IMP: use bigger nodes (t3.large or larger) with 50GB disks - this platform
# runs 10 backend microservices + MySQL + Redis + NGINX Ingress + Prometheus/Grafana
# on top, so undersized nodes will show Pending/CrashLoopBackOff from resource
# pressure, not application bugs.
set -euo pipefail

: "${KOPS_STATE_STORE:?Set KOPS_STATE_STORE, e.g. export KOPS_STATE_STORE=s3://mjcart-kops-state-<yourid>}"

CLUSTER_NAME="${CLUSTER_NAME:-mjcart.k8s.local}"   # .k8s.local = gossip-based, no Route53 domain needed
ZONES="${ZONES:-ap-south-1a,ap-south-1b}"
NODE_SIZE="${NODE_SIZE:-t3.large}"
MASTER_SIZE="${MASTER_SIZE:-t3.large}"
NODE_COUNT="${NODE_COUNT:-3}"
VOLUME_SIZE="${VOLUME_SIZE:-50}"

echo ">>> Ensuring kOps state store bucket exists"
STATE_BUCKET=$(echo "$KOPS_STATE_STORE" | sed 's|s3://||')
aws s3api head-bucket --bucket "$STATE_BUCKET" 2>/dev/null || aws s3 mb "s3://$STATE_BUCKET"
aws s3api put-bucket-versioning --bucket "$STATE_BUCKET" --versioning-configuration Status=Enabled

echo ">>> Creating cluster spec: $CLUSTER_NAME"
# NOTE: --master-size/--master-count/--master-volume-size and --iam-role were
# removed/renamed in modern kOps (1.25+). Current kOps uses --control-plane-*
# and has no --iam-role flag at all (IAM is handled automatically per
# instance group). Using the current flag names below so this actually runs.
kops create cluster \
  --name="$CLUSTER_NAME" \
  --zones="$ZONES" \
  --node-count="$NODE_COUNT" \
  --node-size="$NODE_SIZE" \
  --control-plane-size="$MASTER_SIZE" \
  --control-plane-count=1 \
  --node-volume-size="$VOLUME_SIZE" \
  --control-plane-volume-size="$VOLUME_SIZE" \
  --networking=calico

echo ">>> Provisioning cluster on AWS (~10-15 min)"
kops update cluster --name "$CLUSTER_NAME" --yes

echo ">>> Waiting for cluster to validate"
kops validate cluster --name "$CLUSTER_NAME" --wait 15m

echo ">>> Cluster ready. Default StorageClass (needed by k8s/mysql.yaml PVC):"
kubectl get storageclass
