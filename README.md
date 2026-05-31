# MSDSP-432-Final-Project

Smart City Zero-Disk IoT Infrastructure for MSDS 432 Foundations of Data Engineering.

Author: Prathamesh  
Team: Group 4  
Status: Local-first MVP in progress. See [Project Tracker](docs/PROJECT_TRACKER.md) for current slice status and next steps.

## Project Direction

This project implements the Phase 2 detailed design as a local-first, cloud-ready data engineering platform:

1. Ingest smart city sensor data with Go services.
2. Validate, normalize, and buffer readings before storage.
3. Store recent hot data in TimescaleDB.
4. Prepare cold storage through Parquet files and GCS-compatible partitioning.
5. Visualize real-time and historical insights through Grafana and a public-demo-ready Streamlit command center.

The first implementation milestone is intentionally small: establish the repository structure and local developer workflow before building application logic.

## Repository Layout

```text
apps/streamlit/        Enterprise Streamlit command center for reviewer/client reporting
docs/design/           Phase 2 PDF report and architecture diagram
docs/final/            Phase 3 final submission guide and presentation artifacts
docs/runbooks/         Setup, operations, and deployment notes
infra/cloud/           Terraform and Kubernetes cloud-readiness placeholder
infra/local/           Docker Compose and local service configuration placeholder
services/ingestor/     Go ingestion service placeholder
services/writer/       Go storage writer service placeholder
```

## Local Workflow

Create a local environment file from the template before running services:

```sh
cp .env.example .env
```

Useful commands:

```sh
make help
make check
make test
make cloud-check
make phase3-check
make phase3-package
make phase3-package-list
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
make artifact-registry-create
make artifact-registry-check
make docker-build
make docker-smoke
make docker-tag-release
make docker-push
make artifact-registry-list
make terraform-check
make terraform-init
make terraform-validate
make terraform-plan
make terraform-show-plan
make terraform-import-artifact-registry
make terraform-apply-core
make gcp-core-check
make pubsub-check
make bigquery-cold-check
make run-local
make seed-simulator
make grafana-demo-ready
make run-openaq
make poll-multisource-once
make run-multisource
make consume-pubsub
make consume-pubsub-once
make pubsub-smoke
make pubsub-hotpath-smoke
make export-cold-demo
make export-cold-gcs
make cloud-cold-smoke
make runtime-promote-latest
make runtime-release-check
make runtime-demo-mode
make runtime-idle-mode
make runtime-resume-mode
make runtime-cost-report
make runtime-evidence
ALLOW_PUBLIC_INGRESS=yes make public-demo-apply
make public-demo-url
make public-demo-disable
make run-streamlit
make run-streamlit-compose
make run
make stop
```

