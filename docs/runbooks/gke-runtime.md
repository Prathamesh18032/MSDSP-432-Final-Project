# GKE Runtime Runbook

This runbook covers Slice 17: the first enterprise cloud runtime with GKE Autopilot and self-hosted TimescaleDB as the hot store. It intentionally does not use Cloud SQL or an external Timescale service.

## Cost And Safety

Runtime resources can create ongoing cost. Confirm these before applying:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make gcp-core-check
```

Do not run the runtime apply unless the team is ready to create GKE Autopilot resources:

```sh
ALLOW_TERRAFORM_APPLY_RUNTIME=yes make terraform-apply-runtime
```

The runtime path does not create service account keys, Cloud SQL, external TimescaleDB, or remote Terraform state. Public Streamlit access is handled separately by the guarded public demo workflow.

## Prerequisites

- Core GCP resources from Slice 15 are applied.
- Artifact Registry contains current images for ingestor, writer, and Streamlit.
- Local `infra/cloud/terraform/terraform.tfvars` exists and points at project `smartcity-zero-disk-iot-pa` in `asia-south1`.
- `K8S_TIMESCALE_PASSWORD` is available locally when applying Kubernetes manifests.
- Optional `OPENAQ_API_KEY` is available locally if the cloud ingestor should include OpenAQ.

Recommended image tag:

```sh
make docker-build IMAGE_TAG=latest-main
make docker-smoke IMAGE_TAG=latest-main
make docker-push IMAGE_TAG=latest-main
```

`make docker-build` defaults to `DOCKER_PLATFORM=linux/amd64` because GKE Autopilot schedules these workloads on AMD64 nodes.

## Apply Order

1. Review runtime Terraform:

```sh
make terraform-validate
make terraform-plan-runtime
```

2. Apply runtime Terraform only with the explicit guard:

```sh
ALLOW_TERRAFORM_APPLY_RUNTIME=yes make terraform-apply-runtime
```

3. Configure kubectl:

```sh
make gke-get-credentials
```

4. Render Kubernetes manifests:

```sh
RUNTIME_IMAGE_TAG=latest-main make k8s-render
```

5. Apply runtime manifests and create the runtime secret:

```sh
K8S_TIMESCALE_PASSWORD=<strong-password> RUNTIME_IMAGE_TAG=latest-main make k8s-apply
```

6. Check status:

```sh
make k8s-status
make k8s-smoke
```

To include one cold-export CronJob execution in the smoke:

```sh
RUN_COLD_EXPORT_SMOKE=yes make k8s-smoke
```

To trigger and verify one TimescaleDB backup:

```sh
make k8s-backup-once
make k8s-backup-check
```

7. Test backup restore in an isolated namespace:

```sh
make k8s-restore-test
make k8s-restore-check
make k8s-restore-clean
```

8. View Streamlit locally through port-forward:

```sh
make k8s-port-forward-streamlit
```

Open `http://localhost:8501`.

For a shareable reviewer URL, use `make public-demo-apply` with `ALLOW_PUBLIC_INGRESS=yes` and `STREAMLIT_DEMO_PASSWORD` set. See [public-demo.md](public-demo.md).

## Expected Runtime Flow

```text
multi-source ingestor -> Pub/Sub -> hot writer -> internal TimescaleDB StatefulSet
internal TimescaleDB -> cold export CronJob -> GCS Parquet -> BigQuery external table
internal TimescaleDB -> backup CronJob -> GCS pg_dump backup
internal TimescaleDB -> Streamlit service -> local port-forward or guarded public demo ingress
```

TimescaleDB is exposed only inside the Kubernetes cluster through `smartcity-timescaledb.<namespace>.svc.cluster.local:5432`.

## Rollback And Cleanup

For a temporary demo, scale application workloads down first:

```sh
make runtime-scale-down
```

To remove Kubernetes workloads while keeping the GKE cluster:

```sh
kubectl delete -f infra/cloud/k8s/rendered/workloads.yaml
```

Full infrastructure cleanup should be planned carefully because Terraform state is local in this phase. Do not manually delete Terraform-managed resources unless the team records the cleanup and reconciles state afterward.

## Troubleshooting

- If `make k8s-apply` cannot create the secret, confirm `K8S_TIMESCALE_PASSWORD` is set.
- If pods cannot access GCP resources, inspect service account annotations with `kubectl describe serviceaccount -n smartcity`.
- If the writer cannot connect to TimescaleDB, inspect the `TIMESCALE_DSN` secret and verify the StatefulSet is ready.
- If Streamlit is not reachable, confirm the service exists and rerun `make k8s-port-forward-streamlit`.
