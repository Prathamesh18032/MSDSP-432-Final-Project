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

bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-}}"
project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-}}"
region="$(tfvar gcp_region || true)"; region="${region:-${GCP_REGION:-asia-south1}}"
repo="$(tfvar artifact_registry_repository || true)"; repo="${repo:-${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}}"

"${root_dir}/infra/cloud/scripts/gcp_cost_guard_check.sh"

echo
echo "GKE workloads that can drive ongoing cost:"
kubectl get deploy,statefulset,cronjob,pvc -n "${namespace}" -o wide

if [[ -n "${bucket}" ]]; then
  echo
  echo "GCS cold/backup storage usage:"
  gcloud storage du -s "gs://${bucket}" || true
fi

echo
echo "Artifact Registry repository size:"
gcloud artifacts repositories describe "${repo}" \
  --project "${project}" \
  --location "${region}" \
  --format="json(name,registryUri,updateTime)" || true

echo
echo "Cost control options:"
echo "- Run 'make runtime-scale-down' after demos to stop ingestor, writer, and Streamlit pods."
echo "- Keep TimescaleDB/PVC intact for recovery unless the team explicitly plans full cleanup."
echo "- Keep the GCP budget alert active before long-running demos."

echo "Runtime cost check completed."
