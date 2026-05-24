# Terraform Scaffold

This Terraform models the future GCP deployment and is currently used for plan review only. Slice 13 allows `terraform init`, `terraform validate`, and `terraform plan`, but still forbids `terraform apply`.

## Resources Modeled

- Required GCP service APIs.
- Pub/Sub topic, dead-letter topic, and hot-writer subscription.
- GCS bucket for partitioned Parquet cold storage.
- BigQuery dataset and external table placeholder over the Parquet layout.
- Artifact Registry Docker repository.
- Google service accounts for ingestor, writer, and analytics workloads.
- IAM bindings for Pub/Sub, GCS, BigQuery, and GKE Workload Identity Federation.
- Pub/Sub service-agent IAM for future dead-letter routing.

## Safe Local Check

```sh
make cloud-check
```

This may run `terraform fmt -check -recursive infra/cloud/terraform` when Terraform is installed. It does not initialize providers or contact GCP.

## Slice 13 Plan Workflow

1. Copy `terraform.tfvars.example` to local uncommitted `terraform.tfvars`.
2. Keep `gcp_project_id = "smartcity-zero-disk-iot-pa"`.
3. Keep `gcp_region = "asia-south1"`.
4. Keep a globally unique bucket name such as `smartcity-zero-disk-iot-pa-cold`.
5. Run:

```sh
make terraform-check
make terraform-init
make terraform-validate
make terraform-plan
make terraform-show-plan
```

The saved plan artifact is local and ignored by Git. This workflow does not apply resources.

## Existing Artifact Registry Repository

Slice 12 created Artifact Registry repository `smartcity` outside Terraform so container images could be published. Before any future `terraform apply`, import that repository into local or remote Terraform state:

```sh
make terraform-import-artifact-registry-preview
```

The preview prints the exact `terraform import` command. Do not apply this Terraform until that ownership gap is handled.

## Before First Apply

- Agree where Terraform state will live.
- Import existing Artifact Registry repository `smartcity`.
- Review the saved plan with the team.
- Confirm budget alert and enabled API cost implications.
- Confirm IAM changes, Pub/Sub resources, GCS bucket name, and BigQuery dataset name.
- Only then consider `terraform apply` in a later slice.
