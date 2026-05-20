# Local Infrastructure

Local infrastructure supports the first MVP without requiring GCP credentials.

Current starter stack:

- TimescaleDB for hot sensor readings.
- PostgreSQL for metadata tables.
- Grafana for real-time dashboards.

Future additions:

- TimescaleDB init SQL and migrations.
- Grafana datasource and dashboard provisioning.
- Seed data for demo and dashboard smoke tests.

Current schema:

- `timescaledb/init/001_schema.sql` creates `sensor_readings`, `ingestion_metrics`, and `hourly_aggregates`.

Run the local stack and seed simulator data:

```sh
make run-local
make seed-simulator
```
