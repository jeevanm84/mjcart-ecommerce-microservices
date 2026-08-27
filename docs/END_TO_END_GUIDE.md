# MJ's Cart: complete end-to-end guide

This is the single canonical guide for the project. Follow it in order the first time. It covers:

1. authenticating GitHub as `jeevanm84`;
2. cloning and running the complete application;
3. completing and tracing an order;
4. verifying a change;
5. pushing a branch, opening a pull request, and merging it;
6. improving repository and profile visibility;
7. optionally deploying to Kubernetes with kOps on AWS;
8. safely stopping local and cloud resources.

Sections marked **Optional: AWS deployment** create billable cloud resources. You can complete the entire local and GitHub workflow without AWS.

---

## Phase 1: prepare your computer

### 1.1 Required local tools

Install and start:

- Git;
- Docker Desktop, or Docker Engine with Compose v2;
- GitHub CLI (`gh`);
- `curl`;
- at least 6 GB of memory available to Docker.

Check them:

```bash
git --version
docker --version
docker compose version
gh --version
curl --version
```

If `docker info` fails, start Docker Desktop and wait until it reports that the engine is running.

### 1.2 Authenticate as the correct GitHub account

The repository belongs to **`jeevanm84`**. An account displayed in the IDE does not necessarily control credentials used by terminal Git.

Check the terminal account:

```bash
gh auth status
```

Continue only if it says you are logged into `github.com` as `jeevanm84`. If it shows another account or an invalid token:

```bash
gh auth logout -h github.com -u mamudurijk
gh auth logout -h github.com -u mamuduri-jeevankumar_bsfms
gh auth login -h github.com -p https -w
gh auth setup-git
gh auth status
```

During browser authentication, verify that the browser account is `jeevanm84` before authorizing GitHub CLI.

Expected checkpoint:

```text
Logged in to github.com account jeevanm84
```

Do not push if a different username is displayed.

### 1.3 Configure the commit identity for this repository

Use a repository-local identity so personal work does not use a company email:

```bash
git config user.name "Jeevan Kumar Mamuduri"
git config user.email "97403155+jeevanm84@users.noreply.github.com"
```

Confirm it:

```bash
git config user.name
git config user.email
```

---

## Phase 2: get the project

For a new copy:

```bash
git clone https://github.com/jeevanm84/mjcart-ecommerce-microservices.git
cd mjcart-ecommerce-microservices
```

If the project is already open in IntelliJ, stay in its terminal and verify the repository:

```bash
git remote -v
git status --short --branch
```

The remote must be:

```text
https://github.com/jeevanm84/mjcart-ecommerce-microservices
```

Create local configuration:

```bash
cp .env.example .env
```

The defaults are intended only for local learning. Never commit `.env`.

---

## Phase 3: run the complete platform locally

### 3.1 Build and start

```bash
docker compose up --build -d
```

Or use the shortcut:

```bash
make up
```

The first run downloads images, builds the frontend and ten backend images, starts MySQL and Redis, and initializes sample products and inventory. It may take several minutes.

### 3.2 Watch startup

```bash
docker compose ps
docker compose logs -f mysql api-gateway frontend
```

Wait until MySQL is healthy and the application services are running. Press `Ctrl+C` to stop following logs; containers remain active.

### 3.3 Verify the important paths

```bash
./scripts/verify-local.sh
```

Expected result:

```text
Frontend                OK
API gateway             OK
Product catalog         OK
Inventory               OK

All local smoke checks passed.
```

Open:

- storefront: <http://localhost:3000>;
- gateway health: <http://localhost:8080/health>;
- product API: <http://localhost:3000/api/products>.

---

## Phase 4: complete one end-to-end order

### 4.1 Use the UI

1. Open <http://localhost:3000>.
2. Select **Login**.
3. Enter a name, email, and password, then select **Register**.
4. Open a product and select **Add to Cart**.
5. Open the cart and select **Place Order (COD)**.
6. Open **Orders** and confirm the order appears.

The project intentionally has no payment gateway. Checkout is Cash on Delivery.

### 4.2 Trace the services

In another terminal:

```bash
docker compose logs -f api-gateway order-service inventory-service shipping-service notification-service
```

Place another order and observe this flow:

```text
Browser
  → frontend NGINX
  → API gateway
  → Order Service
      → Inventory Service
      → MySQL order database
      → Shipping Service
      → Notification Service
```

### 4.3 Inspect stored data

```bash
docker compose exec mysql mysql -uroot -prootpass -e 'SELECT * FROM order_db.orders;'
docker compose exec mysql mysql -uroot -prootpass -e 'SELECT * FROM shipping_db.shipments;'
docker compose exec mysql mysql -uroot -prootpass -e 'SELECT * FROM notification_db.notifications;'
```

Review the [API reference](API.md) for every available route and request body.

---

## Phase 5: understand the repository

Read these components in order:

1. `frontend/src/main.jsx` — UI and browser API calls;
2. `frontend/nginx.conf` — local `/api` reverse proxy;
3. `services/api-gateway/server.js` — public-to-internal route mapping;
4. `services/order-service/server.js` — checkout orchestration;
5. `services/inventory-service/server.js` — atomic stock reservation;
6. `database/init.sql` — schema and seed data;
7. `docker-compose.yml` — local topology;
8. `k8s/` — Kubernetes topology.

Then use the [architecture guide](ARCHITECTURE.md) and [learning paths](LEARNING_PATHS.md) to choose beginner, intermediate, or experienced exercises.

---

## Phase 6: make and verify a change

### 6.1 Create a branch

Do not develop directly on `main`:

```bash
git switch main
git pull --ff-only origin main
git switch -c feat/short-description
```

If Git reports that the branch already exists, switch to it instead:

```bash
git switch feat/short-description
```

### 6.2 Run the project checks

```bash
docker compose config --quiet
```

```bash
for file in services/*/server.js; do
  node --check "$file"
done
```

```bash
npm --prefix frontend ci
npm --prefix frontend run build
```

With the containers running:

```bash
./scripts/verify-local.sh
```

### 6.3 Review and commit

```bash
git status --short
git diff --check
git diff
```

Stage only intended files, then commit:

```bash
git add README.md docs/ .github/ CONTRIBUTING.md CODE_OF_CONDUCT.md SECURITY.md LICENSE
git add .env.example .gitignore Makefile docker-compose.yml frontend/ scripts/verify-local.sh
git commit -m "docs: professionalize project onboarding and community setup"
```

If the working tree says `nothing to commit, working tree clean`, the change has already been committed. Confirm with:

```bash
git log -1 --oneline --decorate
```

---

## Phase 7: push, open a pull request, and merge

### 7.1 Safety check before pushing

```bash
gh auth status
git remote get-url origin
git status --short --branch
```

Proceed only when:

- the authenticated account is `jeevanm84`;
- the remote contains `jeevanm84/mjcart-ecommerce-microservices`;
- you are on the intended feature branch.

### 7.2 Push the branch

For the existing professionalization branch:

```bash
git push -u origin docs/professionalize-project
```

This pushes only to `jeevanm84/mjcart-ecommerce-microservices`. It does not merge anything.

### 7.3 Create the pull request

```bash
gh pr create \
  --base main \
  --head docs/professionalize-project \
  --title "docs: professionalize project onboarding and community setup" \
  --fill
```

Alternatively, open <https://github.com/jeevanm84/mjcart-ecommerce-microservices/pulls> and select **New pull request**.

### 7.4 Review CI and merge

```bash
gh pr checks --watch
gh pr view --web
```

Confirm that CI is green and review the changed files. Then merge on GitHub, preferably with **Squash and merge** for this focused change.

After merging:

```bash
git switch main
git pull --ff-only origin main
git branch -d docs/professionalize-project
```

Deleting the local feature branch is optional and happens only after the pull request is merged.

---

## Phase 8: make the GitHub repository easier to discover

Open the repository's **About** settings and use:

**Description**

```text
Learning-first e-commerce microservices platform with React, Node.js, MySQL, Redis, Docker Compose, Kubernetes (kOps), and Prometheus.
```

**Topics**

```text
microservices ecommerce nodejs react docker docker-compose kubernetes kops mysql redis api-gateway prometheus devops aws learning-project system-design
```

Then:

