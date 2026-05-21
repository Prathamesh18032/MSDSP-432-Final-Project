# GCP Readiness Runbook

This runbook lists the prerequisites for moving from the local-first MVP to the first cloud deployment. Slice 9 does not create cloud resources; it prepares the reviewable scaffolding.

## Required Before Terraform

- Confirm the target `GCP_PROJECT_ID` and `GCP_REGION`.
- Confirm billing is enabled and a budget alert exists.
- Confirm the team member running Terraform has permission to manage IAM, Pub/Sub, GCS, BigQuery, Artifact Registry, and GKE.
- Install and authenticate `gcloud`.
- Install Terraform locally or configure it in CI.
- Decide where Terraform state will live before the first real apply.

## Required APIs

The Terraform scaffold includes API enablement for:

- Artifact Registry
- BigQuery
- GKE / Container API
- IAM
- Pub/Sub
- Cloud Storage

## Required Runtime Secrets

Do not commit secrets. Create runtime secrets through Secret Manager, Kubernetes Secrets, or the team-approved secret workflow.

Expected secret keys:

- `OPENAQ_API_KEY`
- `TIMESCALE_DSN`
- `GRAFANA_ADMIN_USER`
- `GRAFANA_ADMIN_PASSWORD`

## Cost Cautions

- Keep GKE Autopilot workloads small while validating.
- Use one development namespace first.
- Keep GCS lifecycle rules enabled for cold data.
- Avoid public buckets and public dashboards.
- Stop or scale down nonessential workloads after demos.

## First Cloud Validation Sequence

1. Run `make cloud-check`.
2. Replace Terraform example values with real project values.
3. Run `terraform fmt -check -recursive infra/cloud/terraform`.
4. Run `terraform init` only after backend/state ownership is agreed.
5. Run `terraform plan` and review resource count, IAM changes, and costs.
6. Publish container images.
7. Create runtime secrets.
8. Apply Kubernetes manifests to the development namespace.
9. Validate Pub/Sub publishing, hot write path, cold export, Grafana, and Streamlit.
