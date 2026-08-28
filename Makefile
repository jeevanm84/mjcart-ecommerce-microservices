.DEFAULT_GOAL := help

.PHONY: help setup up down logs status verify build clean

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*## "; printf "MJ cart commands:\n\n"} /^[a-zA-Z_-]+:.*## / {printf "  %-12s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

setup: ## Create a local .env file if it does not exist
	@test -f .env || cp .env.example .env

up: ## Build and start the complete local platform
	docker compose up --build -d

down: ## Stop the local platform without deleting data
	docker compose down

logs: ## Follow logs from every container
	docker compose logs -f --tail=100

status: ## Show container status
	docker compose ps

verify: ## Run the local smoke checks
	./scripts/verify-local.sh

build: ## Build the frontend for production
	npm --prefix frontend ci
	npm --prefix frontend run build

clean: ## Stop containers and delete local database data
	docker compose down --volumes
