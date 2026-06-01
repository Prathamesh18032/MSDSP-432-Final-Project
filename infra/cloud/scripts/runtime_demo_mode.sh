#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
namespace="${GKE_NAMESPACE:-smartcity}"

kubectl_retry() {
  local attempt
  for attempt in 1 2 3; do
    if kubectl "$@"; then
      return 0
    fi
    sleep $((attempt * 5))
  done
  kubectl "$@"
}

kubectl_retry scale statefulset/smartcity-timescaledb -n "${namespace}" --replicas=1
kubectl_retry wait --for=condition=Ready pod -l app.kubernetes.io/name=smartcity-timescaledb -n "${namespace}" --timeout=300s
kubectl_retry scale deploy/smartcity-ingestor deploy/smartcity-hot-writer deploy/smartcity-streamlit \
  -n "${namespace}" \
  --replicas=1
kubectl_retry rollout status deploy/smartcity-hot-writer -n "${namespace}" --timeout=180s
kubectl_retry rollout status deploy/smartcity-ingestor -n "${namespace}" --timeout=180s
kubectl_retry rollout status deploy/smartcity-streamlit -n "${namespace}" --timeout=180s
if [[ "${VIDEO_AGENT_REPLICAS:-0}" != "0" ]]; then
  kubectl_retry scale deploy/smartcity-video-agent -n "${namespace}" --replicas="${VIDEO_AGENT_REPLICAS}"
  kubectl_retry rollout status deploy/smartcity-video-agent -n "${namespace}" --timeout=300s
fi

for cronjob in smartcity-cold-export smartcity-timescale-backup; do
  kubectl_retry patch cronjob "${cronjob}" -n "${namespace}" --type merge -p '{"spec":{"suspend":false}}' >/dev/null
done

"${root_dir}/infra/cloud/scripts/runtime_health.sh"
"${root_dir}/infra/cloud/scripts/public_demo_status.sh" || true
echo "Runtime demo mode is active."
