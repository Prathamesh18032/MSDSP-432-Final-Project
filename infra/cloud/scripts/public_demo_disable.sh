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

kubectl delete ingress smartcity-streamlit-public -n "${namespace}" --ignore-not-found
kubectl delete managedcertificate smartcity-streamlit-cert -n "${namespace}" --ignore-not-found 2>/dev/null || true
kubectl delete backendconfig smartcity-streamlit-backend -n "${namespace}" --ignore-not-found 2>/dev/null || true
kubectl patch configmap smartcity-config \
  -n "${namespace}" \
  --type merge \
  -p '{"data":{"PUBLIC_DEMO_ENABLED":"false"}}' 2>/dev/null || true
kubectl rollout restart deploy/smartcity-streamlit -n "${namespace}" 2>/dev/null || true

if [[ "${PUBLIC_DEMO_DELETE_STATIC_IP:-}" == "yes" && -n "${project}" ]]; then
  gcloud compute addresses delete "${static_ip_name}" --global --project "${project}" --quiet || true
else
  echo "Static IP ${static_ip_name} was preserved. Set PUBLIC_DEMO_DELETE_STATIC_IP=yes to delete it."
fi

echo "Public demo ingress disabled."
