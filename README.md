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
5. Visualize real-time and historical insights through Grafana and Streamlit.

The first implementation milestone is intentionally small: establish the repository structure and local developer workflow before building application logic.

## Repository Layout

```text
apps/streamlit/        Streamlit reporting app placeholder
docs/design/           Phase 2 PDF report and architecture diagram
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
make docker-build
make docker-smoke
make run-local
make seed-simulator
make run-openaq
make poll-multisource-once
make run-multisource
make export-cold-demo
make run-streamlit
make run-streamlit-compose
make run
make stop
```

`make check` validates the foundation scaffold. `make test` runs Go tests. `make streamlit-check` validates the Streamlit Python files. `make cloud-check` validates the cloud-readiness scaffold without contacting GCP. `make docker-build` builds local deployable images for the ingestor, writer, and Streamlit app; `make docker-smoke` verifies those images start cleanly without pushing them. `make run-local` starts the local Docker Compose stack in the background, and `make seed-simulator` publishes deterministic simulator readings through the local buffer into TimescaleDB once the database is healthy. `make run-openaq` starts the continuous OpenAQ v3 poller and requires `OPENAQ_API_KEY`. `make poll-multisource-once` runs one local poll across OpenAQ, Open-Meteo, Divvy GBFS, and USGS; `OPENAQ_API_KEY` is optional in this unified path, so OpenAQ is skipped when the key is missing. `make run-multisource` runs the same source set continuously. `make export-cold-demo` exports current TimescaleDB readings to local Parquet files under `data/cold`. `make run-streamlit` starts the local reports app, and `make run-streamlit-compose` starts the Compose Streamlit service.

After seeding data, open Grafana at [http://localhost:3000](http://localhost:3000) and sign in with the local defaults `admin / admin`. The `Smart City Operations` dashboard is provisioned automatically and reads from the local TimescaleDB datasource. If an existing `grafana-data` volume has a changed admin password, Grafana keeps that password until local volumes are reset.

To watch live OpenAQ readings, set `OPENAQ_API_KEY` in `.env`, run `make run-local`, then run `make run-openaq` in a second terminal. Stop the poller with `Ctrl+C`.

To watch broader smart-city telemetry, run `make run-local`, then run `make run-multisource` in a second terminal. This adds live weather from Open-Meteo, bike-share station availability from Divvy GBFS, Chicago River gage height from USGS, and OpenAQ readings when `OPENAQ_API_KEY` is configured.

Simulator, OpenAQ, and multi-source commands use the local queue buffer before writing to TimescaleDB. Queue behavior is controlled by `BACKPRESSURE_CHANNEL_CAPACITY`, `QUEUE_BATCH_SIZE`, and `QUEUE_FLUSH_INTERVAL_MS`.

Cold exports are local-only in this slice. `make export-cold` uses the 72-hour retention window from `COLD_EXPORT_HOT_RETENTION_HOURS`; `make export-cold-demo` uses `COLD_EXPORT_MODE=all` behavior so teammates can validate Parquet output immediately after seeding. Exporting does not delete hot TimescaleDB rows.

For local Streamlit reports, install the Python dependencies once with `python3 -m pip install -r apps/streamlit/requirements.txt`, then run `make run-streamlit` and open [http://localhost:8501](http://localhost:8501). The Docker Compose stack also includes a profiled `streamlit` service on the same port; start it with `make run-streamlit-compose`.

## Workstreams

- Go ingestion: OpenAQ, Open-Meteo, GBFS, USGS, simulator, validation, retry/backoff, quality flags.
- Storage: TimescaleDB schema, batch inserts, aggregates, retention flush, Parquet writer.
- Dashboards: Grafana provisioning, Streamlit reports, cost and data-quality analytics.
- DevOps: Docker Compose, container images, Makefile, CI, Terraform/GKE readiness manifests, setup documentation.

## Project Tracking

- [Project Tracker](docs/PROJECT_TRACKER.md): current status, completed slices, roadmap, team work board, and resume protocol.

## Design Inputs

- [Phase 2 detailed design PDF](docs/design/Project_Phase_2_Group4_Report_Detailed_Design.pdf)
- [Architecture diagram HTML](docs/design/Smart_City_Architecture_Group4_Final.html)
