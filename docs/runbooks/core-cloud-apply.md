# Core Cloud Apply Runbook

Slice 15 is the first controlled Terraform apply for low-cost core GCP resources. It creates Pub/Sub, GCS, BigQuery, service accounts, IAM bindings, and API enablement. It imports the existing Artifact Registry repository from Slice 12 before apply.

This slice does not create GKE, Cloud SQL, remote Terraform state, service account keys, Workload Identity bindings, or always-on workloads.

References:

- Terraform import: <https://developer.hashicorp.com/terraform/cli/commands/import>
- Artifact Registry Terraform resource: <https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository>
- Pub/Sub dead-letter topics: <https://docs.cloud.google.com/pubsub/docs/dead-letter-topics>
- Pub/Sub subscription Terraform resource: <https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_subscription>

## Prerequisites

Confirm local cloud setup and budget guard values:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-check
```

Confirm local Terraform variables exist:

```sh
cp infra/cloud/terraform/terraform.tfvars.example infra/cloud/terraform/terraform.tfvars
make terraform-check
```

Expected project values:

```sh
GCP_PROJECT_ID=smartcity-zero-disk-iot-pa
GCP_REGION=asia-south1
GCP_PUBSUB_TOPIC=smartcity-readings
GCP_PUBSUB_DLQ_TOPIC=smartcity-dlq
GCP_PUBSUB_SUBSCRIPTION=smartcity-hot-writer
GCS_BUCKET=smartcity-zero-disk-iot-pa-cold
BIGQUERY_DATASET=smartcity_iot
ARTIFACT_REGISTRY_REPOSITORY=smartcity
```

## Apply Sequence

Initialize Terraform and import the Artifact Registry repository that already exists from Slice 12:

```sh
make terraform-init
make terraform-import-artifact-registry
```

Review and apply the core plan:

```sh
make terraform-validate
make terraform-plan
make terraform-show-plan
ALLOW_TERRAFORM_APPLY_CORE=yes make terraform-apply-core
```

The apply target creates a fresh plan immediately before applying. The `ALLOW_TERRAFORM_APPLY_CORE=yes` guard is required every time.

## Post-Apply Validation

```sh
make gcp-core-check
make pubsub-check
```

These checks verify:

- Pub/Sub topic, dead-letter topic, and hot-writer subscription.
- GCS cold-storage bucket.
- BigQuery dataset and external table.
- Artifact Registry repository.
- Google service accounts for ingestor, writer, and analytics.

Workload Identity IAM bindings are intentionally disabled by default with `enable_workload_identity_bindings = false` because the GKE identity pool does not exist until a later deployment slice creates a cluster.

## Image Publish

Publish updated images after Slice 14 added the Pub/Sub consumer binary:

```sh
make docker-build IMAGE_TAG=slice15
make docker-smoke IMAGE_TAG=slice15
make docker-push IMAGE_TAG=slice15
make artifact-registry-list
```

## Hot-Path Smoke

Start the local hot store:

```sh
make run-local
```

Publish one multi-source poll to Pub/Sub, then consume a bounded number of messages into local TimescaleDB:

```sh
INGESTION_SINK=pubsub make pubsub-smoke
make consume-pubsub-once
```

Or run the combined target:

```sh
make pubsub-hotpath-smoke
```

The consumer uses:

```sh
PUBSUB_CONSUME_LIMIT=10
PUBSUB_CONSUME_TIMEOUT_SECONDS=60
```

## Safety And Cleanup

Core resources are small, but they are real cloud resources. Keep the budget alert active and avoid creating GKE or Cloud SQL in this slice.

If cleanup is needed, do not run an automated destroy casually. Review the Terraform state and delete resources deliberately through a separate team-approved cleanup slice or manual console cleanup.