`make check` validates the foundation scaffold. `make test` runs Go tests. `make streamlit-check` validates the Streamlit Python files. `make cloud-check` validates the cloud-readiness scaffold without contacting GCP. `make ci-cd-check` validates the GitHub Actions image publishing and manual runtime promotion workflows. `make phase3-check` validates final submission docs, presentation artifacts, dashboard JSON, standard checks, Compose config, and package safety. `make phase3-package` creates `dist/Project_Phase_3_Group4.zip`; `make phase3-package-list` prints the zip contents before submission. `make gcp-bootstrap-check`, `make gcp-cost-guard-check`, and `make artifact-registry-preview` prepare a fresh GCP account safely without creating resources. `make artifact-registry-create` is the first live cloud target: it enables Artifact Registry, creates the configured Docker repository if needed, and configures Docker auth for `asia-south1-docker.pkg.dev`. `make artifact-registry-check` verifies that setup, and `make artifact-registry-list` lists published images. `make ci-publish-check` verifies that main-branch images exist with `latest-main` and short-SHA tags. GitHub Actions publishes images on `main`, then the manual `Promote Runtime` workflow or `make runtime-promote-latest` deploys the selected image tag to GKE and verifies runtime health. `make runtime-image-check` verifies a selected runtime image tag exists before promotion. `make docker-build` builds local deployable images for the ingestor, writer, and Streamlit app; `make docker-smoke` verifies those images start cleanly without pushing them. `make docker-tag-release` ensures local images have the configured release tag, and `make docker-push` pushes those images to Artifact Registry. `make pubsub-check` verifies that the configured Pub/Sub topic and subscription already exist; it does not create resources. `make bigquery-cold-check` verifies that the configured BigQuery external table is queryable over GCS cold-storage objects. `make terraform-plan-runtime` creates a guarded GKE Autopilot runtime plan; `ALLOW_TERRAFORM_APPLY_RUNTIME=yes make terraform-apply-runtime` is the explicit live runtime apply gate. `make k8s-render`, `make k8s-apply`, `make k8s-status`, `make k8s-smoke`, `make k8s-logs`, `make k8s-backup-once`, `make k8s-backup-check`, `make k8s-restore-test`, `make k8s-restore-check`, `make runtime-health`, `make runtime-cost-check`, `make runtime-cost-report`, `make runtime-promote-latest`, `make runtime-release-check`, `make runtime-demo-mode`, `make runtime-idle-mode`, `make runtime-resume-mode`, `make demo-live-start`, `make demo-live-stop`, `make observability-check`, `make runtime-live-smoke`, and `make k8s-port-forward-streamlit` operate the self-hosted TimescaleDB runtime after the cluster exists. `ALLOW_PUBLIC_INGRESS=yes make public-demo-apply` exposes only Streamlit through guarded public ingress and requires `STREAMLIT_DEMO_PASSWORD`; `make public-demo-disable` removes the public endpoint after review. `make run-local` starts the local Docker Compose stack in the background, `make seed-simulator` publishes deterministic simulator readings through the local buffer into TimescaleDB once the database is healthy, and `make grafana-demo-ready` runs the accepted local Grafana population path by starting Compose, seeding simulator data, and polling live smart-city sources once. `make run-openaq` starts the continuous OpenAQ v3 poller and requires `OPENAQ_API_KEY`. `make poll-multisource-once` runs one local poll across OpenAQ, Open-Meteo, Divvy GBFS, and USGS; `OPENAQ_API_KEY` is optional in this unified path, so OpenAQ is skipped when the key is missing. `make run-multisource` runs the same source set continuously. `make consume-pubsub` runs the future hot writer that consumes existing Pub/Sub readings into local TimescaleDB. `make pubsub-smoke` publishes one multi-source poll to an existing Pub/Sub topic when `INGESTION_SINK=pubsub` is ready. `make export-cold-demo` exports current TimescaleDB readings to local Parquet files under `data/cold`; `make export-cold-gcs` uploads exported Parquet files to the configured GCS cold bucket; `make cloud-cold-smoke` seeds local data, uploads Parquet to GCS, and validates BigQuery row visibility. `make run-streamlit` starts the local reports app, and `make run-streamlit-compose` starts the Compose Streamlit service.

For the first controlled cloud step, start with the [GCP console bootstrap runbook](docs/runbooks/gcp-console-bootstrap.md), then follow the [Artifact Registry publish runbook](docs/runbooks/artifact-registry-publish.md). Slice 12 only publishes images; it does not create GKE, Pub/Sub, GCS, BigQuery, or run Terraform. For infrastructure planning, use the [Terraform plan review runbook](docs/runbooks/terraform-plan-review.md). For the first cloud hot-path adapter, use the [Pub/Sub adapter readiness runbook](docs/runbooks/pubsub-adapter-readiness.md). For the first controlled Terraform apply, use the [core cloud apply runbook](docs/runbooks/core-cloud-apply.md). For the GCS and BigQuery cold path, use the [cloud cold path runbook](docs/runbooks/cloud-cold-path.md). For the first GKE runtime, use the [GKE runtime runbook](docs/runbooks/gke-runtime.md); it keeps TimescaleDB as the hot store by running it internally on GKE. For runtime health, backups, restore testing, release promotion, and CI/CD image publishing, use the [cloud operations runbook](docs/runbooks/cloud-operations.md). For a shareable Streamlit URL, use the [public demo runbook](docs/runbooks/public-demo.md). For the end-to-end project story, use the [live demo runbook](docs/runbooks/live-demo.md).

