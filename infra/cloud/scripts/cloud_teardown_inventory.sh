#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${script_dir}/cloud_teardown_lib.sh"

project="$(cloud_teardown_project)"
region="$(cloud_teardown_region)"
namespace="$(cloud_teardown_namespace)"
bucket="$(cloud_teardown_bucket)"
dataset="$(cloud_teardown_dataset)"
repository="$(cloud_teardown_repository)"
cluster="$(cloud_teardown_cluster)"
stamp="$(date -u +%Y%m%dT%H%M%SZ)"
evidence_dir="${CLOUD_TEARDOWN_EVIDENCE_DIR:-${CLOUD_TEARDOWN_ROOT_DIR}/artifacts/evidence/cloud-teardown/${stamp}}"

cloud_teardown_assert_target_project "${project}"
mkdir -p "${evidence_dir}"

capture_cmd() {
  local name="$1"
  shift
  local file="${evidence_dir}/${name}.txt"

  {
    printf '$'
    printf ' %q' "$@"
    printf '\n\n'
    "$@"
  } >"${file}" 2>&1 || true

  echo "Wrote ${file}"
}

capture_note() {
  local name="$1"
  local text="$2"
  printf '%s\n' "${text}" >"${evidence_dir}/${name}.txt"
  echo "Wrote ${evidence_dir}/${name}.txt"
}

cat >"${evidence_dir}/summary.txt" <<EOF
Cloud teardown inventory
captured_at_utc=${stamp}
project=${project}
region=${region}
namespace=${namespace}
cluster=${cluster}
bucket=${bucket}
dataset=${dataset}
artifact_repository=${repository}
EOF
echo "Wrote ${evidence_dir}/summary.txt"

if command -v terraform >/dev/null 2>&1; then
  capture_cmd terraform-workspace terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" workspace show
  capture_cmd terraform-state-list terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" state list
  capture_cmd terraform-output terraform -chdir="${CLOUD_TEARDOWN_TF_DIR}" output
else
  capture_note terraform-missing "terraform is not installed."
fi

if command -v gcloud >/dev/null 2>&1; then
  capture_cmd gcloud-auth gcloud auth list
  capture_cmd gcloud-project gcloud projects describe "${project}" --format=json
  capture_cmd gcloud-billing gcloud billing projects describe "${project}" --format=json
  capture_cmd gcloud-enabled-services gcloud services list --enabled --project="${project}" --format='value(config.name)'
  capture_cmd gke-clusters gcloud container clusters list --project="${project}"
  capture_cmd gke-target-cluster gcloud container clusters describe "${cluster}" --region="${region}" --project="${project}"
  capture_cmd compute-addresses gcloud compute addresses list --project="${project}"
  capture_cmd compute-forwarding-rules gcloud compute forwarding-rules list --project="${project}"
  capture_cmd compute-disks gcloud compute disks list --project="${project}"
  capture_cmd compute-snapshots gcloud compute snapshots list --project="${project}"
  capture_cmd pubsub-topics gcloud pubsub topics list --project="${project}"
  capture_cmd pubsub-subscriptions gcloud pubsub subscriptions list --project="${project}"
  capture_cmd storage-buckets gcloud storage buckets list --project="${project}"
  capture_cmd storage-target-bucket gcloud storage buckets describe "gs://${bucket}" --project="${project}"
  if [[ "${CLOUD_TEARDOWN_LIST_GCS_OBJECTS:-yes}" == "yes" ]]; then
    capture_cmd storage-target-objects gcloud storage ls -l "gs://${bucket}/**"
  fi
  capture_cmd artifact-repositories gcloud artifacts repositories list --location="${region}" --project="${project}"
  capture_cmd artifact-images gcloud artifacts docker images list "${region}-docker.pkg.dev/${project}/${repository}" --project="${project}" --include-tags
  capture_cmd service-accounts gcloud iam service-accounts list --project="${project}" --filter='email~smartcity'
  capture_cmd workload-identity-pools gcloud iam workload-identity-pools list --location=global --project="${project}"
else
  capture_note gcloud-missing "gcloud is not installed."
fi

if command -v bq >/dev/null 2>&1; then
  capture_cmd bigquery-datasets bq --project_id="${project}" ls
  capture_cmd bigquery-target-dataset bq --project_id="${project}" ls "${dataset}"
  capture_cmd bigquery-target-table bq --project_id="${project}" show "${dataset}.sensor_readings_external"
else
  capture_note bq-missing "bq is not installed."
fi

if command -v kubectl >/dev/null 2>&1; then
  capture_cmd kubectl-context kubectl config current-context
  capture_cmd k8s-namespace kubectl get namespace "${namespace}" -o wide
  capture_cmd k8s-workloads kubectl get all -n "${namespace}" -o wide
  capture_cmd k8s-ingress kubectl get ingress -n "${namespace}" -o wide
  capture_cmd k8s-pvc kubectl get pvc -n "${namespace}" -o wide
  capture_cmd k8s-pv kubectl get pv -o wide
  capture_cmd k8s-cronjobs kubectl get cronjob -n "${namespace}" -o wide
  capture_cmd k8s-jobs kubectl get jobs -n "${namespace}" -o wide
  capture_cmd k8s-managed-certificates kubectl get managedcertificate -n "${namespace}" -o wide
  capture_cmd k8s-backend-configs kubectl get backendconfig -n "${namespace}" -o wide
else
  capture_note kubectl-missing "kubectl is not installed."
fi

echo
echo "Cloud teardown inventory captured in ${evidence_dir}"
echo "Evidence files are under artifacts/ and are ignored by Git."
