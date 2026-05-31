# Grafana Provisioning

Grafana is provisioned from files when the local Docker Compose stack starts.

## Local Access

- URL: http://localhost:3000
- Default login: `admin / admin`
- Datasource name: `Smart City TimescaleDB`
- Datasource UID: `timescaledb-hot`

Grafana stores local user changes in the `grafana-data` Docker volume. If the admin password was changed during an earlier run, that password remains active even though Compose still defines the default credentials for fresh volumes.

## Provisioned Dashboard

The `Smart City Enterprise Operations` dashboard is loaded from `dashboards/smart-city-operations.json`.
It is the local reviewer-grade observability surface for the data platform and reads from the
`sensor_readings` and `ingestion_metrics` tables in TimescaleDB.

Recommended local reviewer workflow:

```sh
make grafana-demo-ready
```

This starts the local Docker Compose stack, seeds deterministic simulator readings, and runs one
multi-source poll against Open-Meteo, Divvy GBFS, USGS, and OpenAQ when `OPENAQ_API_KEY` is set.
OpenAQ is skipped without a key. The live source panels depend on network availability and provider
responses; the simulator and ingestion operation panels should populate from the local seed path.

The dashboard sections are:

- `Executive Overview`: reviewer-facing KPIs for readings, sensors, sources, validity, freshness, and drops.
- `Live Ingestion Operations`: local queue throughput, backpressure, and dropped-reading trends.
- `City Signal Domains`: air quality, weather/water, mobility, source coverage, and metric coverage.
- `Sensor Estate`: native Grafana geomap, sensor freshness, coverage, and latest readings.
- `Data Quality`: quality distribution, valid-reading rate by source, and suspect/invalid rows.

The dashboard intentionally avoids Pub/Sub lag and GCS latency panels for local mode because those
fields are normally `NULL` unless a future slice records those cloud metrics into TimescaleDB.
