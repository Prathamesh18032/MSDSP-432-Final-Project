SHELL := /bin/bash
.DEFAULT_GOAL := help
GO_TEST_ENV := GOCACHE="$(CURDIR)/.cache/go-build"
IMAGE_REGISTRY ?= asia-south1-docker.pkg.dev/replace-me-project/smartcity
IMAGE_TAG ?= local
INGESTOR_IMAGE = $(IMAGE_REGISTRY)/smartcity-ingestor:$(IMAGE_TAG)
WRITER_IMAGE = $(IMAGE_REGISTRY)/smartcity-writer:$(IMAGE_TAG)
STREAMLIT_IMAGE = $(IMAGE_REGISTRY)/smartcity-streamlit:$(IMAGE_TAG)

ifneq (,$(wildcard .env))
include .env
export
endif

TFVARS_GCS_BUCKET := $(shell awk -F= '/^[[:space:]]*gcs_bucket[[:space:]]*=/ {gsub(/[ "	]/, "", $$2); print $$2}' infra/cloud/terraform/terraform.tfvars 2>/dev/null)
CLOUD_COLD_BUCKET ?= $(if $(TFVARS_GCS_BUCKET),$(TFVARS_GCS_BUCKET),$(GCS_BUCKET))

.PHONY: help check test streamlit-check cloud-check gcp-bootstrap-check gcp-cost-guard-check artifact-registry-preview artifact-registry-check artifact-registry-create artifact-registry-list terraform-check terraform-init terraform-validate terraform-plan terraform-show-plan terraform-import-artifact-registry-preview terraform-import-artifact-registry terraform-apply-core gcp-core-check pubsub-check bigquery-cold-check docker-build docker-build-ingestor docker-build-writer docker-build-streamlit docker-smoke docker-tag-release docker-push run run-local seed-simulator run-openaq run-multisource poll-multisource-once consume-pubsub consume-pubsub-once pubsub-smoke pubsub-hotpath-smoke export-cold export-cold-demo export-cold-gcs cloud-cold-smoke run-streamlit run-streamlit-compose stop logs clean

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
	@test -f services/ingestor/cmd/poll-multisource/main.go
	@test -f services/ingestor/Dockerfile
	@test -f internal/buffer/queue.go
	@test -f internal/cloudpubsub/publisher.go
	@test -f internal/cloudpubsub/consumer.go
	@test -f internal/coldstore/parquet.go
	@test -f services/writer/cmd/export-cold/main.go
	@test -f services/writer/cmd/consume-pubsub/main.go
	@test -f services/writer/Dockerfile
	@test -f apps/streamlit/app.py
	@test -f apps/streamlit/requirements.txt
	@test -f apps/streamlit/Dockerfile
	@echo "Foundation check passed."

test: ## Run Go tests
	$(GO_TEST_ENV) go test ./...

