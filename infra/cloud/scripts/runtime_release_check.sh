#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

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
repository="$(tfvar artifact_registry_repository || true)"; repository="${repository:-${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}}"
namespace="$(tfvar gke_namespace || true)"; namespace="${namespace:-${GKE_NAMESPACE:-smartcity}}"
tag="${RUNTIME_EXPECTED_IMAGE_TAG:-latest-main}"
registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repository}}"

[[ -n "${project}" ]] || { echo "ERROR: GCP_PROJECT_ID is required." >&2; exit 1; }

for image in smartcity-ingestor smartcity-writer smartcity-streamlit; do
  if ! gcloud artifacts docker tags list "${registry}/${image}" \
    --project "${project}" \
    --format="value(tag)" \
    --filter="tag:${tag}" | grep -qx "${tag}"; then
    echo "ERROR: ${image}:${tag} was not found in Artifact Registry." >&2
    exit 1
  fi
  echo "OK: ${image}:${tag} exists in Artifact Registry."
done

for deployment in smartcity-ingestor smartcity-hot-writer smartcity-streamlit; do
  image="$(kubectl get deploy "${deployment}" -n "${namespace}" -o jsonpath='{.spec.template.spec.containers[0].image}')"
  if [[ "${image}" != *":${tag}" ]]; then
    echo "ERROR: ${deployment} is running ${image}, expected tag ${tag}." >&2
    exit 1
  fi
  echo "OK: ${deployment} is running ${image}."
done

echo "Runtime release check passed for tag ${tag}."
