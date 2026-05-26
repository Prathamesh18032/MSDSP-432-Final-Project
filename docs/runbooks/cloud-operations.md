# Cloud Operations Runbook

This runbook covers Slice 18 runtime operations for the Smart City Zero-Disk IoT cloud environment.

## Daily Health Check

Run:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make gcp-core-check
make k8s-status
make observability-check
```

The observability check verifies Kubernetes workload readiness, recent logs, Pub/Sub subscription reachability, GCS cold-object visibility, and BigQuery external-table queryability.

## Live Runtime Smoke

Use this after deploying new images or applying runtime manifests:

```sh
RUNTIME_IMAGE_TAG=slice18 make k8s-render
make k8s-apply
make runtime-live-smoke
RUN_COLD_EXPORT_SMOKE=yes make k8s-smoke
```

`runtime-live-smoke` publishes one multi-source batch to Pub/Sub from the local producer, waits for the GKE writer, and queries internal TimescaleDB.

## Logs

```sh
make k8s-logs
```

This prints recent logs from the ingestor, hot writer, Streamlit, and TimescaleDB workloads.

## TimescaleDB Backups

Backups run from the `smartcity-timescale-backup` CronJob and write custom-format `pg_dump` files to:

```text
gs://<GCS_BUCKET>/backups/timescaledb/year=YYYY/month=MM/day=DD/smartcity_hot-<timestamp>.dump
```

Trigger and verify one backup:

```sh
make k8s-backup-once
make k8s-backup-check
```

Restore is intentionally manual in this slice. For a future restore test, create a temporary TimescaleDB instance or namespace, download the selected `.dump`, and run `pg_restore` against the temporary database before touching the live hot store.

## CI/CD Image Publishing

The `Publish Images` GitHub Actions workflow builds and pushes the three service images on `main` merges. It uses GitHub OIDC and GCP Workload Identity Federation, not service account JSON keys.

Required GitHub repository variables after Terraform apply:

```text
GCP_WORKLOAD_IDENTITY_PROVIDER=<terraform output github_actions_workload_identity_provider>
GCP_CI_SERVICE_ACCOUNT=<terraform output github_actions_service_account>
```

CI publishes short-SHA and `latest-main` tags. Runtime deployment remains manual through `make k8s-render` and `make k8s-apply`.

## Cost Watch

GKE Autopilot, persistent volumes, Artifact Registry storage, GCS, and BigQuery queries can incur cost. Keep the budget alert active and scale down or delete nonessential workloads after demos.
