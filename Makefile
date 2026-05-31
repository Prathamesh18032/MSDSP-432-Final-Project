SHELL := /bin/bash
.DEFAULT_GOAL := help
GO_TEST_ENV := GOCACHE="$(CURDIR)/.cache/go-build"
IMAGE_REGISTRY ?= asia-south1-docker.pkg.dev/replace-me-project/smartcity
IMAGE_TAG ?= local
DOCKER_PLATFORM ?= linux/amd64
INGESTOR_IMAGE = $(IMAGE_REGISTRY)/smartcity-ingestor:$(IMAGE_TAG)
WRITER_IMAGE = $(IMAGE_REGISTRY)/smartcity-writer:$(IMAGE_TAG)
STREAMLIT_IMAGE = $(IMAGE_REGISTRY)/smartcity-streamlit:$(IMAGE_TAG)

ifneq (,$(wildcard .env))
include .env
export
endif

TFVARS_GCS_BUCKET := $(shell awk -F= '/^[[:space:]]*gcs_bucket[[:space:]]*=/ {gsub(/[ "	]/, "", $$2); print $$2}' infra/cloud/terraform/terraform.tfvars 2>/dev/null)
CLOUD_COLD_BUCKET ?= $(if $(TFVARS_GCS_BUCKET),$(TFVARS_GCS_BUCKET),$(GCS_BUCKET))

.PHONY: help check test streamlit-check cloud-check ci-cd-check phase3-check phase3-package phase3-package-list gcp-bootstrap-check gcp-cost-guard-check artifact-registry-preview artifact-registry-check artifact-registry-create artifact-registry-list ci-publish-check terraform-check terraform-init terraform-validate terraform-plan terraform-show-plan terraform-import-artifact-registry-preview terraform-import-artifact-registry terraform-apply-core terraform-plan-runtime terraform-apply-runtime gcp-core-check pubsub-check bigquery-cold-check gke-get-credentials k8s-render k8s-apply k8s-status k8s-smoke k8s-logs k8s-backup-once k8s-backup-check k8s-restore-test k8s-restore-check k8s-restore-clean k8s-port-forward-streamlit public-demo-render public-demo-apply public-demo-status public-demo-url public-demo-smoke public-demo-disable observability-check runtime-check runtime-health runtime-cost-check runtime-scale-down runtime-scale-up runtime-demo-mode runtime-idle-mode runtime-resume-mode runtime-promote-latest runtime-promote-sha runtime-image-check runtime-release-check runtime-cost-report runtime-cost-guard runtime-evidence runtime-live-smoke demo-live-start demo-live-stop docker-build docker-build-ingestor docker-build-writer docker-build-streamlit docker-smoke docker-tag-release docker-push run run-local seed-simulator grafana-demo-ready run-openaq run-multisource poll-multisource-once consume-pubsub consume-pubsub-once pubsub-smoke pubsub-hotpath-smoke export-cold export-cold-demo export-cold-gcs cloud-cold-smoke run-streamlit run-streamlit-compose stop logs clean

help: ## Show available commands
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z0-9_-]+:.*##/ {printf "%-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

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
	@test -f services/writer/cmd/backup-timescale/main.go
	@test -f services/writer/Dockerfile
	@test -f apps/streamlit/app.py
	@test -f apps/streamlit/requirements.txt
	@test -f apps/streamlit/Dockerfile
	@echo "Foundation check passed."

test: ## Run Go tests
	$(GO_TEST_ENV) go test ./...

