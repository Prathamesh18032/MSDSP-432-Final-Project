#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

restore_namespace="${RESTORE_TEST_NAMESPACE:-smartcity-restore-test}"
live_namespace="${GKE_NAMESPACE:-smartcity}"

if [[ "${restore_namespace}" == "${live_namespace}" || "${restore_namespace}" == "smartcity" ]]; then
  echo "ERROR: refusing to clean live namespace ${restore_namespace}." >&2
  exit 1
fi

kubectl delete namespace "${restore_namespace}" --ignore-not-found
echo "Restore-test namespace deleted or absent: ${restore_namespace}."
