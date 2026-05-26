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

bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-}}"
prefix="${TIMESCALE_BACKUP_PREFIX:-backups/timescaledb}"

if [[ -z "${bucket}" ]]; then
  echo "ERROR: GCS_BUCKET or terraform gcs_bucket is required." >&2
  exit 1
fi

if ! command -v gcloud >/dev/null 2>&1; then
  echo "ERROR: gcloud is required for backup checks." >&2
  exit 1
fi

if gcloud storage ls "gs://${bucket}/${prefix}/**" 2>/dev/null | grep -q '\.dump$'; then
  echo "TimescaleDB backup object exists under gs://${bucket}/${prefix}/"
else
  echo "ERROR: No TimescaleDB .dump backup found under gs://${bucket}/${prefix}/" >&2
  exit 1
fi
