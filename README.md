# MSDSP-432-Final-Project

Smart City Zero-Disk IoT Infrastructure for MSDS 432 Foundations of Data Engineering.

Author: Prathamesh  
Team: Group 4  
Status: Repo foundation scaffold is in progress.

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
make run
make stop
```

`make check` validates the foundation scaffold. `make run` starts the local Docker Compose stack once Docker is available.

## Workstreams

- Go ingestion: OpenAQ client, simulator, validation, retry/backoff, quality flags.
- Storage: TimescaleDB schema, batch inserts, aggregates, retention flush, Parquet writer.
- Dashboards: Grafana provisioning, Streamlit reports, cost and data-quality analytics.
- DevOps: Docker Compose, Makefile, CI, cloud manifests, setup documentation.

## Design Inputs

- [Phase 2 detailed design PDF](docs/design/Project_Phase_2_Group4_Report_Detailed_Design.pdf)
- [Architecture diagram HTML](docs/design/Smart_City_Architecture_Group4_Final.html)
