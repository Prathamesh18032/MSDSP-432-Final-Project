#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/cloud_teardown_lib.sh"

project="$(cloud_teardown_project)"
plan_file="${CLOUD_TEARDOWN_DESTROY_PLAN_FILE:-smartcity-destroy.tfplan}"

cloud_teardown_assert_target_project "${project}"
cloud_teardown_require_cmd terraform
cloud_teardown_require_ack "ALLOW_CLOUD_TEARDOWN_DESTROY" "yes" "Refusing to destroy Terraform-managed cloud resources without explicit teardown acknowledgement."
cloud_teardown_require_ack "CLOUD_TEARDOWN_ACK" "destroy-${project}" "Refusing to destroy the wrong project."

if [[ ! -d "${CLOUD_TEARDOWN_TF_DIR}/.terraform" ]]; then
  cloud_teardown_fail "Terraform has not been initialized yet. Run: make terraform-init"
fi

if [[ "${CLOUD_TEARDOWN_APPLY_SAVED_PLAN:-yes}" == "yes" && -f "${CLOUD_TEARDOWN_TF_DIR}/${plan_file}" ]]; then
  terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" apply "${plan_file}"
else
  terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" destroy \
    -var-file=terraform.tfvars \
    -var=enable_runtime_resources=true \
    -var=enable_ci_cd_resources=true \
    -auto-approve
fi

cat <<EOF

Terraform destroy phase completed for ${project}.
Next:
  make cloud-teardown-verify
  gcloud billing projects unlink ${project}
  gcloud projects delete ${project}
EOF
