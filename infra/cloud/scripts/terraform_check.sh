#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tf_dir="${root_dir}/infra/cloud/terraform"
tfvars="${tf_dir}/terraform.tfvars"

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "OK: $*"
}

if ! command -v terraform >/dev/null 2>&1; then
  fail "terraform is not installed. Install it before running Slice 13 plan checks: https://developer.hashicorp.com/terraform/install"
fi
info "terraform is installed: $(terraform version | head -n 1)"

if [[ ! -f "${tfvars}" ]]; then
  fail "Missing ${tfvars}. Copy infra/cloud/terraform/terraform.tfvars.example to terraform.tfvars and replace placeholders."
fi
info "local terraform.tfvars exists"

if grep -q "replace-me" "${tfvars}"; then
  fail "terraform.tfvars still contains replace-me placeholders."
fi

project="$(awk -F= '/^[[:space:]]*gcp_project_id[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
region="$(awk -F= '/^[[:space:]]*gcp_region[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
bucket="$(awk -F= '/^[[:space:]]*gcs_bucket[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
repository="$(awk -F= '/^[[:space:]]*artifact_registry_repository[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"

[[ -n "${project}" ]] || fail "terraform.tfvars is missing gcp_project_id."
[[ -n "${region}" ]] || fail "terraform.tfvars is missing gcp_region."
[[ -n "${bucket}" ]] || fail "terraform.tfvars is missing gcs_bucket."
[[ -n "${repository}" ]] || fail "terraform.tfvars is missing artifact_registry_repository."

if [[ "${region}" != "asia-south1" ]]; then
  fail "gcp_region should be asia-south1 for the current project. Current value: ${region}"
fi

if [[ "${project}" == "replace-me-project" || "${bucket}" == "replace-me-smartcity-iot" ]]; then
  fail "terraform.tfvars still uses placeholder project or bucket values."
fi

info "terraform.tfvars project: ${project}"
info "terraform.tfvars region: ${region}"
info "terraform.tfvars cold bucket: ${bucket}"
info "terraform.tfvars Artifact Registry repository: ${repository}"

echo
echo "Terraform readiness check passed without contacting GCP."
