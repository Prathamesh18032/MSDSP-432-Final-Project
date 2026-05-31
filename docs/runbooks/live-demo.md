# Live Demo Runbook

This runbook shows the enterprise runtime story. Use private port-forward for controlled demos, or the guarded public demo workflow when reviewers need a shareable URL.

## Start

Run:

```sh
make demo-live-start
```

This verifies published `main` images, runtime health, Pub/Sub ingestion into GKE TimescaleDB, cold export to GCS/BigQuery, and Streamlit readiness.

Open Streamlit privately:

```sh
make k8s-port-forward-streamlit
```

Then open `http://localhost:8501`.

For a public reviewer URL:

```sh
export STREAMLIT_DEMO_PASSWORD=<share-with-reviewers>
ALLOW_PUBLIC_INGRESS=yes make public-demo-apply
make public-demo-url
```

Disable it after review:

```sh
make public-demo-disable
```

## Demo Story

1. Multi-source producers collect OpenAQ, Open-Meteo, Divvy GBFS, and USGS readings.
2. Pub/Sub carries normalized `SensorReading` messages.
3. The GKE writer consumes messages into internal TimescaleDB.
4. Cold export writes Parquet to GCS and BigQuery queries it through the external table.
5. Streamlit reads the hot TimescaleDB data through port-forward or guarded public demo ingress.
6. TimescaleDB backups are written to GCS and restore-tested in a disposable namespace.

## Recovery Proof

Run:

```sh
make k8s-backup-once
make k8s-backup-check
make k8s-restore-test
make k8s-restore-check
make k8s-restore-clean
```

The restore namespace must stay separate from the live `smartcity` namespace.

## Stop

After demo:

```sh
make demo-live-stop
```

This scales down optional ingestor, writer, and Streamlit deployments. TimescaleDB, PVCs, backups, Pub/Sub, GCS, BigQuery, Artifact Registry, and Terraform-managed resources remain intact.
