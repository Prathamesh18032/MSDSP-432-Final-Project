# Cloud Infrastructure Readiness

This directory contains cloud-ready scaffolding for the Smart City Zero-Disk IoT platform. It is intentionally readiness-only: do not run `terraform apply` or deploy Kubernetes manifests until the team has confirmed a GCP project, billing, IAM permissions, image publishing, and runtime secret handling.

## What Is Included

- `terraform/`: GCP resource scaffold for Pub/Sub, dead-letter routing, GCS cold storage, BigQuery external analytics, Artifact Registry, service accounts, and Workload Identity IAM bindings.
- `k8s/`: GKE manifest scaffold for the multi-source ingestor, cold export writer job, Streamlit, and Grafana.

## What Is Not Included Yet

- No Terraform backend or remote state configuration.
- No live GCP apply/plan workflow.
- No container image build or publish pipeline.
- No committed secrets, service account JSON keys, or OpenAQ API key.
- No final hot-store decision for cloud TimescaleDB. Future deployment should provide `TIMESCALE_DSN` through `smartcity-runtime-secrets`.

## Future Rollout Order

1. Confirm GCP project, billing, owner/editor permissions, and budget alerts.
2. Enable required APIs and authenticate Terraform locally or through CI.
3. Replace placeholder values in `terraform.tfvars`.
4. Run `terraform fmt`, `terraform init`, and `terraform plan` for review.
5. Add image build/publish workflow for ingestor, writer, and Streamlit containers.
6. Create Kubernetes runtime secrets outside the repository.
7. Deploy GKE manifests to a non-production namespace.
8. Validate ingestion, cold export, Grafana, and Streamlit against cloud resources.

## Local Validation

From the repository root:

```sh
make cloud-check
```

`cloud-check` validates expected cloud files and runs optional Terraform/Kubernetes checks only when the related tools are installed. It does not contact GCP.
