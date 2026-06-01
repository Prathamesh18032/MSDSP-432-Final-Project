#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

namespace="${GKE_NAMESPACE:-smartcity}"

kubectl scale deploy/smartcity-ingestor deploy/smartcity-hot-writer deploy/smartcity-streamlit \
  --replicas=1 \
  -n "${namespace}"

kubectl rollout status deploy/smartcity-hot-writer -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-ingestor -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-streamlit -n "${namespace}" --timeout=180s
if [[ "${VIDEO_AGENT_REPLICAS:-0}" != "0" ]]; then
  kubectl scale deploy/smartcity-video-agent --replicas="${VIDEO_AGENT_REPLICAS}" -n "${namespace}"
  kubectl rollout status deploy/smartcity-video-agent -n "${namespace}" --timeout=300s
fi

echo "Scaled optional runtime deployments back to one replica in namespace ${namespace}."
