#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tf_dir="${root_dir}/infra/cloud/terraform"
plan_file="${TF_PLAN_FILE:-smartcity.tfplan}"

if [[ "${ALLOW_TERRAFORM_APPLY_CORE:-}" != "yes" ]]; then
  echo "ERROR: Refusing to apply Terraform without ALLOW_TERRAFORM_APPLY_CORE=yes." >&2
  echo "This target creates low-cost core GCP resources: Pub/Sub, GCS, BigQuery, IAM/service accounts, and API enablement." >&2
  echo "It does not create GKE, Cloud SQL, service account keys, or remote Terraform state." >&2
  exit 1
fi

"${root_dir}/infra/cloud/scripts/gcp_bootstrap_check.sh"
"${root_dir}/infra/cloud/scripts/gcp_cost_guard_check.sh"
"${root_dir}/infra/cloud/scripts/terraform_check.sh"

cd "${tf_dir}"

if [[ ! -d ".terraform" ]]; then
  echo "ERROR: Terraform has not been initialized yet. Run: make terraform-init" >&2
  exit 1
fi

if ! terraform state list 2>/dev/null | grep -qx "google_artifact_registry_repository.services"; then
  echo "ERROR: Existing Artifact Registry repository is not imported into Terraform state." >&2
  echo "Run: make terraform-import-artifact-registry" >&2
  exit 1
fi

terraform validate

echo "Creating a fresh core apply plan at ${tf_dir}/${plan_file}."
terraform plan -var-file=terraform.tfvars -out="${plan_file}"

terraform apply "${plan_file}"

echo
echo "Core Terraform apply complete. No GKE or Cloud SQL resources are part of this Terraform config."
