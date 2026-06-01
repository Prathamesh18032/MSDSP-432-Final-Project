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

namespace="$(tfvar gke_namespace || true)"; namespace="${namespace:-${GKE_NAMESPACE:-smartcity}}"
domain="${PUBLIC_GRAFANA_DOMAIN:-}"

ip="$(kubectl get ingress smartcity-grafana-public \
  -n "${namespace}" \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"

if [[ -n "${domain}" ]]; then
  echo "Public Grafana URL: https://${domain}"
  if [[ -n "${ip}" ]]; then
    echo "Load balancer IP: ${ip}"
  fi
  exit 0
fi

if [[ -z "${ip}" ]]; then
  echo "Public Grafana URL is not ready yet; the Ingress has no load balancer IP." >&2
  exit 1
fi

echo "Public Grafana URL: http://${ip}"
