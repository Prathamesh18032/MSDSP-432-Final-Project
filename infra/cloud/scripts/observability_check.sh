#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"
rendered_namespace="$(awk '/^  name: / {print $2; exit}' "${root_dir}/infra/cloud/k8s/rendered/namespace.yaml" 2>/dev/null || true)"
namespace="${GKE_NAMESPACE:-${rendered_namespace:-smartcity}}"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-}}"
dataset="$(tfvar bigquery_dataset || true)"; dataset="${dataset:-${BIGQUERY_DATASET:-smartcity_iot}}"
subscription="$(tfvar pubsub_subscription_name || true)"; subscription="${subscription:-${GCP_PUBSUB_SUBSCRIPTION:-smartcity-hot-writer}}"

kubectl get namespace "${namespace}"
kubectl get statefulset,deploy,cronjob,svc,pod -n "${namespace}" -o wide
kubectl rollout status deploy/smartcity-hot-writer -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-ingestor -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-streamlit -n "${namespace}" --timeout=180s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=smartcity-timescaledb -n "${namespace}" --timeout=300s

gcloud pubsub subscriptions describe "${subscription}" --format="value(name)" >/dev/null
echo "Pub/Sub subscription reachable: ${subscription}"

if [[ -n "${bucket}" ]]; then
  gcloud storage ls "gs://${bucket}/sensor_readings/**" >/dev/null 2>&1 && echo "Cold Parquet objects visible in gs://${bucket}/sensor_readings/" || echo "No cold Parquet objects visible yet."
fi

if command -v bq >/dev/null 2>&1; then
  bq query --use_legacy_sql=false --format=none "SELECT COUNT(*) AS row_count FROM \`${dataset}.sensor_readings_external\`" >/dev/null
  echo "BigQuery external table is queryable: ${dataset}.sensor_readings_external"
else
  echo "bq not installed; skipping BigQuery query."
fi

"${root_dir}/infra/cloud/scripts/k8s_logs.sh"

echo "Observability check completed."
