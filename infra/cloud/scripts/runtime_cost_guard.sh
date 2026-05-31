#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

namespace="${GKE_NAMESPACE:-smartcity}"
ack="${RUNTIME_COST_ACK:-false}"
active_public="$(kubectl get ingress smartcity-streamlit-public -n "${namespace}" -o name 2>/dev/null || true)"
active_replicas="$(kubectl get deploy -n "${namespace}" -o jsonpath='{range .items[*]}{.metadata.name}{"="}{.status.readyReplicas}{"\n"}{end}' 2>/dev/null || true)"

if [[ -n "${active_public}" || "${active_replicas}" == *"=1"* ]]; then
  if [[ "${ack}" != "true" ]]; then
    echo "ERROR: runtime appears active or public ingress exists. Set RUNTIME_COST_ACK=true after confirming budget/cost intent." >&2
    echo "${active_public}"
    echo "${active_replicas}"
    exit 1
  fi
fi

echo "Runtime cost guard passed."
