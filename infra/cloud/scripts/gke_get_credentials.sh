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

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}}"
region="$(tfvar gcp_region || true)"; region="${region:-${GCP_REGION:-asia-south1}}"
cluster="$(tfvar gke_cluster_name || true)"; cluster="${cluster:-${GKE_CLUSTER_NAME:-smartcity-autopilot}}"

[[ -n "${project}" && "${project}" != "(unset)" ]] || { echo "ERROR: GCP project is not configured." >&2; exit 1; }

gcloud container clusters get-credentials "${cluster}" \
  --region "${region}" \
  --project "${project}"

echo "kubectl is now configured for ${cluster} in ${region}."
