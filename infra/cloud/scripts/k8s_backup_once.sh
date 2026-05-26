#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rendered_namespace="$(awk '/^  name: / {print $2; exit}' "${root_dir}/infra/cloud/k8s/rendered/namespace.yaml" 2>/dev/null || true)"
namespace="${GKE_NAMESPACE:-${rendered_namespace:-smartcity}}"
job_name="smartcity-timescale-backup-manual-$(date +%Y%m%d%H%M%S)"

kubectl create job -n "${namespace}" --from=cronjob/smartcity-timescale-backup "${job_name}"
kubectl wait -n "${namespace}" --for=condition=complete "job/${job_name}" --timeout="${TIMESCALE_BACKUP_JOB_TIMEOUT:-600s}"
kubectl logs -n "${namespace}" "job/${job_name}" --all-containers=true

echo "Manual TimescaleDB backup job completed: ${job_name}"
