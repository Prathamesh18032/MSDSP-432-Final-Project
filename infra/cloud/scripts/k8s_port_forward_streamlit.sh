#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rendered_namespace="$(awk '/^  name: / {print $2; exit}' "${root_dir}/infra/cloud/k8s/rendered/namespace.yaml" 2>/dev/null || true)"
namespace="${GKE_NAMESPACE:-${rendered_namespace:-smartcity}}"
port="${STREAMLIT_PORT:-8501}"

echo "Forwarding http://localhost:${port} to smartcity-streamlit in namespace ${namespace}."
kubectl port-forward -n "${namespace}" service/smartcity-streamlit "${port}:8501"
