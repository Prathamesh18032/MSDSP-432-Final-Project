#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

if [[ "${ALLOW_PUBLIC_INGRESS:-}" != "yes" ]]; then
  echo "ERROR: set ALLOW_PUBLIC_INGRESS=yes to create or update public demo ingress." >&2
  exit 1
fi

if [[ -z "${STREAMLIT_DEMO_PASSWORD:-}" ]]; then
  echo "ERROR: STREAMLIT_DEMO_PASSWORD is required before enabling public demo access." >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"
rendered_dir="${root_dir}/infra/cloud/k8s/rendered"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-}}"
namespace="$(tfvar gke_namespace || true)"; namespace="${namespace:-${GKE_NAMESPACE:-smartcity}}"
static_ip_name="${PUBLIC_DEMO_STATIC_IP_NAME:-smartcity-demo-ip}"

[[ -n "${project}" ]] || { echo "ERROR: GCP_PROJECT_ID is required." >&2; exit 1; }

"${root_dir}/infra/cloud/scripts/public_demo_render.sh"

gcloud services enable compute.googleapis.com --project "${project}" >/dev/null
if ! gcloud compute addresses describe "${static_ip_name}" --global --project "${project}" >/dev/null 2>&1; then
  gcloud compute addresses create "${static_ip_name}" --global --project "${project}"
fi

encoded_password="$(printf '%s' "${STREAMLIT_DEMO_PASSWORD}" | base64 | tr -d '\n')"
kubectl patch secret smartcity-runtime-secrets \
  -n "${namespace}" \
  --type merge \
  -p "{\"data\":{\"STREAMLIT_DEMO_PASSWORD\":\"${encoded_password}\"}}"

kubectl apply -f "${rendered_dir}/configmap.yaml"
kubectl apply -f "${rendered_dir}/workloads.yaml"
kubectl rollout restart deploy/smartcity-streamlit -n "${namespace}"
kubectl rollout status deploy/smartcity-streamlit -n "${namespace}" --timeout=300s
kubectl apply -f "${rendered_dir}/public-demo.yaml"

echo "Public demo ingress requested. It can take several minutes for GKE to allocate the load balancer."
"${root_dir}/infra/cloud/scripts/public_demo_url.sh" || true