1. enable Issues;
2. enable Discussions only if you can moderate it;
3. upload a clear repository social-preview image;
4. create beginner issues and label them `good first issue`;
5. create a `v1.0.0` release after the improved `main` branch is stable;
6. pin MJ's Cart on the `jeevanm84` profile.

### Create the profile README

Create a new public GitHub repository named exactly:

```text
jeevanm84
```

Copy [the prepared profile README](profile/README.md) into that repository as its root `README.md`. Also set these profile fields:

- **Name:** Jeevan Kumar Mamuduri
- **Bio:** Cloud & DevOps engineer building practical AWS, Kubernetes, and microservices learning projects.

Follow the complete [visibility playbook](GITHUB_VISIBILITY.md) for the launch checklist and four-week publishing plan.

---

## Phase 9: optional AWS deployment with kOps

> [!WARNING]
> This phase creates AWS infrastructure, including EC2 instances, storage, networking, and load balancers. It can incur charges. Use a learning account with budgets and alerts, and complete the teardown section when finished.

### 9.1 Additional tools and access

You need:

- an AWS account and configured AWS CLI;
- kOps;
- `kubectl`;
- Helm;
- Docker Hub access for the images;
- permissions to create the required AWS resources.

Verify identities before creating anything:

```bash
aws sts get-caller-identity
docker login
kubectl version --client
kops version
helm version
```

### 9.2 Configure unique values

```bash
export KOPS_STATE_STORE=s3://mjcart-kops-state-your-unique-suffix
export CLUSTER_NAME=mjcart.k8s.local
export DOCKER_USER=jeevanm84
export IMAGE_TAG=v1
```

Replace `your-unique-suffix`. S3 bucket names are globally unique.

### 9.3 Replace example secrets

Before deployment, edit `k8s/mysql-secret.yaml` and replace every `ChangeMe` or `change-me` value with a strong value. Do not commit real secrets. For a serious environment, use an external secrets manager rather than a checked-in Kubernetes Secret manifest.

### 9.4 Create the cluster

The defaults use three `t3.large` worker nodes plus a `t3.large` control plane in `ap-south-1`. Review the cost and sizes before continuing.

```bash
./scripts/create-kops-cluster.sh
```

### 9.5 Build and publish images

```bash
./scripts/build-push.sh
```

If `DOCKER_USER` or `IMAGE_TAG` differs from the values currently written in `k8s/backend.yaml` and `k8s/frontend.yaml`, update those manifests before deployment.

### 9.6 Install NGINX Ingress

```bash
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace
```

### 9.7 Deploy and verify

```bash
./scripts/deploy.sh
./scripts/verify.sh
kubectl get pods,svc,ingress -n mjcart
```

Optional Prometheus and Grafana installation is described in [the runbook](RUNBOOK.md).

---

## Phase 10: stop resources safely

### Local environment

Stop containers but keep MySQL data:

```bash
docker compose down
```

Delete the local MySQL volume and all demo data:

```bash
docker compose down --volumes
```

### AWS/kOps environment

Ensure the same state-store and cluster variables are set:

```bash
export KOPS_STATE_STORE=s3://mjcart-kops-state-your-unique-suffix
export CLUSTER_NAME=mjcart.k8s.local
```

Then delete workloads and the cluster:

```bash
./scripts/delete-kops-cluster.sh
```

The script intentionally does not delete the S3 state-store bucket. Confirm that EC2 instances, load balancers, and volumes are gone in AWS, then decide whether to retain or separately delete the state bucket.

---

## Final completion checklist

- [ ] `gh auth status` shows `jeevanm84`.
- [ ] Docker is running.
- [ ] `docker compose up --build -d` succeeds.
- [ ] `./scripts/verify-local.sh` passes.
- [ ] A user can register, add a product, and place a COD order.
- [ ] Frontend build and backend syntax checks pass.
- [ ] The feature branch is pushed to the correct repository.
- [ ] CI passes on the pull request.
- [ ] The pull request is reviewed and merged into `main`.
- [ ] Repository description, topics, social preview, and pinned status are configured.
- [ ] The `jeevanm84` profile README is published.
- [ ] Any optional AWS resources are verified or deleted after use.

When this checklist is complete, the project has a reproducible local path, a professional contribution workflow, a clear public presentation, and a documented cloud deployment path.
