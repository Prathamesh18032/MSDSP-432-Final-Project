# Ingestor Service

The ingestor service owns source clients and normalization before readings are handed to storage.

Implemented local sources:

- Deterministic Go simulator in `internal/simulator`.
- OpenAQ v3 latest-measurement poller in `services/ingestor/cmd/poll-openaq`.

## OpenAQ Poller

The OpenAQ poller discovers locations near the configured coordinates, fetches latest readings for each location, maps supported pollutants into the shared `SensorReading` contract, validates them, and writes valid readings into local TimescaleDB.

Supported OpenAQ mappings:

- `pm25` / `pm2.5` with `µg/m³` or equivalent units -> `PM2.5` / `ug/m3`.
- `o3` with `ppm` -> `O3` / `ppm`.
- `no2` with `ppb` -> `NO2` / `ppb`.

Unsupported parameters or incompatible units are skipped with logs so the poller can continue processing the rest of the batch.

Local workflow:

```sh
make run-local
make run-openaq
```

Required environment:

- `OPENAQ_API_KEY`

Useful optional environment:

- `OPENAQ_COORDINATES`
- `OPENAQ_RADIUS_METERS`
- `OPENAQ_LOCATION_LIMIT`
- `OPENAQ_POLL_INTERVAL_SECONDS`

Future responsibilities:

- Queue publisher abstraction for local mode and future GCP Pub/Sub mode.
- Retry/backoff policy shared across source clients.
- Operational metrics for poller throughput, dropped readings, and lag.
