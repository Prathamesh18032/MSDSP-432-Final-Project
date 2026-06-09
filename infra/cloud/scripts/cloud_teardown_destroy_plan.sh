#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/cloud_teardown_lib.sh"

project="$(cloud_teardown_project)"
plan_file="${CLOUD_TEARDOWN_DESTROY_PLAN_FILE:-smartcity-destroy.tfplan}"

cloud_teardown_assert_target_project "${project}"
cloud_teardown_require_cmd terraform

if [[ ! -d "${CLOUD_TEARDOWN_TF_DIR}/.terraform" ]]; then
  cloud_teardown_fail "Terraform has not been initialized yet. Run: make terraform-init"
fi

if [[ ! -f "${CLOUD_TEARDOWN_TFVARS}" ]]; then
  cloud_teardown_fail "Missing ${CLOUD_TEARDOWN_TFVARS}."
fi

terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" validate

terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" plan \
  -destroy \
  -var-file=terraform.tfvars \
  -var=enable_runtime_resources=true \
  -var=enable_ci_cd_resources=true \
  -out="${plan_file}"

echo
echo "Saved destroy plan artifact: ${CLOUD_TEARDOWN_TF_DIR}/${plan_file}"
echo "Review the plan before running: ALLOW_CLOUD_TEARDOWN_DESTROY=yes CLOUD_TEARDOWN_ACK=destroy-${project} make cloud-teardown-destroy"
