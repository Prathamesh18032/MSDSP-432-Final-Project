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
info "gcloud is installed"

if ! gcloud auth list --filter=status:ACTIVE --format='value(account)' | grep -q .; then
  fail "gcloud is not authenticated. Run: gcloud auth login"
fi
info "gcloud has an active authenticated account"

project="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
if [[ -z "${project}" || "${project}" == "(unset)" ]]; then
  fail "No GCP project is configured. Set GCP_PROJECT_ID in .env or run: gcloud config set project YOUR_PROJECT_ID"
fi
info "GCP project is configured: ${project}"

region="${GCP_REGION:-$(gcloud config get-value compute/region 2>/dev/null || true)}"
if [[ -z "${region}" || "${region}" == "(unset)" ]]; then
  fail "No GCP region is configured. Set GCP_REGION=asia-south1 in .env or run: gcloud config set compute/region asia-south1"
fi
if [[ "${region}" != "asia-south1" ]]; then
  fail "GCP_REGION should be asia-south1 for the India/Mumbai default. Current value: ${region}"
fi
info "GCP region is configured: ${region}"

if ! command -v docker >/dev/null 2>&1; then
  fail "Docker is not installed or not on PATH. Install/start Docker Desktop before image publish work."
fi
info "Docker CLI is installed"

repository="${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}"
registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repository}}"
expected_prefix="${region}-docker.pkg.dev/${project}/${repository}"
if [[ "${registry}" != "${expected_prefix}" ]]; then
  fail "IMAGE_REGISTRY should be ${expected_prefix}. Current value: ${registry}"
fi
info "IMAGE_REGISTRY is configured: ${registry}"

echo
echo "Bootstrap check completed without creating or modifying GCP resources."
