SHELL := /bin/bash
.DEFAULT_GOAL := help

.PHONY: help check run stop logs clean

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: ## Validate the repo foundation scaffold
	@test -f README.md
	@test -f .env.example
	@test -f docker-compose.yml
	@test -f .github/workflows/ci.yml
	@test -d services/ingestor
	@test -d services/writer
	@test -d infra/local
	@test -d infra/cloud
	@test -d apps/streamlit
	@test -d docs/design
	@test -d docs/runbooks
	@test -f docs/design/Project_Phase_2_Group4_Report_Detailed_Design.pdf
	@test -f docs/design/Smart_City_Architecture_Group4_Final.html
	@echo "Foundation check passed."

run: ## Start the local Docker Compose stack
	docker compose up

stop: ## Stop the local Docker Compose stack
	docker compose down

logs: ## Follow local Docker Compose logs
	docker compose logs -f

clean: ## Stop local services and remove local Compose volumes
	docker compose down -v --remove-orphans
