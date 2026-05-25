# Cloud Cold Path Runbook

Slice 16 exports local TimescaleDB readings to Parquet, uploads those files to the GCS cold bucket, and validates that BigQuery can query the external table.

## Prerequisites

- Slice 15 core resources are applied and healthy.
- `gcloud` is authenticated to `GCP_PROJECT_ID`.
- `.env` contains the project values:

```sh
GCP_PROJECT_ID=smartcity-zero-disk-iot-pa
GCP_REGION=asia-south1
GCS_BUCKET=smartcity-zero-disk-iot-pa-cold
BIGQUERY_DATASET=smartcity_iot
BIGQUERY_EXTERNAL_TABLE=sensor_readings_external
```

## Commands

Run the local stack and seed data:

```sh
make run-local
make seed-simulator
```

Export current local rows to GCS:

```sh
COLD_EXPORT_MODE=all make export-cold-gcs
```

Validate BigQuery can query the external table:

```sh
CLOUD_COLD_MIN_ROWS=1 make bigquery-cold-check
```

Or run the end-to-end smoke:

```sh
make cloud-cold-smoke
```

## Behavior

- `COLD_STORAGE_TARGET=local` remains the default.
- `COLD_STORAGE_TARGET=gcs` writes Parquet locally first, then uploads the same partition layout to GCS.
- Local Parquet files are kept by default through `CLOUD_COLD_EXPORT_KEEP_LOCAL=true`.
- TimescaleDB rows are not deleted after export.
- BigQuery visibility may take a short moment after upload, so the check retries before failing.

## Cost Notes

This slice uses the existing low-cost GCS bucket and BigQuery external table. The smoke test uploads a small seeded Parquet set and runs a row-count query only. It does not create GKE, Cloud SQL, scheduled jobs, BigQuery native tables, or remote Terraform state.
