#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "OK: $*"
}

if ! command -v gcloud >/dev/null 2>&1; then
  fail "gcloud is not installed. Install the Google Cloud CLI first: https://cloud.google.com/sdk/docs/install"
fi

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  fail "gcloud is not authenticated. Run: gcloud auth login"
fi
info "gcloud has an active authenticated account"

project="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
if [[ -z "${project}" || "${project}" == "(unset)" ]]; then
  fail "No GCP project is configured. Set GCP_PROJECT_ID in .env or run: gcloud config set project YOUR_PROJECT_ID"
fi
if [[ "${project}" == "replace-me-project" ]]; then
  fail "GCP_PROJECT_ID still uses the placeholder replace-me-project. Set your real project ID before checking Artifact Registry."
fi
info "GCP project is configured: ${project}"

region="${GCP_REGION:-$(gcloud config get-value compute/region 2>/dev/null || true)}"
if [[ "${region}" != "asia-south1" ]]; then
  fail "GCP_REGION should be asia-south1 for the India/Mumbai default. Current value: ${region:-unset}"
fi
info "GCP region is configured: ${region}"

repository="${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}"
registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repository}}"
expected_registry="${region}-docker.pkg.dev/${project}/${repository}"
if [[ "${registry}" != "${expected_registry}" ]]; then
  fail "IMAGE_REGISTRY should be ${expected_registry}. Current value: ${registry}"
fi
if [[ "${registry}" == *"replace-me-project"* || "${registry}" == *"<your-project-id>"* ]]; then
  fail "IMAGE_REGISTRY still contains a project placeholder. Set your real Artifact Registry path before checking."
fi
info "IMAGE_REGISTRY is configured: ${registry}"

if ! gcloud services list \
  --enabled \
  --project="${project}" \
  --filter='config.name:artifactregistry.googleapis.com' \
  --format='value(config.name)' | grep -q '^artifactregistry.googleapis.com$'; then
  fail "Artifact Registry API is not enabled. Run: make artifact-registry-create"
fi
info "Artifact Registry API is enabled"

if ! gcloud artifacts repositories describe "${repository}" \
  --project="${project}" \
  --location="${region}" >/dev/null 2>&1; then
  fail "Artifact Registry repository ${repository} does not exist in ${region}. Run: make artifact-registry-create"
fi
info "Artifact Registry repository exists: ${repository}"

docker_config="${DOCKER_CONFIG:-${HOME}/.docker}/config.json"
if [[ ! -f "${docker_config}" ]] || ! grep -q "\"${region}-docker.pkg.dev\"" "${docker_config}"; then
  fail "Docker is not configured for ${region}-docker.pkg.dev. Run: gcloud auth configure-docker ${region}-docker.pkg.dev"
fi
info "Docker credential helper is configured for ${region}-docker.pkg.dev"

echo
echo "Artifact Registry publish prerequisites are ready."
