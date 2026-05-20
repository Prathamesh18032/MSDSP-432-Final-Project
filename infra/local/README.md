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
