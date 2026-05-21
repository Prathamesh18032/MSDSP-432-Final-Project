# Ingestor Service

The ingestor service owns source clients and normalization before readings are handed to storage.

Implemented local sources:

- Deterministic Go simulator in `internal/simulator`.
- OpenAQ v3 latest-measurement poller in `services/ingestor/cmd/poll-openaq`.
- Multi-source poller in `services/ingestor/cmd/poll-multisource` for OpenAQ, Open-Meteo, Divvy GBFS, and USGS.

## OpenAQ Poller

The OpenAQ poller discovers locations near the configured coordinates, fetches latest readings for each location, maps supported pollutants into the shared `SensorReading` contract, validates them, and writes valid readings into local TimescaleDB.

Simulator and OpenAQ readings are published through the local queue buffer before they are flushed into TimescaleDB. The buffer is bounded, drops readings when full, and records `ingestion_metrics` so Grafana can show throughput, channel fill, and dropped-reading totals.

Supported OpenAQ mappings:

- `pm25` / `pm2.5` with `µg/m³` or equivalent units -> `PM2.5` / `ug/m3`.
- `o3` with `ppm` -> `O3` / `ppm`.
- `no2` with `ppb` -> `NO2` / `ppb`.

Unsupported parameters or incompatible units are skipped with logs so the poller can continue processing the rest of the batch.

Local workflow:

```sh
make run-local
make run-openaq
make poll-multisource-once
make run-multisource
make docker-build-ingestor
```

Required environment:

- `OPENAQ_API_KEY`

`OPENAQ_API_KEY` is required for `make run-openaq`. It is optional for `make run-multisource`; the unified poller skips OpenAQ when the key is empty and continues with public no-secret sources.

Useful optional environment:

- `OPENAQ_COORDINATES`
- `OPENAQ_RADIUS_METERS`
- `OPENAQ_LOCATION_LIMIT`
- `OPENAQ_POLL_INTERVAL_SECONDS`
- `MULTISOURCE_POLL_INTERVAL_SECONDS`
- `OPENMETEO_COORDINATES`
- `GBFS_STATION_LIMIT`
- `USGS_SITE_IDS`
- `USGS_PARAMETER_CODES`
- `BACKPRESSURE_CHANNEL_CAPACITY`
- `QUEUE_BATCH_SIZE`
- `QUEUE_FLUSH_INTERVAL_MS`

## Multi-Source Poller

The multi-source poller makes the local MVP feel like a practical city operations feed:

- Open-Meteo maps current weather into `temperature`, `humidity`, `wind_speed`, and `precipitation`.
- Divvy GBFS joins `station_information` with `station_status` and emits `bike_available_count`, `dock_available_count`, and `station_capacity`.
- USGS reads the Chicago River at Columbus Drive gage height as `water_gage_height`.
- OpenAQ is included when `OPENAQ_API_KEY` is present.

All source pollers publish valid readings through the same local queue and TimescaleDB writer. A failure in one live source is logged but does not stop the remaining sources in that polling cycle.

## Container Image

Build the deployable ingestor image locally:

```sh
make docker-build-ingestor
```

The image runs `poll-multisource` by default and is tagged as `smartcity-ingestor` under the configured `IMAGE_REGISTRY` and `IMAGE_TAG`. Slice 10 only builds and smoke-tests locally; pushing to Artifact Registry is deferred.

Future responsibilities:

- Retry/backoff policy shared across source clients.
- Operational metrics for poller throughput, dropped readings, and lag.
