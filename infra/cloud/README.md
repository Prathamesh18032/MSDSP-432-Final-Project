# Cloud Infrastructure Readiness

This directory contains the cloud-ready foundation for the Smart City Zero-Disk IoT platform. Core resources can be applied through guarded Make targets, while runtime resources remain behind an explicit GKE apply guard because they can create ongoing cost.

## What Is Included

- `terraform/`: GCP resources for Pub/Sub, dead-letter routing, GCS cold storage, video object notifications, BigQuery external analytics, Artifact Registry, service accounts, and gated GKE Autopilot runtime.
- `k8s/`: renderable GKE manifests for self-hosted TimescaleDB, the multi-source ingestor, Pub/Sub hot writer, optional video AI agent, cold export CronJob, Streamlit, and guarded Streamlit-only public demo ingress.
- Final cleanup is documented in `docs/runbooks/cloud-teardown.md` and exposed through guarded `make cloud-teardown-*` targets.
- Local container image packaging uses the same Artifact Registry naming convention through `make docker-build`, `make docker-tag-release`, and `make docker-push`.
- Terraform plan review uses local, ignored `terraform.tfvars` and `smartcity.tfplan` artifacts.

## What Is Not Included Yet

- No Terraform backend or remote state configuration.
- No cloud workload deployment pipeline.
- No committed secrets, service account JSON keys, or OpenAQ API key.
- No Cloud SQL, external Timescale service, or GKE workload deployment without explicit commands. Public ingress is Streamlit-only and requires `ALLOW_PUBLIC_INGRESS=yes`.
- No remote Terraform backend yet; state and plan artifacts remain local and ignored.

## Future Rollout Order

1. Complete the web-console bootstrap in `docs/runbooks/gcp-console-bootstrap.md`: project, billing, IAM, and budget alerts.
2. Enable required APIs and authenticate Terraform locally or through CI.
3. Create local `infra/cloud/terraform/terraform.tfvars`.
4. Run `terraform fmt`, `terraform init`, and `terraform plan` for review.
5. Publish ingestor, writer, Streamlit, and optional video-agent images to Artifact Registry.
6. Review the runtime plan with `make terraform-plan-runtime`.
7. Apply runtime resources only with `ALLOW_TERRAFORM_APPLY_RUNTIME=yes make terraform-apply-runtime`.
8. Render manifests with `make k8s-render`, create runtime secrets, and deploy to the non-production namespace.
9. Validate ingestion, TimescaleDB, cold export, and Streamlit through the GKE runtime runbook.

## Local Validation

From the repository root:

```sh
make cloud-check
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
make artifact-registry-create
make artifact-registry-check
make docker-build IMAGE_TAG=<tag>
make docker-tag-release IMAGE_TAG=<tag>
make docker-push IMAGE_TAG=<tag>
make artifact-registry-list
make terraform-check
make terraform-init
make terraform-validate
make terraform-plan
make terraform-show-plan
make terraform-import-artifact-registry-preview
make terraform-import-artifact-registry
ALLOW_TERRAFORM_APPLY_CORE=yes make terraform-apply-core
make gcp-core-check
make pubsub-check
make bigquery-cold-check
make terraform-plan-runtime
ALLOW_TERRAFORM_APPLY_RUNTIME=yes make terraform-apply-runtime
make gke-get-credentials
make k8s-render
make k8s-apply
make k8s-status
make k8s-smoke
make k8s-logs
make k8s-backup-once
make k8s-backup-check
make k8s-restore-test
make k8s-restore-check
make k8s-restore-clean
make runtime-health
make runtime-cost-check
make runtime-cost-report
make runtime-cost-guard
make runtime-promote-latest
make runtime-release-check
make ci-publish-check
ALLOW_PUBLIC_INGRESS=yes make public-demo-render
ALLOW_PUBLIC_INGRESS=yes make public-demo-apply
make public-demo-status
make public-demo-url
make public-demo-smoke
make public-demo-disable
make demo-live-start
make demo-live-stop
make observability-check
make runtime-live-smoke
make k8s-port-forward-streamlit
make runtime-check
```

`cloud-check` validates expected cloud files and runs optional Terraform/Kubernetes checks only when the related tools are installed. The bootstrap preview targets verify local configuration and print future commands. `artifact-registry-create` is the only Slice 12 setup target that creates a live cloud resource: one Artifact Registry Docker repository in `asia-south1`, after enabling the Artifact Registry API. The image push targets publish containers only; they do not deploy workloads or run Terraform.

The final teardown targets are destructive and guarded. Start with `make cloud-teardown-inventory`, then follow `docs/runbooks/cloud-teardown.md` for the freeze, data-emptying, destroy, verification, billing unlink, and project shutdown order.

The Terraform targets support Slice 13 plan review only. They initialize, validate, and save a local plan artifact, but they do not apply resources. The existing Artifact Registry repository from Slice 12 must be imported before any later apply.

`make pubsub-check` verifies that the configured topic and subscription already exist. It is read-only and intentionally does not create Pub/Sub resources.

Slice 15 adds the first guarded apply path for low-cost core resources. `make terraform-apply-core` requires `ALLOW_TERRAFORM_APPLY_CORE=yes`, imports must be handled first, and the core apply still excludes GKE, Cloud SQL, remote state, service account keys, and public ingress.

Slice 16 adds the first cloud cold-path validation. `make export-cold-gcs` uploads Parquet files to the existing GCS bucket, and `make bigquery-cold-check` verifies the external table is queryable. These commands do not create additional infrastructure.

Slice 17 adds the first gated runtime path. `make terraform-plan-runtime` reviews GKE Autopilot and Workload Identity changes. `ALLOW_TERRAFORM_APPLY_RUNTIME=yes make terraform-apply-runtime` creates runtime infrastructure only when intentionally allowed. TimescaleDB remains the hot store and is deployed as an internal Kubernetes StatefulSet with a PVC.

Slice 18 adds live runtime hardening. Runtime Terraform also provisions GitHub Actions Workload Identity Federation for image publishing. Kubernetes manifests include a TimescaleDB backup CronJob, and operations scripts validate logs, workload health, Pub/Sub, GCS, BigQuery, and backup presence.

Slice 19 adds reliability and demo polish. Restore tests run only in a disposable namespace, runtime health checks surface failed jobs/restarts/PVCs/latest objects/image tags, and scale/demo commands help reduce cost after presentations without deleting the hot TimescaleDB PVC.

Slice 20 adds public demo and enterprise operations. Public ingress exposes Streamlit with a demo password and can expose Grafana separately with login-protected credentials for demo week. Release promotion targets deploy CI-published images manually, runtime modes make demo/idle transitions repeatable, and evidence targets capture sanitized validation output.

The optional video AI agent adds a small Cloud Storage media inbox (`video_inbox/`), a video Pub/Sub notification topic/subscription, and a disabled-by-default GKE deployment. Set `VIDEO_AGENT_REPLICAS=1` only for demos that need active inference over uploaded public sample images or extracted frames.
