#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tf_dir="${root_dir}/infra/cloud/terraform"
plan_file="${TF_RUNTIME_PLAN_FILE:-smartcity-runtime.tfplan}"

if [[ "${ALLOW_TERRAFORM_APPLY_RUNTIME:-}" != "yes" ]]; then
  echo "ERROR: Refusing to apply runtime Terraform without ALLOW_TERRAFORM_APPLY_RUNTIME=yes." >&2
  echo "This target can create ongoing-cost runtime resources such as a GKE Autopilot cluster." >&2
  echo "It does not create Cloud SQL, external Timescale services, service account keys, or Streamlit public ingress." >&2
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

state_list="$(terraform state list 2>/dev/null || true)"
if ! grep -qx "google_artifact_registry_repository.services" <<<"${state_list}"; then
  echo "ERROR: Existing Artifact Registry repository is not imported into Terraform state." >&2
  echo "Run: make terraform-import-artifact-registry" >&2
  exit 1
fi

terraform validate

echo "Creating a fresh runtime apply plan at ${tf_dir}/${plan_file}."
terraform plan \
  -var-file=terraform.tfvars \
  -var=enable_runtime_resources=true \
  -var=enable_ci_cd_resources=true \
  -out="${plan_file}"

terraform apply "${plan_file}"

echo
echo "Runtime Terraform apply complete. GKE runtime and GitHub Actions OIDC resources are enabled; TimescaleDB is deployed later through Kubernetes manifests."
