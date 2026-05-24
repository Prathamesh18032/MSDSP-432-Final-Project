# Local-First Strategy

The project starts local-first so all four team members can work without waiting for GCP credentials or billing setup.

## First Build Target

Build a deterministic local vertical slice:

1. Go simulator and live city pollers produce readings.
2. Validator normalizes and flags readings.
3. Queue abstraction passes readings to the writer.
4. Writer inserts hot data into TimescaleDB.
5. Writer can export hot data to local Parquet cold storage.
6. Grafana reads live data from TimescaleDB.
7. Streamlit reports on local hot and cold data.

The local MVP now includes simulator data, OpenAQ air-quality readings, Open-Meteo weather readings, Divvy GBFS bike-share station readings, and USGS Chicago River telemetry.

## Current Local Commands

```sh
make check
make test
make cloud-check
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
make terraform-import-artifact-registry
make terraform-apply-core
make gcp-core-check
make pubsub-check
make run-local
make seed-simulator
make run-openaq
make poll-multisource-once
make run-multisource
make consume-pubsub
make consume-pubsub-once
make pubsub-smoke
make pubsub-hotpath-smoke
make export-cold-demo
make run-streamlit
make run-streamlit-compose
```

If the local TimescaleDB volume already exists from an earlier schema, run `make clean` before `make run-local` so Docker replays the init SQL.

`make seed-simulator` and `make run-openaq` publish through the local queue buffer before TimescaleDB. The buffer records `ingestion_metrics`, so Grafana operation panels should populate after local ingestion runs.

`make run-openaq` requires `OPENAQ_API_KEY` and runs continuously until interrupted. Use it after `make run-local` to insert OpenAQ readings into TimescaleDB and watch Grafana panels refresh.

`make poll-multisource-once` validates all configured live city sources in one run. `make run-multisource` keeps them running continuously. The unified poller includes Open-Meteo, Divvy GBFS, USGS, and OpenAQ when `OPENAQ_API_KEY` is present. If OpenAQ is not configured, it is skipped while the public no-secret sources still run.

`make export-cold` exports retention-eligible readings into local Parquet files under `data/cold`. `make export-cold-demo` exports current rows for immediate validation. Local cold exports do not delete TimescaleDB rows yet.

`make run-streamlit` starts the local reports app after Python dependencies are installed. `make run-streamlit-compose` starts the profiled Docker Compose Streamlit service at port `8501`.

`make cloud-check` validates Terraform and GKE readiness files without contacting GCP. Use it before changing cloud scaffolding or opening a cloud-readiness PR.

`make gcp-bootstrap-check`, `make gcp-cost-guard-check`, and `make artifact-registry-preview` prepare local GCP settings safely for a fresh account. They do not create resources or push images.

`make artifact-registry-create` is the first controlled live cloud command. It enables Artifact Registry, creates one Docker repository in `asia-south1` if missing, and configures Docker auth. `make artifact-registry-check` and `make artifact-registry-list` verify the repository and published images.

`make docker-build` builds the local ingestor, writer, and Streamlit images. `make docker-smoke` verifies those images exist and start with clear local behavior. `make docker-tag-release` applies the configured release tag when needed, and `make docker-push` publishes the images to Artifact Registry. These commands do not deploy workloads.

`INGESTION_SINK=local` is the default producer path. `INGESTION_SINK=pubsub` switches source pollers to publish `SensorReading` JSON messages to an existing Pub/Sub topic. `make pubsub-check`, `make pubsub-smoke`, and `make consume-pubsub` are readiness commands only; they do not create topics or subscriptions.

## Parallel Workstreams

- Go ingestion: OpenAQ, Open-Meteo, GBFS, USGS, simulator, validator, retry/backoff, quality flags.
- Storage: TimescaleDB schema, inserts, aggregates, retention flush, Parquet path.
- Dashboards: Grafana provisioning, Streamlit reports, data-quality views.
- DevOps: Compose, container images, CI, Makefile, Terraform/GKE readiness manifests, setup docs.

## Cloud Readiness

Cloud resources should be prepared behind interfaces and manifests, but the local MVP should not require live GCP access.

When GCP is ready, the team can swap local adapters for:

- Pub/Sub for durable buffering.
- GCS for cold Parquet storage.
- BigQuery for historical analysis.
- GKE Autopilot for deployment.
