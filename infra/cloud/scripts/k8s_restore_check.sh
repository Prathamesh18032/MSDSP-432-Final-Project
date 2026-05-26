#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

restore_namespace="${RESTORE_TEST_NAMESPACE:-smartcity-restore-test}"
live_namespace="${GKE_NAMESPACE:-smartcity}"
db="${K8S_TIMESCALE_DB:-smartcity_hot}"
user="${K8S_TIMESCALE_USER:-smartcity}"

if [[ "${restore_namespace}" == "${live_namespace}" || "${restore_namespace}" == "smartcity" ]]; then
  echo "ERROR: refusing to validate restore in live namespace ${restore_namespace}." >&2
  exit 1
fi

kubectl get namespace "${restore_namespace}" >/dev/null
for _ in {1..30}; do
  if kubectl get pod -n "${restore_namespace}" -l app.kubernetes.io/name=smartcity-restore-timescaledb -o name 2>/dev/null | grep -q .; then
    break
  fi
  sleep 2
done
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=smartcity-restore-timescaledb \
  -n "${restore_namespace}" \
  --timeout=300s

pod="$(kubectl get pod -n "${restore_namespace}" -l app.kubernetes.io/name=smartcity-restore-timescaledb -o jsonpath='{.items[0].metadata.name}')"
kubectl exec -n "${restore_namespace}" "${pod}" -- pg_isready -U "${user}" -d "${db}"

for table in sensor_readings ingestion_metrics hourly_aggregates; do
  exists="$(kubectl exec -n "${restore_namespace}" "${pod}" -- psql -U "${user}" -d "${db}" -tAc "SELECT to_regclass('public.${table}') IS NOT NULL;")"
  if [[ "${exists}" != "t" ]]; then
    echo "ERROR: restored database is missing table/view ${table}." >&2
    exit 1
  fi
done

readings="$(kubectl exec -n "${restore_namespace}" "${pod}" -- psql -U "${user}" -d "${db}" -tAc "SELECT COUNT(*) FROM sensor_readings;")"
if [[ "${readings}" -le 0 ]]; then
  echo "ERROR: restored sensor_readings count is ${readings}; expected nonzero." >&2
  exit 1
fi

echo "Restore check passed in namespace ${restore_namespace}: sensor_readings=${readings}."
