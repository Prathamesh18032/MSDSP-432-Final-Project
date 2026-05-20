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
```

This command generates deterministic simulator readings and inserts them into local TimescaleDB using `pgx`.
