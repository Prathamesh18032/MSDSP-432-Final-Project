# Cloud Operations Runbook

This runbook covers Slice 18 through Slice 20 runtime operations for the Smart City Zero-Disk IoT cloud environment.

## Daily Health Check

Run:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make gcp-core-check
make k8s-status
make runtime-health
make observability-check
```

The runtime health and observability checks verify Kubernetes workload readiness, restart counts, failed jobs, PVC status, Pub/Sub reachability/backlog when available, GCS cold/backup object visibility, BigQuery external-table queryability, current runtime images, and recent logs.

## Release Promotion

Main-branch CI publishes `latest-main` and short-SHA image tags. Deployment remains manual:

```sh
make runtime-promote-latest
make runtime-release-check
```

To promote a specific short SHA:

```sh
IMAGE_TAG=<short-sha> make runtime-promote-sha
RUNTIME_EXPECTED_IMAGE_TAG=<short-sha> make runtime-release-check
```

## Runtime Modes

Use demo mode before a review window:

```sh
make runtime-demo-mode
```

Use idle mode after demos to reduce spend while preserving recoverability:

```sh
make runtime-idle-mode
```

Resume from idle:

```sh
make runtime-resume-mode
```

`runtime-idle-mode` disables public ingress, suspends backup/cold-export CronJobs, and scales optional deployments down. It preserves PVCs, GCS, Pub/Sub, BigQuery, Artifact Registry, backups, and Terraform resources.

## Live Runtime Smoke

Use this after deploying new images or applying runtime manifests:

```sh
RUNTIME_IMAGE_TAG=latest-main make k8s-render
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

## Restore Test

Restore testing is isolated from the live `smartcity` namespace. It creates a disposable namespace, restores the selected backup into a temporary TimescaleDB StatefulSet, validates restored tables and nonzero readings, then can be cleaned up:

```sh
make k8s-restore-test
make k8s-restore-check
make k8s-restore-clean
```

Defaults:

```text
RESTORE_TEST_NAMESPACE=smartcity-restore-test
RESTORE_TEST_STORAGE_SIZE=5Gi
RESTORE_TEST_BACKUP_URI=latest
```

Never set `RESTORE_TEST_NAMESPACE` to the live runtime namespace.

## CI/CD Image Publishing And Runtime Promotion

The `Publish Images` GitHub Actions workflow builds and pushes the three service images on `main` merges. It uses GitHub OIDC and GCP Workload Identity Federation, not service account JSON keys.

Required GitHub repository variables after Terraform apply:

```text
GCP_WORKLOAD_IDENTITY_PROVIDER=<terraform output github_actions_workload_identity_provider>
GCP_CI_SERVICE_ACCOUNT=<terraform output github_actions_service_account>
```

CI publishes short-SHA and `latest-main` tags. On `main`, a successful `Publish Images` run automatically triggers the `Promote Runtime` workflow, which deploys `latest-main` to GKE, applies Grafana provisioning ConfigMaps, restarts Grafana, verifies deployed image tags, and runs runtime health checks. Validate published tags with:

```sh
make ci-publish-check
```

To rerun promotion manually or deploy a specific tag, use one of these paths after a successful publish:

```sh
make runtime-promote-latest
```

Or run the GitHub Actions workflow `Promote Runtime` from the Actions tab. Choose `latest-main` or a short-SHA image tag, then optionally enable public Streamlit smoke, public Grafana ingress apply, and public Grafana smoke. The workflow renders the runtime manifests, applies the selected tag to GKE, updates Grafana provisioning, verifies the deployed image tags, and runs `make runtime-health`.

For a specific short SHA locally:

```sh
IMAGE_TAG=<short-sha> make runtime-promote-sha
```

## Public Demo

Use the [public demo runbook](public-demo.md) when teammates, the professor, or reviewers need a URL. Streamlit requires `STREAMLIT_DEMO_PASSWORD`; Grafana uses a separate login-protected ingress with `GRAFANA_ADMIN_PASSWORD`.

## Cost Watch

GKE Autopilot, persistent volumes, Artifact Registry storage, GCS, and BigQuery queries can incur cost. Keep the budget alert active and scale down or delete nonessential workloads after demos.

```sh
make runtime-cost-check
make runtime-cost-report
RUNTIME_COST_ACK=true make runtime-cost-guard
make runtime-scale-down
```

`runtime-scale-down` scales ingestor, writer, and Streamlit to zero replicas. It does not delete TimescaleDB, PVCs, backups, Pub/Sub, GCS, BigQuery, Artifact Registry, or Terraform-managed resources.

## Evidence Capture

Capture sanitized runtime evidence:

```sh
make runtime-evidence
```

Evidence is written under `artifacts/evidence/` and is ignored by Git. Do not add `.env`, Terraform state, kubeconfig, tokens, or raw credentials to evidence bundles.
