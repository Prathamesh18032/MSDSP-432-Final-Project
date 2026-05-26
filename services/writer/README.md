# Writer Service

Placeholder for the Go storage writer service.

Initial responsibilities:

- Consume validated readings from the queue abstraction.
- Batch insert hot readings into TimescaleDB.
- Emit ingestion metrics.
- Prepare the cold path for memory-to-Parquet writing and GCS-compatible partitioning.
- Run or trigger the 72-hour hot-layer retention flush.

Current command:

```sh
make seed-simulator
make export-cold
make export-cold-demo
make export-cold-gcs
make consume-pubsub
make consume-pubsub-once
make docker-build-writer
```

`make seed-simulator` generates deterministic simulator readings and publishes them through the local queue into TimescaleDB using `pgx`.

`make export-cold` exports readings older than the configured hot-retention window into local Parquet files. `make export-cold-demo` exports current local rows so the team can validate the cold path without waiting 72 hours. `make export-cold-gcs` uses the same export path with `COLD_STORAGE_TARGET=gcs` and uploads the resulting Parquet files to `GCS_BUCKET`. All cold export commands preserve TimescaleDB rows.

`make consume-pubsub` runs the cloud-ready hot writer path. It consumes `SensorReading` JSON messages from `GCP_PUBSUB_SUBSCRIPTION`, validates them, inserts them into TimescaleDB, and acknowledges messages only after a successful write. Pub/Sub is at-least-once delivery, so duplicate messages are tolerated by the existing TimescaleDB upsert key on `(time, sensor_id, metric)`.

`make consume-pubsub-once` sets `PUBSUB_CONSUME_LIMIT` and `PUBSUB_CONSUME_TIMEOUT_SECONDS` so smoke tests can stop automatically after a bounded number of successful message writes.

Cold Parquet output uses the future GCS-compatible partition layout:

```text
data/cold/sensor_readings/source=<source>/metric=<metric>/year=YYYY/month=MM/day=DD/part-<timestamp>.parquet
```

When uploaded to GCS, the object path preserves the `sensor_readings/...` suffix so the BigQuery external table can query the same partition layout:

```text
gs://<GCS_BUCKET>/sensor_readings/source=<source>/metric=<metric>/year=YYYY/month=MM/day=DD/part-<timestamp>.parquet
```

## TimescaleDB Backups

The writer image also includes `backup-timescale`, which runs `pg_dump` against `TIMESCALE_DSN` and uploads a custom-format dump to GCS:

```text
gs://<GCS_BUCKET>/backups/timescaledb/year=YYYY/month=MM/day=DD/smartcity_hot-<timestamp>.dump
```

The GKE runtime uses this command from the `smartcity-timescale-backup` CronJob. Local restore testing is documented in `docs/runbooks/cloud-operations.md`.

## Container Image

Build the deployable writer image locally:

```sh
make docker-build-writer
```

The image runs `export-cold` by default and is tagged as `smartcity-writer` under the configured `IMAGE_REGISTRY` and `IMAGE_TAG`. It also includes `/usr/local/bin/consume-pubsub` for the future cloud hot writer deployment.
