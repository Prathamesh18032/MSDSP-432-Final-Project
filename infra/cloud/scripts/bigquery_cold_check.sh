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
if ! command -v bq >/dev/null 2>&1; then
  fail "bq CLI is not installed or not on PATH; it is included with Google Cloud CLI."
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}}"
bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-smartcity-zero-disk-iot-pa-cold}}"
dataset="$(tfvar bigquery_dataset || true)"; dataset="${dataset:-${BIGQUERY_DATASET:-smartcity_iot}}"
table="${BIGQUERY_EXTERNAL_TABLE:-sensor_readings_external}"
min_rows="${CLOUD_COLD_MIN_ROWS:-0}"
attempts="${BIGQUERY_COLD_CHECK_ATTEMPTS:-6}"
sleep_seconds="${BIGQUERY_COLD_CHECK_SLEEP_SECONDS:-10}"

[[ -n "${project}" && "${project}" != "(unset)" ]] || fail "GCP project is not configured."
[[ "${min_rows}" =~ ^[0-9]+$ ]] || fail "CLOUD_COLD_MIN_ROWS must be a non-negative integer."
[[ "${attempts}" =~ ^[0-9]+$ && "${attempts}" -gt 0 ]] || fail "BIGQUERY_COLD_CHECK_ATTEMPTS must be positive."
[[ "${sleep_seconds}" =~ ^[0-9]+$ ]] || fail "BIGQUERY_COLD_CHECK_SLEEP_SECONDS must be a non-negative integer."

active_project="$(gcloud config get-value project 2>/dev/null || true)"
[[ "${active_project}" == "${project}" ]] || fail "gcloud active project is '${active_project}', expected '${project}'."

gcloud storage buckets describe "gs://${bucket}" --project="${project}" >/dev/null || fail "Missing GCS bucket gs://${bucket}."
info "GCS bucket exists: gs://${bucket}"

bq --project_id="${project}" show "${dataset}" >/dev/null || fail "Missing BigQuery dataset ${dataset}."
info "BigQuery dataset exists: ${dataset}"

bq --project_id="${project}" show "${dataset}.${table}" >/dev/null || fail "Missing BigQuery external table ${dataset}.${table}."
info "BigQuery external table exists: ${dataset}.${table}"

query="SELECT COUNT(1) AS row_count FROM \`${project}.${dataset}.${table}\`"
row_count="0"
for ((attempt = 1; attempt <= attempts; attempt++)); do
  query_output="$(bq --project_id="${project}" query --nouse_legacy_sql --format=csv "${query}" 2>&1)" && query_status=0 || query_status=$?
  if [[ "${query_status}" -eq 0 ]]; then
    row_count="$(printf "%s\n" "${query_output}" | tail -n 1 | tr -d '\r')"
    if [[ "${row_count}" =~ ^[0-9]+$ && "${row_count}" -ge "${min_rows}" ]]; then
      info "BigQuery external table is queryable with ${row_count} row(s)."
      exit 0
    fi
  elif [[ "${query_output}" == *"matched no files"* && "${min_rows}" -eq 0 ]]; then
    info "BigQuery external table is configured, but no cold Parquet files exist yet."
    exit 0
  else
    echo "${query_output}" >&2
  fi
  if [[ "${attempt}" -lt "${attempts}" ]]; then
    echo "BigQuery row count ${row_count} is below expected minimum ${min_rows}; retrying in ${sleep_seconds}s..."
    sleep "${sleep_seconds}"
  fi
done

fail "BigQuery external table row count ${row_count} is below expected minimum ${min_rows}."
