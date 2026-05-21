# Terraform Scaffold

This Terraform is a readiness scaffold for the future GCP deployment. It should be reviewed and customized before any `terraform init`, `terraform plan`, or `terraform apply`.

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

## Before First Real Plan

1. Copy `terraform.tfvars.example` to a local uncommitted `terraform.tfvars`.
2. Replace every `replace-me-*` value.
3. Confirm Terraform state ownership and backend.
4. Confirm GCP billing, APIs, IAM permissions, and budget alerts.
5. Run `terraform init` and `terraform plan` only after the above are agreed by the team.
