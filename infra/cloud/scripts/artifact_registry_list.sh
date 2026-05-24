#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

if ! command -v gcloud >/dev/null 2>&1; then
  fail "gcloud is not installed. Install the Google Cloud CLI first: https://cloud.google.com/sdk/docs/install"
fi

project="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
region="${GCP_REGION:-$(gcloud config get-value compute/region 2>/dev/null || true)}"
repository="${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}"

if [[ -z "${project}" || "${project}" == "(unset)" ]]; then
  fail "No GCP project is configured. Set GCP_PROJECT_ID in .env or run: gcloud config set project YOUR_PROJECT_ID"
fi
if [[ "${project}" == "replace-me-project" ]]; then
  fail "GCP_PROJECT_ID still uses the placeholder replace-me-project. Set your real project ID before listing Artifact Registry images."
fi
if [[ "${region}" != "asia-south1" ]]; then
  fail "GCP_REGION should be asia-south1 for the India/Mumbai default. Current value: ${region:-unset}"
fi

gcloud artifacts docker images list "${region}-docker.pkg.dev/${project}/${repository}" \
  --project="${project}" \
  --include-tags
