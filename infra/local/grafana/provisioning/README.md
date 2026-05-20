# Grafana Provisioning

Grafana is provisioned from files when the local Docker Compose stack starts.

## Local Access

- URL: http://localhost:3000
- Default login: `admin / admin`
- Datasource name: `Smart City TimescaleDB`
- Datasource UID: `timescaledb-hot`

Grafana stores local user changes in the `grafana-data` Docker volume. If the admin password was changed during an earlier run, that password remains active even though Compose still defines the default credentials for fresh volumes.

## Provisioned Dashboard

The `Smart City Operations` dashboard is loaded from `dashboards/smart-city-operations.json`.
It reads seeded simulator data from `sensor_readings` and includes operational panels for
`ingestion_metrics`.

Expected local workflow:

```sh
make run-local
make seed-simulator
```

Sensor panels should show data after seeding. Ingestion operation panels may show no data until a later slice writes rows into `ingestion_metrics`.
