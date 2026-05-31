#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-}}"
namespace="$(tfvar gke_namespace || true)"; namespace="${namespace:-${GKE_NAMESPACE:-smartcity}}"
static_ip_name="${PUBLIC_DEMO_STATIC_IP_NAME:-smartcity-demo-ip}"

echo "Public demo Kubernetes resources:"
kubectl get ingress smartcity-streamlit-public -n "${namespace}" -o wide || true
kubectl get managedcertificate smartcity-streamlit-cert -n "${namespace}" -o wide 2>/dev/null || true
kubectl get backendconfig smartcity-streamlit-backend -n "${namespace}" -o wide 2>/dev/null || true

if [[ -n "${project}" ]]; then
  echo
  echo "Reserved public demo IP:"
  gcloud compute addresses describe "${static_ip_name}" \
    --global \
    --project "${project}" \
    --format="table(name,address,status)" 2>/dev/null || true
fi