streamlit-check: ## Run lightweight Streamlit app syntax checks
	python3 -m py_compile apps/streamlit/app.py apps/streamlit/smartcity/*.py

ci-cd-check: ## Validate GitHub Actions image publishing workflow
	infra/cloud/scripts/ci_cd_check.sh

phase3-check: ## Validate final Phase 3 submission files and package safety
	scripts/phase3_check.sh

phase3-package: ## Build dist/Project_Phase_3_Group4.zip from package-safe project files
	scripts/phase3_package.sh

phase3-package-list: ## List contents of the Phase 3 submission zip
	scripts/phase3_package_list.sh

cloud-check: ## Validate cloud-readiness scaffold without contacting GCP
	@test -f infra/cloud/README.md
	@test -f docs/runbooks/gcp-readiness.md
	@test -f infra/cloud/terraform/README.md
	@test -f infra/cloud/terraform/versions.tf
	@test -f infra/cloud/terraform/variables.tf
	@test -f infra/cloud/terraform/main.tf
	@test -f infra/cloud/terraform/outputs.tf
	@test -f infra/cloud/terraform/terraform.tfvars.example
	@test -f .github/workflows/publish-images.yml
	@test -f .github/workflows/promote-runtime.yml
	@test -f infra/cloud/k8s/README.md
	@test -f infra/cloud/k8s/base/namespace.yaml
	@test -f infra/cloud/k8s/base/serviceaccounts.yaml
	@test -f infra/cloud/k8s/base/configmap.yaml
	@test -f infra/cloud/k8s/base/workloads.yaml
	@test -f infra/cloud/k8s/base/public-demo-http.yaml
	@test -f infra/cloud/k8s/base/public-demo-https.yaml
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
	@test -x infra/cloud/scripts/terraform_plan_runtime.sh
	@test -x infra/cloud/scripts/terraform_apply_runtime.sh
	@test -x infra/cloud/scripts/gke_get_credentials.sh
	@test -x infra/cloud/scripts/gcp_core_check.sh
	@test -x infra/cloud/scripts/pubsub_check.sh
	@test -x infra/cloud/scripts/bigquery_cold_check.sh
	@test -x infra/cloud/scripts/k8s_render.sh
	@test -x infra/cloud/scripts/k8s_apply.sh
	@test -x infra/cloud/scripts/k8s_status.sh
	@test -x infra/cloud/scripts/k8s_smoke.sh
	@test -x infra/cloud/scripts/k8s_logs.sh
	@test -x infra/cloud/scripts/k8s_backup_once.sh
	@test -x infra/cloud/scripts/k8s_backup_check.sh
	@test -x infra/cloud/scripts/k8s_restore_test.sh
	@test -x infra/cloud/scripts/k8s_restore_check.sh
	@test -x infra/cloud/scripts/k8s_restore_clean.sh
	@test -x infra/cloud/scripts/k8s_port_forward_streamlit.sh
	@test -x infra/cloud/scripts/public_demo_render.sh
	@test -x infra/cloud/scripts/public_demo_apply.sh
	@test -x infra/cloud/scripts/public_demo_status.sh
	@test -x infra/cloud/scripts/public_demo_url.sh
	@test -x infra/cloud/scripts/public_demo_smoke.sh
	@test -x infra/cloud/scripts/public_demo_disable.sh
	@test -x infra/cloud/scripts/observability_check.sh
	@test -x infra/cloud/scripts/runtime_check.sh
	@test -x infra/cloud/scripts/runtime_health.sh
	@test -x infra/cloud/scripts/runtime_cost_check.sh
	@test -x infra/cloud/scripts/runtime_scale_down.sh
	@test -x infra/cloud/scripts/runtime_scale_up.sh
	@test -x infra/cloud/scripts/runtime_demo_mode.sh
	@test -x infra/cloud/scripts/runtime_idle_mode.sh
	@test -x infra/cloud/scripts/runtime_resume_mode.sh
	@test -x infra/cloud/scripts/runtime_promote_latest.sh
	@test -x infra/cloud/scripts/runtime_promote_sha.sh
	@test -x infra/cloud/scripts/runtime_release_check.sh
	@test -x infra/cloud/scripts/runtime_cost_report.sh
	@test -x infra/cloud/scripts/runtime_cost_guard.sh
	@test -x infra/cloud/scripts/runtime_evidence.sh
	@test -x infra/cloud/scripts/runtime_live_smoke.sh
	@test -x infra/cloud/scripts/demo_live_start.sh
	@test -x infra/cloud/scripts/demo_live_stop.sh
	@test -x infra/cloud/scripts/ci_cd_check.sh
	@test -x infra/cloud/scripts/ci_publish_check.sh
	@test -f docs/runbooks/artifact-registry-publish.md
	@test -f docs/runbooks/terraform-plan-review.md
	@test -f docs/runbooks/pubsub-adapter-readiness.md
	@test -f docs/runbooks/core-cloud-apply.md
	@test -f docs/runbooks/cloud-cold-path.md
	@test -f docs/runbooks/gke-runtime.md
	@test -f docs/runbooks/cloud-operations.md
	@test -f docs/runbooks/live-demo.md
	@test -f docs/runbooks/public-demo.md
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

ci-publish-check: ## Verify main-branch images are published with latest-main and short SHA tags
	infra/cloud/scripts/ci_publish_check.sh

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

terraform-plan-runtime: ## Create a gated runtime Terraform plan for GKE without applying resources
	infra/cloud/scripts/terraform_plan_runtime.sh

terraform-apply-runtime: ## Apply runtime GKE resources with ALLOW_TERRAFORM_APPLY_RUNTIME=yes
	infra/cloud/scripts/terraform_apply_runtime.sh

gcp-core-check: ## Verify core GCP resources after controlled Terraform apply
	infra/cloud/scripts/gcp_core_check.sh

pubsub-check: ## Verify existing Pub/Sub topic/subscription readiness without creating resources
	infra/cloud/scripts/pubsub_check.sh

bigquery-cold-check: ## Verify the GCS-backed BigQuery external table is queryable
	infra/cloud/scripts/bigquery_cold_check.sh

gke-get-credentials: ## Configure kubectl for the configured GKE runtime cluster
	infra/cloud/scripts/gke_get_credentials.sh

k8s-render: ## Render Kubernetes runtime manifests with local project/image values
	infra/cloud/scripts/k8s_render.sh

k8s-apply: ## Apply rendered Kubernetes runtime manifests and create runtime secrets when env is set
	infra/cloud/scripts/k8s_apply.sh

k8s-status: ## Show Kubernetes runtime workload status
	infra/cloud/scripts/k8s_status.sh

k8s-smoke: ## Validate GKE runtime pods and internal TimescaleDB readiness
	infra/cloud/scripts/k8s_smoke.sh

k8s-logs: ## Show recent GKE runtime logs
	infra/cloud/scripts/k8s_logs.sh

k8s-backup-once: ## Trigger one TimescaleDB backup job in GKE
	infra/cloud/scripts/k8s_backup_once.sh

k8s-backup-check: ## Verify at least one TimescaleDB backup exists in GCS
	infra/cloud/scripts/k8s_backup_check.sh

k8s-restore-test: ## Restore the latest GCS backup into a disposable TimescaleDB namespace
	infra/cloud/scripts/k8s_restore_test.sh

k8s-restore-check: ## Validate the disposable restore-test database
	infra/cloud/scripts/k8s_restore_check.sh

k8s-restore-clean: ## Delete the disposable restore-test namespace
	infra/cloud/scripts/k8s_restore_clean.sh

k8s-port-forward-streamlit: ## Port-forward Streamlit from the GKE runtime namespace
	infra/cloud/scripts/k8s_port_forward_streamlit.sh

public-demo-render: ## Render public Streamlit demo ingress manifests with ALLOW_PUBLIC_INGRESS=yes
	infra/cloud/scripts/public_demo_render.sh

public-demo-apply: ## Create/update the guarded public Streamlit demo ingress
	infra/cloud/scripts/public_demo_apply.sh

public-demo-status: ## Show public demo ingress, certificate, backend, and static IP status
	infra/cloud/scripts/public_demo_status.sh

public-demo-url: ## Print the current public demo URL when the ingress is ready
	infra/cloud/scripts/public_demo_url.sh

public-demo-smoke: ## Smoke-test the public Streamlit demo health endpoint
	infra/cloud/scripts/public_demo_smoke.sh

public-demo-disable: ## Disable the public Streamlit demo ingress
	infra/cloud/scripts/public_demo_disable.sh

observability-check: ## Validate cloud runtime health, logs, Pub/Sub, GCS, and BigQuery visibility
	infra/cloud/scripts/observability_check.sh

runtime-check: ## Validate runtime prerequisites and render manifests without applying them
	infra/cloud/scripts/runtime_check.sh

runtime-health: ## Run extended live runtime health checks
	infra/cloud/scripts/runtime_health.sh

runtime-cost-check: ## Show cost-sensitive runtime resources and storage usage
	infra/cloud/scripts/runtime_cost_check.sh

runtime-scale-down: ## Scale optional runtime deployments to zero while keeping TimescaleDB/PVC intact
	infra/cloud/scripts/runtime_scale_down.sh

runtime-scale-up: ## Scale optional runtime deployments back to one replica
	infra/cloud/scripts/runtime_scale_up.sh

runtime-demo-mode: ## Resume runtime workloads and CronJobs for a live demo window
	infra/cloud/scripts/runtime_demo_mode.sh

runtime-idle-mode: ## Disable public ingress, suspend CronJobs, and scale optional workloads down
	infra/cloud/scripts/runtime_idle_mode.sh

runtime-resume-mode: ## Bring the runtime back from idle mode and validate health
	infra/cloud/scripts/runtime_resume_mode.sh

runtime-promote-latest: ## Promote latest-main images to the GKE runtime
	infra/cloud/scripts/runtime_promote_latest.sh

runtime-promote-sha: ## Promote a specific CI-published image tag with IMAGE_TAG=<short-sha>
	infra/cloud/scripts/runtime_promote_sha.sh

runtime-image-check: ## Verify selected runtime image tag exists in Artifact Registry
	infra/cloud/scripts/runtime_image_check.sh

runtime-release-check: ## Verify deployed runtime image tags match RUNTIME_EXPECTED_IMAGE_TAG
	infra/cloud/scripts/runtime_release_check.sh

runtime-cost-report: ## Summarize active cloud resources and public demo cost posture
	infra/cloud/scripts/runtime_cost_report.sh

runtime-cost-guard: ## Fail when active runtime/public demo cost is not acknowledged
	infra/cloud/scripts/runtime_cost_guard.sh

runtime-evidence: ## Capture sanitized runtime evidence output under artifacts/evidence
	infra/cloud/scripts/runtime_evidence.sh

runtime-live-smoke: ## Publish one batch and verify the GKE Pub/Sub writer inserts into TimescaleDB
	infra/cloud/scripts/runtime_live_smoke.sh

demo-live-start: ## Run live demo checks and print Streamlit port-forward instructions
	infra/cloud/scripts/demo_live_start.sh

demo-live-stop: ## Scale down optional demo workloads and print cleanup guidance
	infra/cloud/scripts/demo_live_stop.sh

docker-build: docker-build-ingestor docker-build-writer docker-build-streamlit ## Build all application container images locally

docker-build-ingestor: ## Build the multi-source ingestor image locally
	docker build --platform $(DOCKER_PLATFORM) -f services/ingestor/Dockerfile -t $(INGESTOR_IMAGE) .

docker-build-writer: ## Build the cold export writer image locally
	docker build --platform $(DOCKER_PLATFORM) -f services/writer/Dockerfile -t $(WRITER_IMAGE) .

docker-build-streamlit: ## Build the Streamlit reports image locally
	docker build --platform $(DOCKER_PLATFORM) -f apps/streamlit/Dockerfile -t $(STREAMLIT_IMAGE) .

docker-smoke: ## Smoke-test locally built images without pushing or contacting GCP
	@docker image inspect $(INGESTOR_IMAGE) >/dev/null
	@docker image inspect $(WRITER_IMAGE) >/dev/null
	@docker image inspect $(STREAMLIT_IMAGE) >/dev/null
	@docker run --rm $(INGESTOR_IMAGE) -once 2>&1 | grep -q "connect to TimescaleDB"
	@docker run --rm $(WRITER_IMAGE) 2>&1 | grep -q "connect to TimescaleDB"
	@docker run --rm --entrypoint python $(STREAMLIT_IMAGE) -m py_compile apps/streamlit/app.py apps/streamlit/smartcity/*.py
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

grafana-demo-ready: ## Start local stack and populate Grafana from simulator plus live sources
	$(MAKE) run-local
	$(MAKE) seed-simulator
	$(MAKE) poll-multisource-once
	@echo "Grafana demo data path complete. Open http://localhost:$${GRAFANA_PORT:-3000} and use admin / admin on fresh volumes."

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
