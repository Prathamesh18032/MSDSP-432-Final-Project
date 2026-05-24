#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tf_dir="${root_dir}/infra/cloud/terraform"
plan_file="${TF_PLAN_FILE:-smartcity.tfplan}"

"${root_dir}/infra/cloud/scripts/terraform_check.sh"

cd "${tf_dir}"

if [[ ! -d ".terraform" ]]; then
  echo "Terraform has not been initialized yet. Run: make terraform-init" >&2
  exit 1
fi

echo "NOTE: Slice 12 Artifact Registry repository may already exist outside Terraform."
echo "Before any future apply, review: make terraform-import-artifact-registry-preview"
echo

terraform plan \
  -var-file=terraform.tfvars \
  -out="${plan_file}"

echo
echo "Saved Terraform plan artifact: ${tf_dir}/${plan_file}"
echo "This command did not apply resources."
