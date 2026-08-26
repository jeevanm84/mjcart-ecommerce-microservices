# MJ's Cart - Runbook

## Local (docker compose / npm)
See main README "Run locally" section.

## kOps cluster
```bash
export KOPS_STATE_STORE=s3://mjcart-kops-state-<yourid>
./scripts/create-kops-cluster.sh
./scripts/build-push.sh
./scripts/deploy.sh
./scripts/verify.sh
```

## Common issues

- **Pods Pending**: nodes undersized. Re-check `NODE_SIZE`/`VOLUME_SIZE` used
  in `create-kops-cluster.sh` - this platform needs `t3.large`+ nodes.
- **MySQL StatefulSet stuck Pending**: check `kubectl get storageclass` - kOps
  doesn't ship a fixed StorageClass name the way EKS does; set
  `storageClassName` in `k8s/mysql.yaml` to whatever is marked `(default)`.
- **502 from api-gateway**: a backend pod isn't ready yet; check
  `kubectl get pods -n mjcart` and `kubectl logs deploy/<service> -n mjcart`.

## Teardown
```bash
./scripts/delete-kops-cluster.sh
```
