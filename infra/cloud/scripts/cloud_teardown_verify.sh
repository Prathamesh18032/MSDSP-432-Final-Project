#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/cloud_teardown_lib.sh"

project="$(cloud_teardown_project)"
region="$(cloud_teardown_region)"

cloud_teardown_assert_target_project "${project}"
cloud_teardown_require_cmd gcloud

failed=0

check_empty() {
  local label="$1"
  shift
  local output
  output="$("$@" 2>/dev/null || true)"
  if [[ -n "${output//[[:space:]]/}" ]]; then
    echo "ERROR: ${label} still present:"
    echo "${output}"
    failed=1
  else
    echo "OK: no ${label}"
  fi
}

lifecycle="$(gcloud projects describe "${project}" --format='value(lifecycleState)' 2>/dev/null || true)"
if [[ "${lifecycle}" == "DELETE_REQUESTED" ]]; then
  echo "OK: project ${project} is already pending deletion."
  exit 0
fi

echo "Project lifecycle: ${lifecycle:-unknown}"
billing_enabled="$(gcloud billing projects describe "${project}" --format='value(billingEnabled)' 2>/dev/null || true)"
echo "Billing enabled: ${billing_enabled:-unknown}"

if command -v terraform >/dev/null 2>&1 && [[ -d "${CLOUD_TEARDOWN_TF_DIR}/.terraform" ]]; then
  state_list="$(terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" state list 2>/dev/null || true)"
  non_data_state="$(printf '%s\n' "${state_list}" | awk 'NF && $1 !~ /^data\./ {print}')"
  if [[ -n "${non_data_state}" ]]; then
    echo "ERROR: Terraform state still contains managed resources:"
    echo "${non_data_state}"
    failed=1
  else
    echo "OK: Terraform state has no managed resources."
  fi
else
  echo "WARNING: Terraform is unavailable or uninitialized; skipped local state verification."
fi

check_empty "GKE clusters" gcloud container clusters list --project="${project}" --format='value(name)'
check_empty "Compute disks" gcloud compute disks list --project="${project}" --format='value(name)'
check_empty "Compute snapshots" gcloud compute snapshots list --project="${project}" --format='value(name)'
check_empty "Compute addresses" gcloud compute addresses list --project="${project}" --format='value(name)'
check_empty "Compute forwarding rules" gcloud compute forwarding-rules list --project="${project}" --format='value(name)'
check_empty "Pub/Sub topics" gcloud pubsub topics list --project="${project}" --format='value(name)'
check_empty "Pub/Sub subscriptions" gcloud pubsub subscriptions list --project="${project}" --format='value(name)'
check_empty "Cloud Storage buckets" gcloud storage buckets list --project="${project}" --format='value(name)'
check_empty "Artifact Registry repositories" gcloud artifacts repositories list --location="${region}" --project="${project}" --format='value(name)'
check_empty "smartcity service accounts" gcloud iam service-accounts list --project="${project}" --filter='email~smartcity' --format='value(email)'
check_empty "Workload Identity pools" gcloud iam workload-identity-pools list --location=global --project="${project}" --format='value(name)'

if command -v bq >/dev/null 2>&1; then
  datasets="$(bq --project_id="${project}" ls --format=csv 2>/dev/null | awk -F, 'NR > 1 && $1 != "" {print $1}' || true)"
  if [[ -n "${datasets}" ]]; then
    echo "ERROR: BigQuery datasets still present:"
    echo "${datasets}"
    failed=1
  else
    echo "OK: no BigQuery datasets"
  fi
else
  echo "WARNING: bq is unavailable; skipped BigQuery dataset verification."
fi

if [[ "${failed}" != "0" ]]; then
  echo
  echo "Cloud teardown verification failed. Resolve listed resources, then rerun make cloud-teardown-verify."
  exit 1
fi

cat <<EOF

Cloud teardown verification passed for ${project}.
Final billing/project shutdown commands:
  gcloud billing projects unlink ${project}
  gcloud projects delete ${project}
EOF
