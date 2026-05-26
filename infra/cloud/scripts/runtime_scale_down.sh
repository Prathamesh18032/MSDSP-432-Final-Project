#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

namespace="${GKE_NAMESPACE:-smartcity}"

kubectl scale deploy/smartcity-ingestor deploy/smartcity-hot-writer deploy/smartcity-streamlit \
  --replicas=0 \
  -n "${namespace}"

echo "Scaled optional runtime deployments to zero in namespace ${namespace}."
echo "TimescaleDB StatefulSet, PVC, services, CronJobs, and cloud resources were left intact."
