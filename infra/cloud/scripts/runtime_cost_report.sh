#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"${root_dir}/infra/cloud/scripts/runtime_cost_check.sh"
echo
"${root_dir}/infra/cloud/scripts/public_demo_status.sh" || true
echo
echo "CronJob suspension state:"
kubectl get cronjob -n "${GKE_NAMESPACE:-smartcity}" -o custom-columns=NAME:.metadata.name,SUSPEND:.spec.suspend,SCHEDULE:.spec.schedule,LAST:.status.lastScheduleTime || true
