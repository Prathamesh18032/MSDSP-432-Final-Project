# Artifact Registry Publish Runbook

This runbook is for Slice 12, the first controlled live GCP step. It publishes container images to Artifact Registry in `asia-south1` and intentionally does not create GKE, Pub/Sub, GCS, BigQuery, or Terraform state.

References:

- Google Cloud CLI install: <https://cloud.google.com/sdk/docs/install>
- Artifact Registry Docker push and pull: <https://cloud.google.com/artifact-registry/docs/docker/pushing-and-pulling>
- Artifact Registry repositories: <https://cloud.google.com/artifact-registry/docs/repositories>
- Cloud Billing budgets: <https://cloud.google.com/billing/docs/how-to/budgets>

## One-Time Account Setup

Start with the web-console checklist in `docs/runbooks/gcp-console-bootstrap.md`. Create the project, link billing, add a budget alert, and confirm IAM access before installing the Google Cloud CLI.

Then install the Google Cloud CLI and authenticate:

```sh
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-project-id>
gcloud config set compute/region asia-south1
```

For this project, the recommended initial budget alert is `25` USD. Do not manually create GKE, Pub/Sub, GCS, BigQuery, Cloud SQL, or Terraform resources for Slice 12.

## Local Environment

Copy the cloud values from `infra/cloud/gcp.env.example` into your local `.env` and replace project-specific values:

```sh
GCP_PROJECT_ID=<your-project-id>
GCP_REGION=asia-south1
BUDGET_ALERT_AMOUNT_USD=25
ARTIFACT_REGISTRY_REPOSITORY=smartcity
IMAGE_REGISTRY=asia-south1-docker.pkg.dev/<your-project-id>/smartcity
IMAGE_TAG=<release-tag-or-short-sha>
```

Do not commit `.env`, credentials, service account keys, or real secrets.

## Preflight Checks

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
```

These checks and previews are read-only. They do not create cloud resources or push images.

## Create Repository

```sh
make artifact-registry-create
make artifact-registry-check
```

`artifact-registry-create` enables `artifactregistry.googleapis.com`, creates the Docker repository if it is missing, and configures Docker auth for `asia-south1-docker.pkg.dev`.

## Build and Push Images

Use a reviewable tag such as the PR number, date, or short commit SHA:

```sh
make docker-build IMAGE_TAG=<tag>
make docker-smoke IMAGE_TAG=<tag>
make docker-tag-release IMAGE_TAG=<tag>
make docker-push IMAGE_TAG=<tag>
make artifact-registry-list
```

The expected images are:

- `smartcity-ingestor`
- `smartcity-writer`
- `smartcity-streamlit`

## Safety Boundaries

- This slice does not run Terraform.
- This slice does not deploy Kubernetes manifests.
- This slice does not create always-on compute.
- This slice does not create Pub/Sub, GCS, BigQuery, or GKE resources.
- If a command asks for confirmation outside this documented flow, stop and review it before continuing.
