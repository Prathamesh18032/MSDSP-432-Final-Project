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
  fail "gcloud is not installed. Install the Google Cloud CLI first."
fi

project="${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}"
region="${GCP_REGION:-asia-south1}"
topic="${GCP_PUBSUB_TOPIC:-smartcity-readings}"
dlq_topic="${GCP_PUBSUB_DLQ_TOPIC:-smartcity-dlq}"
subscription="${GCP_PUBSUB_SUBSCRIPTION:-smartcity-hot-writer}"
bucket="${GCS_BUCKET:-smartcity-zero-disk-iot-pa-cold}"
dataset="${BIGQUERY_DATASET:-smartcity_iot}"
repository="${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}"
root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}}"
region="$(tfvar gcp_region || true)"; region="${region:-${GCP_REGION:-asia-south1}}"
topic="$(tfvar pubsub_topic_name || true)"; topic="${topic:-${GCP_PUBSUB_TOPIC:-smartcity-readings}}"
dlq_topic="$(tfvar pubsub_dlq_topic_name || true)"; dlq_topic="${dlq_topic:-${GCP_PUBSUB_DLQ_TOPIC:-smartcity-dlq}}"
subscription="$(tfvar pubsub_subscription_name || true)"; subscription="${subscription:-${GCP_PUBSUB_SUBSCRIPTION:-smartcity-hot-writer}}"
video_topic="$(tfvar video_pubsub_topic_name || true)"; video_topic="${video_topic:-${VIDEO_AGENT_PUBSUB_TOPIC:-smartcity-video-events}}"
video_subscription="$(tfvar video_pubsub_subscription_name || true)"; video_subscription="${video_subscription:-${VIDEO_AGENT_PUBSUB_SUBSCRIPTION:-smartcity-video-agent}}"
bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-smartcity-zero-disk-iot-pa-cold}}"
dataset="$(tfvar bigquery_dataset || true)"; dataset="${dataset:-${BIGQUERY_DATASET:-smartcity_iot}}"
repository="$(tfvar artifact_registry_repository || true)"; repository="${repository:-${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}}"

[[ -n "${project}" && "${project}" != "(unset)" ]] || fail "GCP project is not configured."
[[ "${region}" == "asia-south1" ]] || fail "GCP_REGION should be asia-south1. Current value: ${region}"

if ! gcloud services list --enabled --project="${project}" --format='value(config.name)' | grep -qx "pubsub.googleapis.com"; then
  fail "Pub/Sub API is not enabled."
fi
info "Pub/Sub API is enabled"

gcloud pubsub topics describe "${topic}" --project="${project}" >/dev/null || fail "Missing Pub/Sub topic ${topic}."
info "Pub/Sub topic exists: ${topic}"

gcloud pubsub topics describe "${dlq_topic}" --project="${project}" >/dev/null || fail "Missing Pub/Sub DLQ topic ${dlq_topic}."
info "Pub/Sub DLQ topic exists: ${dlq_topic}"

gcloud pubsub subscriptions describe "${subscription}" --project="${project}" >/dev/null || fail "Missing Pub/Sub subscription ${subscription}."
info "Pub/Sub subscription exists: ${subscription}"

gcloud pubsub topics describe "${video_topic}" --project="${project}" >/dev/null || fail "Missing video Pub/Sub topic ${video_topic}."
info "Video Pub/Sub topic exists: ${video_topic}"

gcloud pubsub subscriptions describe "${video_subscription}" --project="${project}" >/dev/null || fail "Missing video Pub/Sub subscription ${video_subscription}."
info "Video Pub/Sub subscription exists: ${video_subscription}"

gcloud storage buckets describe "gs://${bucket}" --project="${project}" >/dev/null || fail "Missing GCS bucket gs://${bucket}."
info "GCS bucket exists: gs://${bucket}"

if ! command -v bq >/dev/null 2>&1; then
  fail "bq CLI is not installed or not on PATH; it is included with Google Cloud CLI."
fi
bq --project_id="${project}" show "${dataset}" >/dev/null || fail "Missing BigQuery dataset ${dataset}."
info "BigQuery dataset exists: ${dataset}"

bq --project_id="${project}" show "${dataset}.sensor_readings_external" >/dev/null || fail "Missing BigQuery external table ${dataset}.sensor_readings_external."
info "BigQuery external table exists: ${dataset}.sensor_readings_external"

gcloud artifacts repositories describe "${repository}" --project="${project}" --location="${region}" >/dev/null || fail "Missing Artifact Registry repository ${repository}."
info "Artifact Registry repository exists: ${repository}"

for account in smartcity-ingestor smartcity-writer smartcity-analytics; do
  gcloud iam service-accounts describe "${account}@${project}.iam.gserviceaccount.com" --project="${project}" >/dev/null || fail "Missing service account ${account}."
  info "Service account exists: ${account}"
done

echo
echo "GCP core resource check passed."
