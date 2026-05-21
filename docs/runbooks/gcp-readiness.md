# GCP Readiness Runbook

This runbook lists the prerequisites for moving from the local-first MVP to the first cloud deployment. Slice 11 is bootstrap-only: it helps verify your local setup and project choices, but it does not create cloud resources.

## Region Choice

Use `asia-south1` for the India/Mumbai default:

```sh
GCP_REGION=asia-south1
IMAGE_REGISTRY=asia-south1-docker.pkg.dev/<your-project-id>/smartcity
```

Keep this aligned across `.env`, Terraform variables, image tags, and future Artifact Registry commands.

## Required Before Terraform

- Confirm the target `GCP_PROJECT_ID` and `GCP_REGION`.
- Confirm billing is enabled and a budget alert exists.
- Confirm the team member running Terraform has permission to manage IAM, Pub/Sub, GCS, BigQuery, Artifact Registry, and GKE.
- Install and authenticate `gcloud`.
- Install Terraform locally or configure it in CI.
- Decide where Terraform state will live before the first real apply.

## Fresh Account Bootstrap

1. Create or select a GCP project in the Google Cloud Console.
2. Confirm billing is linked to that project.
3. Create a budget alert before enabling services or creating resources.
4. Copy `infra/cloud/gcp.env.example` into your local `.env` values and replace `replace-me-project`.
5. Install the Google Cloud CLI.
6. Authenticate locally:

```sh
gcloud auth login
gcloud config set project <your-project-id>
gcloud config set compute/region asia-south1
```

7. Run local bootstrap checks:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
```

These checks do not create resources, enable APIs, run Terraform, or push images.

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
