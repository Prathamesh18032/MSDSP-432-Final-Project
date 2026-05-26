#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rendered_dir="${root_dir}/infra/cloud/k8s/rendered"
db="${K8S_TIMESCALE_DB:-smartcity_hot}"
user="${K8S_TIMESCALE_USER:-smartcity}"
password="${K8S_TIMESCALE_PASSWORD:-}"

if [[ ! -d "${rendered_dir}" ]]; then
  echo "Rendered manifests not found. Run: make k8s-render" >&2
  exit 1
fi

rendered_namespace="$(awk '/^  name: / {print $2; exit}' "${rendered_dir}/namespace.yaml" 2>/dev/null || true)"
namespace="${GKE_NAMESPACE:-${rendered_namespace:-smartcity}}"

kubectl apply -f "${rendered_dir}/namespace.yaml"

if ! kubectl get secret smartcity-runtime-secrets -n "${namespace}" >/dev/null 2>&1; then
  if [[ -z "${password}" ]]; then
    echo "ERROR: smartcity-runtime-secrets does not exist and K8S_TIMESCALE_PASSWORD is not set." >&2
    echo "Set K8S_TIMESCALE_PASSWORD and rerun, or create the secret manually." >&2
    exit 1
  fi

  dsn="postgres://${user}:${password}@smartcity-timescaledb.${namespace}.svc.cluster.local:5432/${db}?sslmode=disable"
  args=(
    create secret generic smartcity-runtime-secrets
    --namespace "${namespace}"
    --from-literal "TIMESCALE_PASSWORD=${password}"
    --from-literal "TIMESCALE_DSN=${dsn}"
  )
  if [[ -n "${OPENAQ_API_KEY:-}" ]]; then
    args+=(--from-literal "OPENAQ_API_KEY=${OPENAQ_API_KEY}")
  fi

  kubectl "${args[@]}" --dry-run=client -o yaml | kubectl apply -f -
fi

kubectl apply -f "${rendered_dir}/timescaledb-init.yaml"
kubectl apply -f "${rendered_dir}/serviceaccounts.yaml"
kubectl apply -f "${rendered_dir}/configmap.yaml"
kubectl apply -f "${rendered_dir}/workloads.yaml"

echo "Kubernetes runtime manifests applied to namespace ${namespace}."
