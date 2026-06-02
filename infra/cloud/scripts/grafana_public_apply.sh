#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

if [[ "${ALLOW_GRAFANA_PUBLIC_INGRESS:-}" != "yes" ]]; then
  echo "ERROR: set ALLOW_GRAFANA_PUBLIC_INGRESS=yes to create or update public Grafana ingress." >&2
  exit 1
fi

if [[ -z "${GRAFANA_ADMIN_PASSWORD:-}" ]]; then
  echo "ERROR: GRAFANA_ADMIN_PASSWORD is required before enabling public Grafana." >&2
  exit 1
fi

if [[ "${GRAFANA_ADMIN_PASSWORD}" == "admin" ]]; then
  echo "ERROR: GRAFANA_ADMIN_PASSWORD must not be the default value 'admin'." >&2
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
static_ip_name="${PUBLIC_GRAFANA_STATIC_IP_NAME:-smartcity-grafana-demo-ip}"
domain="${PUBLIC_GRAFANA_DOMAIN:-}"

[[ -n "${project}" ]] || { echo "ERROR: GCP_PROJECT_ID is required." >&2; exit 1; }

if [[ "${GRAFANA_PUBLIC_MANAGE_STATIC_IP:-}" == "yes" ]]; then
  gcloud services enable compute.googleapis.com --project "${project}" >/dev/null
  if ! gcloud compute addresses describe "${static_ip_name}" --global --project "${project}" >/dev/null 2>&1; then
    gcloud compute addresses create "${static_ip_name}" --global --project "${project}"
  fi

  ip="$(gcloud compute addresses describe "${static_ip_name}" \
    --global \
    --project "${project}" \
    --format='value(address)')"
else
  ip=""
fi

if [[ -n "${domain}" ]]; then
  export GRAFANA_ROOT_URL="https://${domain}"
elif [[ -n "${ip}" ]]; then
  export GRAFANA_ROOT_URL="http://${ip}"
fi

"${root_dir}/infra/cloud/scripts/grafana_public_render.sh"

if ! kubectl get secret smartcity-runtime-secrets -n "${namespace}" >/dev/null 2>&1; then
  echo "ERROR: smartcity-runtime-secrets does not exist in namespace ${namespace}." >&2
  echo "Run make k8s-apply with K8S_TIMESCALE_PASSWORD set before enabling public Grafana." >&2
  exit 1
fi

encoded_password="$(printf '%s' "${GRAFANA_ADMIN_PASSWORD}" | base64 | tr -d '\n')"
kubectl patch secret smartcity-runtime-secrets \
  -n "${namespace}" \
  --type merge \
  -p "{\"data\":{\"GRAFANA_ADMIN_PASSWORD\":\"${encoded_password}\"}}"

kubectl apply -f "${rendered_dir}/configmap.yaml"
kubectl apply -f "${rendered_dir}/grafana-provisioning.yaml"
kubectl apply -f "${rendered_dir}/workloads.yaml"
kubectl rollout restart deploy/smartcity-grafana -n "${namespace}"
kubectl rollout status deploy/smartcity-grafana -n "${namespace}" --timeout=300s
kubectl apply -f "${rendered_dir}/grafana-public.yaml"

echo "Public Grafana ingress requested. It can take several minutes for GKE to allocate the load balancer."
"${root_dir}/infra/cloud/scripts/grafana_public_url.sh" || true
