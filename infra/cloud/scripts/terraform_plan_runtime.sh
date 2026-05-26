#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tf_dir="${root_dir}/infra/cloud/terraform"
plan_file="${TF_RUNTIME_PLAN_FILE:-smartcity-runtime.tfplan}"

"${root_dir}/infra/cloud/scripts/gcp_bootstrap_check.sh"
"${root_dir}/infra/cloud/scripts/gcp_cost_guard_check.sh"
"${root_dir}/infra/cloud/scripts/terraform_check.sh"

cd "${tf_dir}"

if [[ ! -d ".terraform" ]]; then
  echo "Terraform has not been initialized yet. Run: make terraform-init" >&2
  exit 1
fi

terraform validate

terraform plan \
  -var-file=terraform.tfvars \
  -var=enable_runtime_resources=true \
  -var=enable_ci_cd_resources=true \
  -out="${plan_file}"

echo
echo "Saved runtime Terraform plan artifact: ${tf_dir}/${plan_file}"
echo "This command did not apply resources."