streamlit-check: ## Run lightweight Streamlit app syntax checks
	python3 -m py_compile apps/streamlit/app.py apps/streamlit/smartcity/*.py

cloud-check: ## Validate cloud-readiness scaffold without contacting GCP
	@test -f infra/cloud/README.md
	@test -f docs/runbooks/gcp-readiness.md
	@test -f infra/cloud/terraform/README.md
	@test -f infra/cloud/terraform/versions.tf
	@test -f infra/cloud/terraform/variables.tf
	@test -f infra/cloud/terraform/main.tf
	@test -f infra/cloud/terraform/outputs.tf
	@test -f infra/cloud/terraform/terraform.tfvars.example
	@test -f infra/cloud/k8s/README.md
	@test -f infra/cloud/k8s/base/namespace.yaml
	@test -f infra/cloud/k8s/base/serviceaccounts.yaml
	@test -f infra/cloud/k8s/base/configmap.yaml
	@test -f infra/cloud/k8s/base/workloads.yaml
	@test -f infra/cloud/gcp.env.example
	@test -f docs/runbooks/gcp-console-bootstrap.md
	@test -x infra/cloud/scripts/gcp_bootstrap_check.sh
	@test -x infra/cloud/scripts/gcp_cost_guard_check.sh
	@test -x infra/cloud/scripts/artifact_registry_preview.sh
	@test -x infra/cloud/scripts/artifact_registry_check.sh
	@test -x infra/cloud/scripts/artifact_registry_create.sh
	@test -x infra/cloud/scripts/artifact_registry_list.sh
	@test -x infra/cloud/scripts/docker_tag_release.sh
	@test -x infra/cloud/scripts/docker_push.sh
	@test -x infra/cloud/scripts/terraform_check.sh
	@test -x infra/cloud/scripts/terraform_init.sh
	@test -x infra/cloud/scripts/terraform_validate.sh
	@test -x infra/cloud/scripts/terraform_plan.sh
	@test -x infra/cloud/scripts/terraform_show_plan.sh
	@test -x infra/cloud/scripts/terraform_import_artifact_registry_preview.sh
	@test -x infra/cloud/scripts/terraform_import_artifact_registry.sh
	@test -x infra/cloud/scripts/terraform_apply_core.sh
	@test -x infra/cloud/scripts/gcp_core_check.sh
	@test -x infra/cloud/scripts/pubsub_check.sh
	@test -x infra/cloud/scripts/bigquery_cold_check.sh
	@test -f docs/runbooks/artifact-registry-publish.md
	@test -f docs/runbooks/terraform-plan-review.md
	@test -f docs/runbooks/pubsub-adapter-readiness.md
	@test -f docs/runbooks/core-cloud-apply.md
	@test -f docs/runbooks/cloud-cold-path.md
	@for file in $$(find infra/cloud/k8s -name '*.yaml' -type f); do grep -q '^apiVersion:' "$$file"; grep -q '^kind:' "$$file"; done
	@if command -v terraform >/dev/null 2>&1; then terraform fmt -check -recursive infra/cloud/terraform; else echo "terraform not installed; skipping terraform fmt"; fi
	@if command -v kubectl >/dev/null 2>&1; then kubectl version --client=true >/dev/null; echo "kubectl installed; cluster dry-run intentionally skipped"; else echo "kubectl not installed; skipping kubernetes client check"; fi
	@! grep -R "smartcity_dev_password\|smartcity_meta_dev_password" infra/cloud >/dev/null
	@echo "Cloud readiness check passed."

gcp-bootstrap-check: ## Verify local gcloud/project/region/image settings without creating GCP resources
	infra/cloud/scripts/gcp_bootstrap_check.sh

gcp-cost-guard-check: ## Verify local project/region/budget guard values without billing API calls
	infra/cloud/scripts/gcp_cost_guard_check.sh

artifact-registry-preview: ## Print future Artifact Registry setup and push commands without executing them
	infra/cloud/scripts/artifact_registry_preview.sh

artifact-registry-check: ## Verify Artifact Registry API, repository, and Docker auth are ready
	infra/cloud/scripts/artifact_registry_check.sh

artifact-registry-create: ## Enable Artifact Registry, create the Docker repository if missing, and configure Docker auth
	infra/cloud/scripts/artifact_registry_create.sh

artifact-registry-list: ## List published Artifact Registry images for the configured repository
	infra/cloud/scripts/artifact_registry_list.sh

terraform-check: ## Check Terraform CLI and local tfvars readiness without contacting GCP
	infra/cloud/scripts/terraform_check.sh

terraform-init: ## Initialize Terraform providers locally without applying resources
	infra/cloud/scripts/terraform_init.sh

terraform-validate: ## Validate Terraform configuration after init
	infra/cloud/scripts/terraform_validate.sh

terraform-plan: ## Create a local Terraform plan artifact without applying resources
	infra/cloud/scripts/terraform_plan.sh

terraform-show-plan: ## Show the saved local Terraform plan artifact
	infra/cloud/scripts/terraform_show_plan.sh

terraform-import-artifact-registry-preview: ## Print the import command for the Slice 12 Artifact Registry repository
	infra/cloud/scripts/terraform_import_artifact_registry_preview.sh

terraform-import-artifact-registry: ## Import the existing Artifact Registry repository into local Terraform state
	infra/cloud/scripts/terraform_import_artifact_registry.sh

terraform-apply-core: ## Apply low-cost core GCP resources with ALLOW_TERRAFORM_APPLY_CORE=yes
	infra/cloud/scripts/terraform_apply_core.sh

gcp-core-check: ## Verify core GCP resources after controlled Terraform apply
	infra/cloud/scripts/gcp_core_check.sh

pubsub-check: ## Verify existing Pub/Sub topic/subscription readiness without creating resources
	infra/cloud/scripts/pubsub_check.sh

bigquery-cold-check: ## Verify the GCS-backed BigQuery external table is queryable
	infra/cloud/scripts/bigquery_cold_check.sh

docker-build: docker-build-ingestor docker-build-writer docker-build-streamlit ## Build all application container images locally

docker-build-ingestor: ## Build the multi-source ingestor image locally
	docker build -f services/ingestor/Dockerfile -t $(INGESTOR_IMAGE) .

docker-build-writer: ## Build the cold export writer image locally
	docker build -f services/writer/Dockerfile -t $(WRITER_IMAGE) .

docker-build-streamlit: ## Build the Streamlit reports image locally
	docker build -f apps/streamlit/Dockerfile -t $(STREAMLIT_IMAGE) .

docker-smoke: ## Smoke-test locally built images without pushing or contacting GCP
	@docker image inspect $(INGESTOR_IMAGE) >/dev/null
	@docker image inspect $(WRITER_IMAGE) >/dev/null
	@docker image inspect $(STREAMLIT_IMAGE) >/dev/null
	@docker run --rm $(INGESTOR_IMAGE) -once 2>&1 | grep -q "connect to TimescaleDB"
	@docker run --rm $(WRITER_IMAGE) 2>&1 | grep -q "connect to TimescaleDB"
	@docker run --rm --entrypoint python $(STREAMLIT_IMAGE) -m py_compile apps/streamlit/app.py apps/streamlit/smartcity/cold_storage.py apps/streamlit/smartcity/data_access.py
	@echo "Docker smoke check passed."

docker-tag-release: ## Ensure all local images have the configured Artifact Registry release tag
	infra/cloud/scripts/docker_tag_release.sh

docker-push: ## Push all configured service images to Artifact Registry
	infra/cloud/scripts/docker_push.sh

run: ## Start the local Docker Compose stack
	docker compose up

run-local: ## Start the local stack in the background
	docker compose up -d

seed-simulator: ## Insert deterministic simulator readings into local TimescaleDB
	$(GO_TEST_ENV) go run ./services/writer/cmd/seed-simulator

run-openaq: ## Continuously poll OpenAQ latest readings into local TimescaleDB
	$(GO_TEST_ENV) go run ./services/ingestor/cmd/poll-openaq

run-multisource: ## Continuously poll OpenAQ, Open-Meteo, GBFS, and USGS into local TimescaleDB
	$(GO_TEST_ENV) go run ./services/ingestor/cmd/poll-multisource

poll-multisource-once: ## Poll all configured smart-city sources once for local validation
	$(GO_TEST_ENV) go run ./services/ingestor/cmd/poll-multisource -once

consume-pubsub: ## Consume existing Pub/Sub readings into local TimescaleDB
	$(GO_TEST_ENV) go run ./services/writer/cmd/consume-pubsub

consume-pubsub-once: ## Consume a bounded number of Pub/Sub readings into local TimescaleDB
	PUBSUB_CONSUME_LIMIT=$${PUBSUB_CONSUME_LIMIT:-10} PUBSUB_CONSUME_TIMEOUT_SECONDS=$${PUBSUB_CONSUME_TIMEOUT_SECONDS:-60} $(GO_TEST_ENV) go run ./services/writer/cmd/consume-pubsub

pubsub-smoke: ## Publish one multi-source poll to an existing Pub/Sub topic
	INGESTION_SINK=pubsub $(GO_TEST_ENV) go run ./services/ingestor/cmd/poll-multisource -once

pubsub-hotpath-smoke: ## Publish to Pub/Sub, consume into local TimescaleDB, and show inserted row counts
	$(MAKE) pubsub-check
	INGESTION_SINK=pubsub $(GO_TEST_ENV) go run ./services/ingestor/cmd/poll-multisource -once
	PUBSUB_CONSUME_LIMIT=$${PUBSUB_CONSUME_LIMIT:-10} PUBSUB_CONSUME_TIMEOUT_SECONDS=$${PUBSUB_CONSUME_TIMEOUT_SECONDS:-60} $(GO_TEST_ENV) go run ./services/writer/cmd/consume-pubsub
	docker exec smartcity-timescaledb psql -U smartcity -d smartcity_hot -c "SELECT source, COUNT(*) AS readings FROM sensor_readings GROUP BY source ORDER BY source;"

export-cold: ## Export retention-eligible TimescaleDB readings to local Parquet cold storage
	$(GO_TEST_ENV) go run ./services/writer/cmd/export-cold

export-cold-demo: ## Export current local TimescaleDB readings to local Parquet cold storage
	$(GO_TEST_ENV) go run ./services/writer/cmd/export-cold -mode all

export-cold-gcs: ## Export TimescaleDB readings to local Parquet and upload them to GCS
	GCS_BUCKET="$(CLOUD_COLD_BUCKET)" COLD_STORAGE_TARGET=gcs COLD_EXPORT_MODE=$${COLD_EXPORT_MODE:-all} $(GO_TEST_ENV) go run ./services/writer/cmd/export-cold

cloud-cold-smoke: ## Seed local data, export Parquet to GCS, and verify BigQuery sees rows
	$(MAKE) gcp-core-check
	$(MAKE) run-local
	$(MAKE) seed-simulator
	GCS_BUCKET="$(CLOUD_COLD_BUCKET)" COLD_STORAGE_TARGET=gcs COLD_EXPORT_MODE=all $(GO_TEST_ENV) go run ./services/writer/cmd/export-cold
	CLOUD_COLD_MIN_ROWS=$${CLOUD_COLD_MIN_ROWS:-1} $(MAKE) bigquery-cold-check

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
