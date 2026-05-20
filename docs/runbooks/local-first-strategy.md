# Local-First Strategy

The project starts local-first so all four team members can work without waiting for GCP credentials or billing setup.

## First Build Target

Build a deterministic local vertical slice:

1. Go simulator and OpenAQ poller produce readings.
2. Validator normalizes and flags readings.
3. Queue abstraction passes readings to the writer.
4. Writer inserts hot data into TimescaleDB.
5. Grafana reads live data from TimescaleDB.

The current slice implements the simulator, validator, initial TimescaleDB schema, and local seed writer. OpenAQ and Grafana provisioning come next.

## Current Local Commands

```sh
make check
make test
make run-local
make seed-simulator
```

If the local TimescaleDB volume already exists from an earlier schema, run `make clean` before `make run-local` so Docker replays the init SQL.

## Parallel Workstreams

- Go ingestion: source clients, simulator, validator, retry/backoff, quality flags.
- Storage: TimescaleDB schema, inserts, aggregates, retention flush, Parquet path.
- Dashboards: Grafana provisioning, Streamlit reports, data-quality views.
- DevOps: Compose, CI, Makefile, Terraform/Kubernetes placeholders, setup docs.

## Cloud Readiness

Cloud resources should be prepared behind interfaces and manifests, but the local MVP should not require live GCP access.

When GCP is ready, the team can swap local adapters for:

- Pub/Sub for durable buffering.
- GCS for cold Parquet storage.
- BigQuery for historical analysis.
- GKE Autopilot for deployment.
