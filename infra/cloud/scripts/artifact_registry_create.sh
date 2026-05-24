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

project="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
if [[ -z "${project}" || "${project}" == "(unset)" ]]; then
  fail "No GCP project is configured. Set GCP_PROJECT_ID in .env or run: gcloud config set project YOUR_PROJECT_ID"
fi
if [[ "${project}" == "replace-me-project" ]]; then
  fail "GCP_PROJECT_ID still uses the placeholder replace-me-project. Set your real project ID before creating Artifact Registry resources."
fi

region="${GCP_REGION:-$(gcloud config get-value compute/region 2>/dev/null || true)}"
if [[ "${region}" != "asia-south1" ]]; then
  fail "GCP_REGION should be asia-south1 for the India/Mumbai default. Current value: ${region:-unset}"
fi

repository="${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}"
registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repository}}"
expected_registry="${region}-docker.pkg.dev/${project}/${repository}"
if [[ "${registry}" != "${expected_registry}" ]]; then
  fail "IMAGE_REGISTRY should be ${expected_registry}. Current value: ${registry}"
fi

echo "Using project ${project}, region ${region}, repository ${repository}."
echo "This target enables Artifact Registry and creates one Docker repository if it is missing."

gcloud config set project "${project}" >/dev/null
gcloud config set compute/region "${region}" >/dev/null

gcloud services enable artifactregistry.googleapis.com --project="${project}"
info "Artifact Registry API is enabled"

if gcloud artifacts repositories describe "${repository}" \
  --project="${project}" \
  --location="${region}" >/dev/null 2>&1; then
  info "Artifact Registry repository already exists: ${repository}"
else
  gcloud artifacts repositories create "${repository}" \
    --project="${project}" \
    --repository-format=docker \
    --location="${region}" \
    --description="Smart City service container images"
  info "Artifact Registry repository created: ${repository}"
fi

gcloud auth configure-docker "${region}-docker.pkg.dev" --quiet
info "Docker credential helper configured for ${region}-docker.pkg.dev"

echo
echo "Artifact Registry is ready for image publishing."
