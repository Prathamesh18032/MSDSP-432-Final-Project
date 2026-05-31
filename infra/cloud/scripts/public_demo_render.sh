#!/usr/bin/env bash
set -euo pipefail

if [[ "${ALLOW_PUBLIC_INGRESS:-}" != "yes" ]]; then
  echo "ERROR: set ALLOW_PUBLIC_INGRESS=yes to render public demo ingress manifests." >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"
base_dir="${root_dir}/infra/cloud/k8s/base"
rendered_dir="${root_dir}/infra/cloud/k8s/rendered"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

namespace="$(tfvar gke_namespace || true)"; namespace="${namespace:-${GKE_NAMESPACE:-smartcity}}"
static_ip_name="${PUBLIC_DEMO_STATIC_IP_NAME:-smartcity-demo-ip}"
domain="${PUBLIC_DEMO_DOMAIN:-}"
template="${base_dir}/public-demo-http.yaml"
scheme="http"

if [[ -n "${domain}" ]]; then
  template="${base_dir}/public-demo-https.yaml"
  scheme="https"
fi

PUBLIC_DEMO_ENABLED=true "${root_dir}/infra/cloud/scripts/k8s_render.sh"

sed \
  -e "s|__GKE_NAMESPACE__|${namespace}|g" \
  -e "s|__PUBLIC_DEMO_STATIC_IP_NAME__|${static_ip_name}|g" \
  -e "s|__PUBLIC_DEMO_DOMAIN__|${domain}|g" \
  "${template}" > "${rendered_dir}/public-demo.yaml"

echo "Rendered public demo ingress manifests to ${rendered_dir}/public-demo.yaml"
echo "Public demo mode: ${scheme}"
echo "Static IP name: ${static_ip_name}"
if [[ -n "${domain}" ]]; then
  echo "Domain: ${domain}"
else
  echo "WARNING: no PUBLIC_DEMO_DOMAIN configured; this renders a temporary HTTP-only public IP demo."
fi
