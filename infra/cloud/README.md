# Cloud Infrastructure Readiness

This directory contains cloud-ready scaffolding for the Smart City Zero-Disk IoT platform. It is intentionally readiness-only: do not run `terraform apply` or deploy Kubernetes manifests until the team has confirmed a GCP project, billing, IAM permissions, image publishing, and runtime secret handling.

## What Is Included

- `terraform/`: GCP resource scaffold for Pub/Sub, dead-letter routing, GCS cold storage, BigQuery external analytics, Artifact Registry, service accounts, and Workload Identity IAM bindings.
- `k8s/`: GKE manifest scaffold for the multi-source ingestor, Pub/Sub hot writer, cold export writer job, Streamlit, and Grafana.
- Local container image packaging uses the same Artifact Registry naming convention through `make docker-build`, `make docker-tag-release`, and `make docker-push`.
- Terraform plan review uses local, ignored `terraform.tfvars` and `smartcity.tfplan` artifacts.

## What Is Not Included Yet

- No Terraform backend or remote state configuration.
- No live GCP apply/plan workflow.
- No cloud workload deployment pipeline.
- No committed secrets, service account JSON keys, or OpenAQ API key.
- No final hot-store decision for cloud TimescaleDB. Future deployment should provide `TIMESCALE_DSN` through `smartcity-runtime-secrets`.

## Future Rollout Order

1. Complete the web-console bootstrap in `docs/runbooks/gcp-console-bootstrap.md`: project, billing, IAM, and budget alerts.
2. Enable required APIs and authenticate Terraform locally or through CI.
3. Create local `infra/cloud/terraform/terraform.tfvars`.
4. Run `terraform fmt`, `terraform init`, and `terraform plan` for review.
5. Publish ingestor, writer, and Streamlit images to Artifact Registry.
6. Create Kubernetes runtime secrets outside the repository.
7. Deploy GKE manifests to a non-production namespace.
8. Validate ingestion, cold export, Grafana, and Streamlit against cloud resources.

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
```

`cloud-check` validates expected cloud files and runs optional Terraform/Kubernetes checks only when the related tools are installed. The bootstrap preview targets verify local configuration and print future commands. `artifact-registry-create` is the only Slice 12 setup target that creates a live cloud resource: one Artifact Registry Docker repository in `asia-south1`, after enabling the Artifact Registry API. The image push targets publish containers only; they do not deploy workloads or run Terraform.

The Terraform targets support Slice 13 plan review only. They initialize, validate, and save a local plan artifact, but they do not apply resources. The existing Artifact Registry repository from Slice 12 must be imported before any later apply.

`make pubsub-check` verifies that the configured topic and subscription already exist. It is read-only and intentionally does not create Pub/Sub resources.

Slice 15 adds the first guarded apply path for low-cost core resources. `make terraform-apply-core` requires `ALLOW_TERRAFORM_APPLY_CORE=yes`, imports must be handled first, and the current Terraform config still excludes GKE, Cloud SQL, remote state, service account keys, and Workload Identity bindings. Workload Identity bindings stay disabled until a GKE identity pool exists.

Slice 16 adds the first cloud cold-path validation. `make export-cold-gcs` uploads Parquet files to the existing GCS bucket, and `make bigquery-cold-check` verifies the external table is queryable. These commands do not create additional infrastructure.
