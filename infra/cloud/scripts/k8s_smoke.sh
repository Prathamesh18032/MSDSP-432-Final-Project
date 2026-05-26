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

kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=smartcity-timescaledb \
  -n "${namespace}" \
  --timeout=300s

kubectl rollout status deploy/smartcity-hot-writer -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-ingestor -n "${namespace}" --timeout=180s
kubectl rollout status deploy/smartcity-streamlit -n "${namespace}" --timeout=180s

timescale_pod="$(kubectl get pod -n "${namespace}" -l app.kubernetes.io/name=smartcity-timescaledb -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "${namespace}" "${timescale_pod}" -- pg_isready -U "${user}" -d "${db}"
kubectl exec -n "${namespace}" "${timescale_pod}" -- psql -U "${user}" -d "${db}" -c "SELECT COUNT(*) AS sensor_readings FROM sensor_readings;"

if [[ "${RUN_COLD_EXPORT_SMOKE:-}" == "yes" ]]; then
  job_name="smartcity-cold-export-smoke-$(date +%Y%m%d%H%M%S)"
  kubectl create job -n "${namespace}" --from=cronjob/smartcity-cold-export "${job_name}"
  kubectl wait -n "${namespace}" --for=condition=complete "job/${job_name}" --timeout=300s
fi

echo "Kubernetes runtime smoke passed."
