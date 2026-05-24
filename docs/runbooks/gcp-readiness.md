# GCP Readiness Runbook

This runbook lists the prerequisites for moving from the local-first MVP to the first cloud deployment. Slice 11 was bootstrap-only. Slice 12 is the first controlled live GCP step: it creates an Artifact Registry Docker repository and publishes local images, but it does not deploy workloads.

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

Follow `docs/runbooks/gcp-console-bootstrap.md` before installing `gcloud`.

1. Create or select a GCP project in the Google Cloud Console.
2. Confirm billing is linked to that project.
3. Create a budget alert before enabling services or creating resources.
4. Confirm your own IAM access on the project.
5. Avoid creating GKE, Cloud SQL, Pub/Sub, GCS, BigQuery, service account keys, or Terraform state buckets.
6. Copy `infra/cloud/gcp.env.example` into your local `.env` values and replace `replace-me-project`.
7. Install the Google Cloud CLI.
8. Authenticate locally:

```sh
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-project-id>
gcloud config set compute/region asia-south1
```

9. Run local bootstrap checks:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
```

These checks do not create resources, enable APIs, run Terraform, or push images.

## First Live Cloud Step: Artifact Registry

After the bootstrap checks pass, use the Artifact Registry publish runbook:

```sh
make artifact-registry-create
make artifact-registry-check
make docker-build IMAGE_TAG=<tag>
make docker-tag-release IMAGE_TAG=<tag>
make docker-push IMAGE_TAG=<tag>
make artifact-registry-list
```

This creates only the Docker repository configured by `ARTIFACT_REGISTRY_REPOSITORY` and pushes the three project images. It does not create GKE, Pub/Sub, GCS, BigQuery, TimescaleDB, runtime secrets, or Terraform state.

## Pub/Sub Adapter Readiness

Slice 14 adds Pub/Sub publisher and consumer code. It is readiness-only: no topic, subscription, GKE workload, or Terraform apply is created by this slice.

Use the adapter runbook after Pub/Sub resources exist:

```sh
make pubsub-check
INGESTION_SINK=pubsub make pubsub-smoke
make consume-pubsub
```

The expected topic is `smartcity-readings` and the expected subscription is `smartcity-hot-writer`.

## First Core Terraform Apply

Slice 15 creates/imports only low-cost core resources. Follow `docs/runbooks/core-cloud-apply.md`:

```sh
make terraform-import-artifact-registry
ALLOW_TERRAFORM_APPLY_CORE=yes make terraform-apply-core
make gcp-core-check
make pubsub-hotpath-smoke
```

This still does not create GKE, Cloud SQL, service account keys, remote Terraform state, Workload Identity bindings, or always-on workloads.

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
4. For Slice 13, use local state only and run the Terraform plan review workflow in `docs/runbooks/terraform-plan-review.md`.
5. Run `terraform plan` and review resource count, IAM changes, and costs.
6. Publish container images.
7. Create runtime secrets.
8. Apply Kubernetes manifests to the development namespace.
9. Validate Pub/Sub publishing, hot write path, cold export, Grafana, and Streamlit.
