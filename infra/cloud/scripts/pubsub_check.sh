#!/usr/bin/env bash
set -euo pipefail

PROJECT_ID="${GCP_PROJECT_ID:-}"
TOPIC="${GCP_PUBSUB_TOPIC:-smartcity-readings}"
SUBSCRIPTION="${GCP_PUBSUB_SUBSCRIPTION:-smartcity-hot-writer}"

if [[ -z "${PROJECT_ID}" ]]; then
  echo "GCP_PROJECT_ID is required for Pub/Sub checks." >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud is not installed; install Google Cloud CLI before live Pub/Sub validation." >&2
  exit 1
fi

ACTIVE_PROJECT="$(gcloud config get-value project 2>/dev/null || true)"
if [[ "${ACTIVE_PROJECT}" != "${PROJECT_ID}" ]]; then
  echo "gcloud active project is '${ACTIVE_PROJECT}', expected '${PROJECT_ID}'." >&2
  exit 1
fi

echo "Checking Pub/Sub topic '${TOPIC}' in project '${PROJECT_ID}'..."
if ! gcloud pubsub topics describe "${TOPIC}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Pub/Sub topic '${TOPIC}' does not exist yet. This slice does not create it." >&2
  echo "Create it in a later controlled cloud slice or through reviewed Terraform apply." >&2
  exit 1
fi

echo "Checking Pub/Sub subscription '${SUBSCRIPTION}' in project '${PROJECT_ID}'..."
if ! gcloud pubsub subscriptions describe "${SUBSCRIPTION}" --project "${PROJECT_ID}" >/dev/null 2>&1; then
  echo "Pub/Sub subscription '${SUBSCRIPTION}' does not exist yet. This slice does not create it." >&2
  echo "Create it in a later controlled cloud slice or through reviewed Terraform apply." >&2
  exit 1
fi

echo "Pub/Sub readiness check passed."
