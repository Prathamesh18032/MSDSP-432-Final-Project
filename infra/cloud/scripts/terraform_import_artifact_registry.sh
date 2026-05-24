#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tf_dir="${root_dir}/infra/cloud/terraform"
tfvars="${tf_dir}/terraform.tfvars"

"${root_dir}/infra/cloud/scripts/terraform_check.sh"

cd "${tf_dir}"

if [[ ! -d ".terraform" ]]; then
  echo "ERROR: Terraform has not been initialized yet. Run: make terraform-init" >&2
  exit 1
fi

project="$(awk -F= '/^[[:space:]]*gcp_project_id[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
region="$(awk -F= '/^[[:space:]]*gcp_region[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
repository="$(awk -F= '/^[[:space:]]*artifact_registry_repository[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
address="google_artifact_registry_repository.services"
resource_id="projects/${project}/locations/${region}/repositories/${repository}"

if terraform state list 2>/dev/null | grep -qx "${address}"; then
  echo "Artifact Registry repository is already imported in Terraform state: ${address}"
  exit 0
fi

echo "Importing existing Artifact Registry repository into Terraform state:"
echo "  ${address}"
echo "  ${resource_id}"
terraform import "${address}" "${resource_id}"

echo
echo "Artifact Registry import complete."
