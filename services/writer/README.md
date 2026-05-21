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
```

`make seed-simulator` generates deterministic simulator readings and publishes them through the local queue into TimescaleDB using `pgx`.

`make export-cold` exports readings older than the configured hot-retention window into local Parquet files. `make export-cold-demo` exports current local rows so the team can validate the cold path without waiting 72 hours. Both commands preserve TimescaleDB rows.

Cold Parquet output uses the future GCS-compatible partition layout:

```text
data/cold/sensor_readings/source=<source>/metric=<metric>/year=YYYY/month=MM/day=DD/part-<timestamp>.parquet
```
