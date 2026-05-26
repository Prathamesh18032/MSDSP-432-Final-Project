#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rendered_namespace="$(awk '/^  name: / {print $2; exit}' "${root_dir}/infra/cloud/k8s/rendered/namespace.yaml" 2>/dev/null || true)"
namespace="${GKE_NAMESPACE:-${rendered_namespace:-smartcity}}"
db="${K8S_TIMESCALE_DB:-smartcity_hot}"
user="${K8S_TIMESCALE_USER:-smartcity}"

"${root_dir}/infra/cloud/scripts/pubsub_check.sh"

echo "Publishing one multi-source batch to Pub/Sub from the local producer."
(
  cd "${root_dir}"
  INGESTION_SINK=pubsub GOCACHE="${root_dir}/.cache/go-build" go run ./services/ingestor/cmd/poll-multisource -once
)

echo "Waiting for the GKE writer to consume messages."
sleep "${RUNTIME_LIVE_SMOKE_WAIT_SECONDS:-30}"

timescale_pod="$(kubectl get pod -n "${namespace}" -l app.kubernetes.io/name=smartcity-timescaledb -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "${namespace}" "${timescale_pod}" -- psql -U "${user}" -d "${db}" -c "SELECT source, COUNT(*) AS readings FROM sensor_readings GROUP BY source ORDER BY source;"

echo "Runtime live smoke completed."
