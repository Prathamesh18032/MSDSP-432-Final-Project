# Cloud Infrastructure Readiness

This directory contains cloud-ready scaffolding for the Smart City Zero-Disk IoT platform. It is intentionally readiness-only: do not run `terraform apply` or deploy Kubernetes manifests until the team has confirmed a GCP project, billing, IAM permissions, image publishing, and runtime secret handling.

## What Is Included

- `terraform/`: GCP resource scaffold for Pub/Sub, dead-letter routing, GCS cold storage, BigQuery external analytics, Artifact Registry, service accounts, and Workload Identity IAM bindings.
- `k8s/`: GKE manifest scaffold for the multi-source ingestor, cold export writer job, Streamlit, and Grafana.
- Local container image packaging uses the same Artifact Registry naming convention through `make docker-build`, `make docker-tag-release`, and `make docker-push`.

## What Is Not Included Yet

- No Terraform backend or remote state configuration.
- No live GCP apply/plan workflow.
- No cloud workload deployment pipeline.
- No committed secrets, service account JSON keys, or OpenAQ API key.
- No final hot-store decision for cloud TimescaleDB. Future deployment should provide `TIMESCALE_DSN` through `smartcity-runtime-secrets`.

## Future Rollout Order

1. Complete the web-console bootstrap in `docs/runbooks/gcp-console-bootstrap.md`: project, billing, IAM, and budget alerts.
2. Enable required APIs and authenticate Terraform locally or through CI.
3. Replace placeholder values in `terraform.tfvars`.
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
```

`cloud-check` validates expected cloud files and runs optional Terraform/Kubernetes checks only when the related tools are installed. The bootstrap preview targets verify local configuration and print future commands. `artifact-registry-create` is the only Slice 12 setup target that creates a live cloud resource: one Artifact Registry Docker repository in `asia-south1`, after enabling the Artifact Registry API. The image push targets publish containers only; they do not deploy workloads or run Terraform.
