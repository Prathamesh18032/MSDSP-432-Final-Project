# GCP Console Bootstrap Runbook

Use this runbook before installing or authenticating the Google Cloud CLI. It is intended for a fresh Google Cloud account and keeps Slice 12 limited to Artifact Registry image publishing in `asia-south1`.

References:

- Google Cloud Console: <https://console.cloud.google.com/>
- Projects: <https://cloud.google.com/resource-manager/docs/creating-managing-projects>
- Billing budgets: <https://cloud.google.com/billing/docs/how-to/budgets>
- Artifact Registry IAM roles: <https://cloud.google.com/iam/docs/roles-permissions/artifactregistry>

## 1. Create the Project

1. Open the Google Cloud Console.
2. Use the project selector in the top bar.
3. Choose `New Project`.
4. Use this project name:

```text
smartcity-zero-disk-iot
```

5. Use a unique project ID, for example:

```text
smartcity-zero-disk-iot-<your-initials>
```

6. Save the exact project ID. This value becomes `GCP_PROJECT_ID` in local `.env`.

Google Cloud project IDs are globally unique and cannot be changed after creation, so avoid temporary names like `test-project`.

## 2. Link Billing

1. Open `Billing`.
2. Confirm the free trial billing account is active.
3. Link the new smart city project to that billing account if Google did not link it automatically.
4. Do not create compute, storage, database, or Kubernetes resources during this step.

## 3. Create a Budget Alert

1. Open `Billing` -> `Budgets & alerts`.
2. Choose `Create budget`.
3. Scope the budget to the new smart city project only.
4. Set the initial budget amount to:

```text
25 USD
```

5. Keep the default alert thresholds if shown.
6. Save the budget.

Record this locally as:

```sh
BUDGET_ALERT_AMOUNT_USD=25
```

## 4. Confirm IAM Access

1. Open `IAM & Admin` -> `IAM`.
2. Confirm your Google account is listed on the project.
3. For your own fresh personal project, `Owner` is acceptable during bootstrap.
4. Do not give teammates `Owner` by default. For later team access, prefer narrower roles such as Artifact Registry Reader or Writer.

## 5. Avoid Creating Other Resources

Do not create these from the web console for Slice 12:

- GKE clusters.
- Cloud SQL instances.
- Pub/Sub topics.
- GCS buckets.
- BigQuery datasets.
- Service account JSON keys.
- Terraform state buckets.

The first live resource should be the Artifact Registry Docker repository created by the repo command `make artifact-registry-create`.

## 6. Optional API Check

Open `APIs & Services` -> `Enabled APIs & services`.

You do not need to enable APIs manually for Slice 12. The local command `make artifact-registry-create` enables only `artifactregistry.googleapis.com` when you are ready.

## 7. Continue to CLI Setup

After the web-console checklist is complete, install the Google Cloud CLI and run:

```sh
gcloud auth login
gcloud auth application-default login
gcloud config set project <your-project-id>
gcloud config set compute/region asia-south1
```

Then update local `.env`:

```sh
GCP_PROJECT_ID=<your-project-id>
GCP_REGION=asia-south1
BUDGET_ALERT_AMOUNT_USD=25
ARTIFACT_REGISTRY_REPOSITORY=smartcity
IMAGE_REGISTRY=asia-south1-docker.pkg.dev/<your-project-id>/smartcity
IMAGE_TAG=slice12
```

Run the repo checks before creating anything:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
```
