# Contributing to MJ's Cart

Thank you for improving the project. Contributions are welcome at every experience level: documentation fixes, tests, accessibility improvements, service features, and infrastructure changes all matter.

## Before you start

1. Search existing issues and pull requests.
2. For a small fix, open a focused pull request directly.
3. For a new service, dependency, architecture change, or breaking API change, open a proposal issue first.
4. Never include credentials, private keys, personal customer data, or cloud account identifiers.

## Local workflow

```bash
git clone https://github.com/jeevanm84/mjcart-ecommerce-microservices.git
cd mjcart-ecommerce-microservices
cp .env.example .env
docker compose up --build -d
./scripts/verify-local.sh
```

Create a descriptive branch:

```bash
git switch -c feat/short-description
```

## Make a good change

- Keep the change scoped to one problem.
- Match existing JavaScript style; prefer clear code over clever abstractions.
- Add or update documentation when commands, configuration, APIs, or behavior change.
- Preserve `/health`, `/ready`, and `/metrics` on backend services.
- Use environment variables for configuration and safe local defaults only.
- Do not commit `.env`, generated output, IDE metadata, or secrets.
- Add verification that would have caught the bug or demonstrates the new behavior.

## Verify before opening a pull request

```bash
node --check services/api-gateway/server.js
npm --prefix frontend ci
npm --prefix frontend run build
docker compose config --quiet
docker compose up --build -d
./scripts/verify-local.sh
```

When a command cannot be run locally, explain why in the pull request.

## Commit and pull-request guidance

Use an imperative, descriptive subject. Conventional prefixes are encouraged but not required:

```text
feat: add order idempotency key
fix: proxy local API requests through nginx
docs: clarify first-time MySQL startup
test: cover inventory reservation failure
```

The pull request should explain:

- what problem it solves;
- what changed;
- how it was verified;
- screenshots for visible UI changes;
- risks, limitations, or follow-up work.

By participating, you agree to follow the [Code of Conduct](CODE_OF_CONDUCT.md).
