# Terraform Plan Review Runbook

Slice 13 creates a reviewable Terraform plan for core GCP resources. It does not run `terraform apply` and should not create GKE, Pub/Sub, GCS, BigQuery, or IAM resources.

References:

- Google project services: <https://registry.terraform.io/providers/hashicorp/google/latest/docs/guides/google_project_service>
- Artifact Registry repository import: <https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/artifact_registry_repository>
- Pub/Sub topic: <https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/pubsub_topic>
- BigQuery external table: <https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/bigquery_table>

## One-Time Local Setup

Install Terraform locally before running the plan workflow:

```sh
brew tap hashicorp/tap
brew install hashicorp/tap/terraform
terraform version
```

Confirm Google Cloud is still configured:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
```

## Local Variables

Create a local uncommitted tfvars file:

```sh
cp infra/cloud/terraform/terraform.tfvars.example infra/cloud/terraform/terraform.tfvars
```

Expected Slice 13 values:

```hcl
gcp_project_id = "smartcity-zero-disk-iot-pa"
gcp_region     = "asia-south1"
gcs_bucket     = "smartcity-zero-disk-iot-pa-cold"
```

The `terraform.tfvars` file is ignored by Git.

## Existing Artifact Registry Import Preview

Slice 12 already created Artifact Registry repository `smartcity`. Terraform must import it before any future apply:

```sh
make terraform-import-artifact-registry-preview
```

This target prints the command only. It does not modify Terraform state.

## Plan Workflow

```sh
make terraform-check
make terraform-init
make terraform-validate
make terraform-plan
make terraform-show-plan
```

The saved plan artifact is ignored by Git. Review the plan for resource count, names, IAM bindings, API enablement, GCS lifecycle rules, Pub/Sub dead-letter behavior, and BigQuery external table configuration.

Slice 13 validation produced a plan with `27 to add, 0 to change, 0 to destroy`. That count includes the existing Artifact Registry repository because it has not been imported into Terraform state yet.

## Safety Rules

- Do not run `terraform apply` in Slice 13.
- Do not commit `.terraform/`, `terraform.tfvars`, state files, or plan files.
- Do not create a remote backend yet.
- Do not create service account JSON keys.
- If the plan proposes creating the existing Artifact Registry repository, stop and import it before any future apply.
