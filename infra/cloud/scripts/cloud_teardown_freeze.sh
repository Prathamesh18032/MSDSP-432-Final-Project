#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/cloud_teardown_lib.sh"

project="$(cloud_teardown_project)"
namespace="$(cloud_teardown_namespace)"
github_repository="$(cloud_teardown_github_repository)"

cloud_teardown_assert_target_project "${project}"
cloud_teardown_require_ack "ALLOW_CLOUD_TEARDOWN_FREEZE" "yes" "Refusing to freeze the final cloud runtime without explicit teardown acknowledgement."

if command -v kubectl >/dev/null 2>&1; then
  export PUBLIC_DEMO_DELETE_STATIC_IP="${PUBLIC_DEMO_DELETE_STATIC_IP:-yes}"
  export PUBLIC_GRAFANA_DELETE_STATIC_IP="${PUBLIC_GRAFANA_DELETE_STATIC_IP:-yes}"

  "${CLOUD_TEARDOWN_ROOT_DIR}/infra/cloud/scripts/public_demo_disable.sh" || true
  "${CLOUD_TEARDOWN_ROOT_DIR}/infra/cloud/scripts/grafana_public_disable.sh" || true

  while IFS= read -r cronjob; do
    [[ -n "${cronjob}" ]] || continue
    kubectl patch "${cronjob}" -n "${namespace}" --type merge -p '{"spec":{"suspend":true}}' >/dev/null 2>&1 || true
  done < <(kubectl get cronjob -n "${namespace}" -o name 2>/dev/null || true)

  kubectl scale deploy/smartcity-ingestor deploy/smartcity-hot-writer deploy/smartcity-streamlit deploy/smartcity-video-agent \
    --replicas=0 \
    -n "${namespace}" || true

  kubectl scale statefulset/smartcity-timescaledb \
    --replicas=0 \
    -n "${namespace}" || true

  kubectl get deploy,statefulset,cronjob,ingress,pvc -n "${namespace}" -o wide || true
else
  echo "kubectl is not installed; skipped Kubernetes freeze. Run this target from a machine with cluster access before destroy."
fi

if [[ "${TEARDOWN_REMOVE_GITHUB_VARS:-}" == "yes" ]]; then
  cloud_teardown_require_cmd gh
  for variable in GCP_WORKLOAD_IDENTITY_PROVIDER GCP_CI_SERVICE_ACCOUNT; do
    gh api -X DELETE "repos/${github_repository}/actions/variables/${variable}" --silent || true
    echo "Requested deletion of GitHub Actions variable ${variable} from ${github_repository}."
  done
else
  cat <<EOF

GitHub Actions promotion variables were not removed automatically.
To stop runtime promotion credentials, either rerun with TEARDOWN_REMOVE_GITHUB_VARS=yes or delete:
  GCP_WORKLOAD_IDENTITY_PROVIDER
  GCP_CI_SERVICE_ACCOUNT
from repository ${github_repository}.
EOF
fi

echo
echo "Cloud teardown freeze completed for ${project}."
