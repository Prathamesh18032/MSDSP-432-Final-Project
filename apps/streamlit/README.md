# Streamlit Reports

Run locally:

```sh
make run-streamlit
```

Build the deployable Streamlit image locally:

```sh
make docker-build-streamlit
```

The image is tagged as `smartcity-streamlit` under the configured `IMAGE_REGISTRY` and `IMAGE_TAG`. Slice 10 only builds and smoke-tests locally; pushing to Artifact Registry is deferred.

The Streamlit app provides the local analytics surface for seeded TimescaleDB data and locally exported Parquet files.

Implemented reports:

- Overview metrics for readings, sensors, metrics, sources, and latest reading time.
- Air quality trend report from TimescaleDB.
- Data quality and coverage report.
- Sensor health report with stale sensor indicators.
- Cold storage summary from local Parquet files under `data/cold`.

Local setup:

```sh
python3 -m pip install -r apps/streamlit/requirements.txt
make run-local
make seed-simulator
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