After seeding data, open Grafana at [http://localhost:3000](http://localhost:3000) and sign in with the local defaults `admin / admin`. For the reviewer-ready Grafana path, run `make grafana-demo-ready`, then open the `Smart City Enterprise Operations` dashboard. It is provisioned automatically and reads from the local TimescaleDB datasource. If an existing `grafana-data` volume has a changed admin password, Grafana keeps that password until local volumes are reset.

To watch live OpenAQ readings, set `OPENAQ_API_KEY` in `.env`, run `make run-local`, then run `make run-openaq` in a second terminal. Stop the poller with `Ctrl+C`.

To watch broader smart-city telemetry, run `make run-local`, then run `make run-multisource` in a second terminal. This adds live weather from Open-Meteo, bike-share station availability from Divvy GBFS, Chicago River gage height from USGS, and OpenAQ readings when `OPENAQ_API_KEY` is configured.

Simulator, OpenAQ, and multi-source commands use the local queue buffer before writing to TimescaleDB. Queue behavior is controlled by `BACKPRESSURE_CHANNEL_CAPACITY`, `QUEUE_BATCH_SIZE`, and `QUEUE_FLUSH_INTERVAL_MS`.

Local ingestion remains the default with `INGESTION_SINK=local`. To publish producer output to an existing Pub/Sub topic instead, set `INGESTION_SINK=pubsub`, `GCP_PROJECT_ID`, and `GCP_PUBSUB_TOPIC`, then run `make pubsub-smoke` or `make run-multisource`. Use `make consume-pubsub` to drain the configured subscription into local TimescaleDB. Slice 14 does not create Pub/Sub resources.

Cold exports default to local files. `make export-cold` uses the 72-hour retention window from `COLD_EXPORT_HOT_RETENTION_HOURS`; `make export-cold-demo` uses `COLD_EXPORT_MODE=all` behavior so teammates can validate Parquet output immediately after seeding. Set `COLD_STORAGE_TARGET=gcs` or run `make export-cold-gcs` to upload Parquet output to `GCS_BUCKET` for BigQuery external-table analysis. Exporting does not delete hot TimescaleDB rows.

For the Streamlit command center, install the Python dependencies once with `python3 -m pip install -r apps/streamlit/requirements.txt`, then run `make run-streamlit` and open [http://localhost:8501](http://localhost:8501). The app shows executive KPIs, source-specific city operations, air quality, Divvy mobility, weather, Chicago River telemetry, data quality, sensor network maps, and cold-path evidence from local Parquet or GCS/BigQuery. The Docker Compose stack also includes a profiled `streamlit` service on the same port; start it with `make run-streamlit-compose`.

## Phase 3 Final Submission

The Phase 3 package is documented in [docs/final/README.md](docs/final/README.md). The required code zip is generated with `make phase3-package` and written to `dist/Project_Phase_3_Group4.zip`. The Week 10 presentation artifacts are [PPTX](docs/final/Project_Phase_3_Group4_Presentation.pptx) and [PDF](docs/final/Project_Phase_3_Group4_Presentation.pdf).

## Workstreams

- Go ingestion: OpenAQ, Open-Meteo, GBFS, USGS, simulator, validation, retry/backoff, quality flags.
- Storage: TimescaleDB schema, batch inserts, aggregates, retention flush, Parquet writer.
- Dashboards: Grafana provisioning, Streamlit command center, cost and data-quality analytics.
- DevOps: Docker Compose, container images, Makefile, CI, Terraform/GKE readiness manifests, setup documentation.

## Project Tracking

- [Project Tracker](docs/PROJECT_TRACKER.md): current status, completed slices, roadmap, team work board, and resume protocol.

## Design Inputs

- [Phase 2 detailed design PDF](docs/design/Project_Phase_2_Group4_Report_Detailed_Design.pdf)
- [Phase 2 presentation PDF](docs/design/Project_Phase_2_Group4_Presentation.pdf)
- [Architecture diagram HTML](docs/design/Smart_City_Architecture_Group4_Final.html)
