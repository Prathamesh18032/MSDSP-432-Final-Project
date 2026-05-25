#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"${root_dir}/infra/cloud/scripts/gcp_bootstrap_check.sh"
"${root_dir}/infra/cloud/scripts/gcp_cost_guard_check.sh"
"${root_dir}/infra/cloud/scripts/gcp_core_check.sh"
"${root_dir}/infra/cloud/scripts/k8s_render.sh"

if command -v kubectl >/dev/null 2>&1 && kubectl config current-context >/dev/null 2>&1; then
  "${root_dir}/infra/cloud/scripts/k8s_status.sh" || true
else
  echo "kubectl is not configured for a cluster yet; skipping live Kubernetes status."
fi

echo "Runtime readiness check completed."
