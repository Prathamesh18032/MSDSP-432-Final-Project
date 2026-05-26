#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"${root_dir}/infra/cloud/scripts/ci_publish_check.sh"
"${root_dir}/infra/cloud/scripts/runtime_health.sh"
"${root_dir}/infra/cloud/scripts/runtime_live_smoke.sh"
RUN_COLD_EXPORT_SMOKE=yes "${root_dir}/infra/cloud/scripts/k8s_smoke.sh"

port="${STREAMLIT_PORT:-8501}"
namespace="${GKE_NAMESPACE:-smartcity}"

cat <<EOF
Live demo checks passed.

Open Streamlit through a private port-forward:
  make k8s-port-forward-streamlit
  http://localhost:${port}

Demo story:
  multi-source sensors -> Pub/Sub -> GKE writer -> TimescaleDB -> GCS/BigQuery -> Streamlit -> GCS backup/restore proof

Namespace:
  ${namespace}
EOF
