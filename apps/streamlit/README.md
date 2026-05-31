# Smart City Command Center

Run locally:

```sh
make run-streamlit
```

Build the deployable Streamlit image locally:

```sh
make docker-build-streamlit
```

The image is tagged as `smartcity-streamlit` under the configured `IMAGE_REGISTRY` and `IMAGE_TAG`.

The Streamlit app is the public reviewer/client surface for the project. It presents current city operations, source health, historical archive evidence, and executive reporting in product-facing language.

For public demo mode, set `PUBLIC_DEMO_ENABLED=true` and provide `STREAMLIT_DEMO_PASSWORD`. Without public demo mode, local and private cloud usage do not require a password. Only the reporting app is intended for public review.

Implemented command-center sections:

- Executive overview with city KPIs, source freshness, data readiness, service health, and archive status.
- City operations with source activity, health signals, and downloadable source summaries.
- Air quality, mobility, weather, and Chicago River views with metric-specific visuals.
- Sensor network map/table with friendly station names plus coordinates.
- Data quality coverage, quality flags, stale sensor context, and downloadable coverage summaries.
- Historical archive status from local exports or cloud reporting configuration.

Useful app settings:

```sh
STREAMLIT_REFRESH_SECONDS=60
STREAMLIT_DEFAULT_WINDOW_HOURS=24
STREAMLIT_BRAND_TITLE="Smart City Command Center"
STREAMLIT_CITY_NAME=Chicago
STREAMLIT_ENABLE_GBFS_STATION_NAMES=true
```

Local setup:

```sh
python3 -m pip install -r apps/streamlit/requirements.txt
make run-local
make seed-simulator
make poll-multisource-once
make export-cold-demo
make run-streamlit
```

Then open [http://localhost:8501](http://localhost:8501).

Docker setup:

```sh
make run-local
make seed-simulator
make export-cold-demo
make run-streamlit-compose
```

The profiled Compose service starts at [http://localhost:8501](http://localhost:8501). The container reads TimescaleDB through the Compose network and mounts local `data/cold` read-only for Parquet summaries.
