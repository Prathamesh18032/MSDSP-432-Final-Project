#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"

project="${GCP_PROJECT_ID:-}"
region="${GCP_REGION:-asia-south1}"
repository="${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}"

if [[ -f "${tfvars}" ]]; then
  tf_project="$(awk -F= '/^[[:space:]]*gcp_project_id[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
  tf_region="$(awk -F= '/^[[:space:]]*gcp_region[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
  tf_repository="$(awk -F= '/^[[:space:]]*artifact_registry_repository[[:space:]]*=/ {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}")"
  project="${tf_project:-${project}}"
  region="${tf_region:-${region}}"
  repository="${tf_repository:-${repository}}"
fi

if [[ -z "${project}" || "${project}" == "replace-me-project" ]]; then
  echo "ERROR: Set GCP_PROJECT_ID or create infra/cloud/terraform/terraform.tfvars with a real gcp_project_id." >&2
  exit 1
fi

cat <<EOF
Artifact Registry was created during Slice 12 outside Terraform.
Before any future terraform apply, import it into Terraform state:

cd infra/cloud/terraform
terraform import \\
  google_artifact_registry_repository.services \\
  projects/${project}/locations/${region}/repositories/${repository}

This command is intentionally not executed by this preview target.
EOF
