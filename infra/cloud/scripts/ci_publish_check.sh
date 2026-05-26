#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-}}"
region="$(tfvar gcp_region || true)"; region="${region:-${GCP_REGION:-asia-south1}}"
repo="$(tfvar artifact_registry_repository || true)"; repo="${repo:-${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}}"
short_sha="${GITHUB_ACTIONS_IMAGE_TAG:-$(git -C "${root_dir}" rev-parse --short origin/main 2>/dev/null || git -C "${root_dir}" rev-parse --short HEAD)}"

if [[ -z "${project}" ]]; then
  echo "ERROR: GCP_PROJECT_ID or terraform gcp_project_id is required." >&2
  exit 1
fi

for image in smartcity-ingestor smartcity-writer smartcity-streamlit; do
  image_ref="${region}-docker.pkg.dev/${project}/${repo}/${image}"
  tags="$(gcloud artifacts docker tags list "${image_ref}" --project "${project}" --format='value(tag)' 2>/dev/null || true)"
  if ! grep -qx "latest-main" <<<"${tags}"; then
    echo "ERROR: ${image_ref} is missing tag latest-main." >&2
    exit 1
  fi
  if ! grep -qx "${short_sha}" <<<"${tags}"; then
    echo "ERROR: ${image_ref} is missing expected short SHA tag ${short_sha}." >&2
    exit 1
  fi
  echo "OK: ${image} has tags latest-main and ${short_sha}."
done

echo "CI publish check passed for ${project}/${repo}."
