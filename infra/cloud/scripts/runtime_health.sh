#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"
namespace="${GKE_NAMESPACE:-smartcity}"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

latest_object() {
  local uri="$1"
  gcloud storage ls -l "${uri}" 2>/dev/null | awk '/gs:\/\// {print $2 " " $3}' | sort | tail -1
}

print_object_age() {
  local label="$1"
  local listing="$2"
  if [[ -z "${listing}" ]]; then
    echo "WARNING: no ${label} object found."
    return 0
  fi
  local timestamp object
  timestamp="$(awk '{print $1}' <<<"${listing}")"
  object="$(awk '{print $2}' <<<"${listing}")"
  python3 - "$label" "$timestamp" "$object" <<'PY'
import sys
from datetime import datetime, timezone

label, ts, obj = sys.argv[1], sys.argv[2], sys.argv[3]
dt = datetime.fromisoformat(ts.replace("Z", "+00:00"))
age_hours = (datetime.now(timezone.utc) - dt).total_seconds() / 3600
print(f"{label}: {obj} age_hours={age_hours:.2f}")
PY
}

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-}}"
bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-}}"
dataset="$(tfvar bigquery_dataset || true)"; dataset="${dataset:-${BIGQUERY_DATASET:-smartcity_iot}}"
subscription="$(tfvar pubsub_subscription_name || true)"; subscription="${subscription:-${GCP_PUBSUB_SUBSCRIPTION:-smartcity-hot-writer}}"
backup_prefix="${TIMESCALE_BACKUP_PREFIX:-backups/timescaledb}"

kubectl get namespace "${namespace}" >/dev/null
kubectl rollout status deploy/smartcity-hot-writer -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-ingestor -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-streamlit -n "${namespace}" --timeout=180s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=smartcity-timescaledb -n "${namespace}" --timeout=300s

echo
echo "Pod restart counts:"
kubectl get pods -n "${namespace}" -o jsonpath='{range .items[*]}{.metadata.name}{" restarts="}{range .status.containerStatuses[*]}{.restartCount}{" "}{end}{"\n"}{end}'

failed_jobs="$(kubectl get jobs -n "${namespace}" -o jsonpath='{range .items[?(@.status.failed)]}{.metadata.name}{" failed="}{.status.failed}{"\n"}{end}' || true)"
if [[ -n "${failed_jobs}" ]]; then
  echo "ERROR: failed jobs detected:"
  echo "${failed_jobs}"
  exit 1
fi
echo "OK: no failed jobs detected in ${namespace}."

echo
kubectl get pvc -n "${namespace}"

echo
echo "Current runtime images:"
kubectl get deploy -n "${namespace}" -o jsonpath='{range .items[*]}{.metadata.name}{" image="}{.spec.template.spec.containers[0].image}{"\n"}{end}'

gcloud pubsub subscriptions describe "${subscription}" --project "${project}" --format="value(name)" >/dev/null
backlog="$(gcloud monitoring time-series list \
  --project "${project}" \
  --filter="metric.type=\"pubsub.googleapis.com/subscription/num_undelivered_messages\" AND resource.labels.subscription_id=\"${subscription}\"" \
  --freshness=30m \
  --limit=1 \
  --format="value(points[0].value.int64Value)" 2>/dev/null | head -1 || true)"
echo "Pub/Sub subscription reachable: ${subscription}; backlog=${backlog:-unknown}"

if [[ -n "${bucket}" ]]; then
  print_object_age "Latest backup" "$(latest_object "gs://${bucket}/${backup_prefix}/**")"
  print_object_age "Latest cold export" "$(latest_object "gs://${bucket}/sensor_readings/**")"
fi

if command -v bq >/dev/null 2>&1; then
  bq query --use_legacy_sql=false --format=prettyjson "SELECT COUNT(*) AS row_count FROM \`${dataset}.sensor_readings_external\`" >/dev/null
  echo "BigQuery external table row-count query passed: ${dataset}.sensor_readings_external"
fi

echo "Runtime health check passed."
