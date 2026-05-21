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
make run-local
make seed-simulator
make run-openaq
make export-cold-demo
make run
make stop
```

`make check` validates the foundation scaffold. `make test` runs Go tests. `make run-local` starts the local Docker Compose stack in the background, and `make seed-simulator` publishes deterministic simulator readings through the local buffer into TimescaleDB once the database is healthy. `make run-openaq` starts the continuous OpenAQ v3 poller and requires `OPENAQ_API_KEY`. `make export-cold-demo` exports current TimescaleDB readings to local Parquet files under `data/cold`.

After seeding data, open Grafana at [http://localhost:3000](http://localhost:3000) and sign in with the local defaults `admin / admin`. The `Smart City Operations` dashboard is provisioned automatically and reads from the local TimescaleDB datasource. If an existing `grafana-data` volume has a changed admin password, Grafana keeps that password until local volumes are reset.

To watch live OpenAQ readings, set `OPENAQ_API_KEY` in `.env`, run `make run-local`, then run `make run-openaq` in a second terminal. Stop the poller with `Ctrl+C`.

Both simulator and OpenAQ commands use the local queue buffer before writing to TimescaleDB. Queue behavior is controlled by `BACKPRESSURE_CHANNEL_CAPACITY`, `QUEUE_BATCH_SIZE`, and `QUEUE_FLUSH_INTERVAL_MS`.

Cold exports are local-only in this slice. `make export-cold` uses the 72-hour retention window from `COLD_EXPORT_HOT_RETENTION_HOURS`; `make export-cold-demo` uses `COLD_EXPORT_MODE=all` behavior so teammates can validate Parquet output immediately after seeding. Exporting does not delete hot TimescaleDB rows.

## Workstreams

- Go ingestion: OpenAQ client, simulator, validation, retry/backoff, quality flags.
- Storage: TimescaleDB schema, batch inserts, aggregates, retention flush, Parquet writer.
- Dashboards: Grafana provisioning, Streamlit reports, cost and data-quality analytics.
- DevOps: Docker Compose, Makefile, CI, cloud manifests, setup documentation.

## Project Tracking

- [Project Tracker](docs/PROJECT_TRACKER.md): current status, completed slices, roadmap, team work board, and resume protocol.

## Design Inputs

- [Phase 2 detailed design PDF](docs/design/Project_Phase_2_Group4_Report_Detailed_Design.pdf)
- [Architecture diagram HTML](docs/design/Smart_City_Architecture_Group4_Final.html)
