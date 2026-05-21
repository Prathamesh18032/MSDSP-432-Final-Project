SHELL := /bin/bash
.DEFAULT_GOAL := help
GO_TEST_ENV := GOCACHE="$(CURDIR)/.cache/go-build"

ifneq (,$(wildcard .env))
include .env
export
endif

.PHONY: help check test streamlit-check run run-local seed-simulator run-openaq export-cold export-cold-demo run-streamlit run-streamlit-compose stop logs clean

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*##/ {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

check: ## Validate the repo foundation scaffold
	@test -f README.md
	@test -f .env.example
	@test -f docker-compose.yml
	@test -f .github/workflows/ci.yml
	@test -f go.mod
	@test -f docs/PROJECT_TRACKER.md
	@test -d services/ingestor
	@test -d services/writer
	@test -d infra/local
	@test -d infra/cloud
	@test -d apps/streamlit
	@test -d docs/design
	@test -d docs/runbooks
	@test -f docs/design/Project_Phase_2_Group4_Report_Detailed_Design.pdf
	@test -f docs/design/Smart_City_Architecture_Group4_Final.html
	@test -f infra/local/timescaledb/init/001_schema.sql
	@test -f infra/local/grafana/provisioning/datasources/timescaledb.yml
	@test -f infra/local/grafana/provisioning/dashboards/dashboard-provider.yml
	@test -f infra/local/grafana/provisioning/dashboards/smart-city-operations.json
	@test -f services/ingestor/cmd/poll-openaq/main.go
	@test -f internal/buffer/queue.go
	@test -f internal/coldstore/parquet.go
	@test -f services/writer/cmd/export-cold/main.go
	@test -f apps/streamlit/app.py
	@test -f apps/streamlit/requirements.txt
	@echo "Foundation check passed."

test: ## Run Go tests
	$(GO_TEST_ENV) go test ./...

streamlit-check: ## Run lightweight Streamlit app syntax checks
	python3 -m py_compile apps/streamlit/app.py apps/streamlit/smartcity/*.py

run: ## Start the local Docker Compose stack
	docker compose up

run-local: ## Start the local stack in the background
	docker compose up -d

seed-simulator: ## Insert deterministic simulator readings into local TimescaleDB
	$(GO_TEST_ENV) go run ./services/writer/cmd/seed-simulator

run-openaq: ## Continuously poll OpenAQ latest readings into local TimescaleDB
	$(GO_TEST_ENV) go run ./services/ingestor/cmd/poll-openaq

export-cold: ## Export retention-eligible TimescaleDB readings to local Parquet cold storage
	$(GO_TEST_ENV) go run ./services/writer/cmd/export-cold

export-cold-demo: ## Export current local TimescaleDB readings to local Parquet cold storage
	$(GO_TEST_ENV) go run ./services/writer/cmd/export-cold -mode all

run-streamlit: ## Run the Streamlit reports app locally
	python3 -m streamlit run apps/streamlit/app.py --server.port $${STREAMLIT_PORT:-8501} --server.headless true --browser.gatherUsageStats false

run-streamlit-compose: ## Run the Streamlit reports app through Docker Compose
	docker compose --profile analytics up -d --build streamlit

stop: ## Stop the local Docker Compose stack
	docker compose down

logs: ## Follow local Docker Compose logs
	docker compose logs -f

clean: ## Stop local services and remove local Compose volumes
	docker compose down -v --remove-orphans
