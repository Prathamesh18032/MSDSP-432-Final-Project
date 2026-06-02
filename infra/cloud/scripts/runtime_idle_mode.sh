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

"${root_dir}/infra/cloud/scripts/public_demo_disable.sh" || true

for cronjob in smartcity-cold-export smartcity-timescale-backup; do
  kubectl_retry patch cronjob "${cronjob}" -n "${namespace}" --type merge -p '{"spec":{"suspend":true}}' >/dev/null || true
done

kubectl_retry scale deploy/smartcity-ingestor deploy/smartcity-hot-writer deploy/smartcity-streamlit deploy/smartcity-video-agent \
  -n "${namespace}" \
  --replicas=0 \
  --ignore-not-found=true

if [[ "${RUNTIME_IDLE_SCALE_TIMESCALE:-false}" == "true" ]]; then
  kubectl_retry scale statefulset/smartcity-timescaledb -n "${namespace}" --replicas=0
  echo "TimescaleDB compute scaled to zero; PVC remains intact."
else
  echo "TimescaleDB remains running. Set RUNTIME_IDLE_SCALE_TIMESCALE=true to scale StatefulSet compute to zero."
fi

echo "Runtime idle mode requested. PVCs, GCS, Pub/Sub, BigQuery, Artifact Registry, backups, and Terraform resources were preserved."
