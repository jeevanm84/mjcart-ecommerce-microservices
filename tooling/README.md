# tooling/

`create-mjcart.sh` is the generator that produces this entire project from
scratch (services, frontend, k8s manifests, docs, CI workflow, kOps scripts).
It's included here for reproducibility / regenerating a clean copy:

```bash
export DOCKER_USER=jeevanm84
export IMAGE_TAG=v1
export NAMESPACE=mjcart
export MYSQL_ROOT_PASSWORD=<your-choice>
export JWT_SECRET=<your-choice>
./create-mjcart.sh
```

It will `rm -rf mjcart-ecommerce-microservices` and regenerate it fresh in
the current directory - run it from one level above this repo if you want
to rebuild from a clean slate.
