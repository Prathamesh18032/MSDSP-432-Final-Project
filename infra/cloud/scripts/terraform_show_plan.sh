#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tf_dir="${root_dir}/infra/cloud/terraform"
plan_file="${TF_PLAN_FILE:-smartcity.tfplan}"

if ! command -v terraform >/dev/null 2>&1; then
  echo "ERROR: terraform is not installed. Install it before showing a plan." >&2
  exit 1
fi

if [[ ! -f "${tf_dir}/${plan_file}" ]]; then
  echo "ERROR: Missing Terraform plan artifact: ${tf_dir}/${plan_file}" >&2
  echo "Run: make terraform-plan" >&2
  exit 1
fi

cd "${tf_dir}"
terraform show "${plan_file}"
