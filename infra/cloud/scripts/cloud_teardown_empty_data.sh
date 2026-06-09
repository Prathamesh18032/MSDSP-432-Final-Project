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

cloud_teardown_assert_target_project "${project}"
cloud_teardown_require_ack "ALLOW_CLOUD_TEARDOWN_EMPTY_DATA" "yes" "Refusing to delete final cloud data without explicit teardown acknowledgement."

if command -v kubectl >/dev/null 2>&1; then
  rendered_dir="${CLOUD_TEARDOWN_ROOT_DIR}/infra/cloud/k8s/rendered"

  kubectl delete ingress smartcity-streamlit-public smartcity-grafana-public -n "${namespace}" --ignore-not-found || true
  kubectl delete managedcertificate smartcity-streamlit-cert smartcity-grafana-cert -n "${namespace}" --ignore-not-found 2>/dev/null || true
  kubectl delete backendconfig smartcity-streamlit-backend smartcity-grafana-backend -n "${namespace}" --ignore-not-found 2>/dev/null || true

  for manifest in public-demo.yaml grafana-public.yaml workloads.yaml serviceaccounts.yaml configmap.yaml grafana-provisioning.yaml; do
    if [[ -f "${rendered_dir}/${manifest}" ]]; then
      kubectl delete -f "${rendered_dir}/${manifest}" --ignore-not-found || true
    fi
  done

  kubectl delete pvc --all -n "${namespace}" --ignore-not-found --wait=true --timeout=300s || true
  kubectl delete namespace "${RESTORE_TEST_NAMESPACE:-smartcity-restore-test}" --ignore-not-found --wait=true --timeout=180s || true

  if [[ "${CLOUD_TEARDOWN_DELETE_NAMESPACE:-yes}" == "yes" ]]; then
    kubectl delete namespace "${namespace}" --ignore-not-found --wait=true --timeout=300s || true
  fi
else
  echo "kubectl is not installed; skipped Kubernetes manifest and PVC cleanup."
fi

if command -v gcloud >/dev/null 2>&1; then
  if gcloud storage buckets describe "gs://${bucket}" --project="${project}" >/dev/null 2>&1; then
    gcloud storage rm --recursive "gs://${bucket}/**" --project="${project}" --quiet || true
  else
    echo "GCS bucket gs://${bucket} is already absent."
  fi

  if gcloud artifacts repositories describe "${repository}" --location="${region}" --project="${project}" >/dev/null 2>&1; then
    images="${CLOUD_TEARDOWN_ARTIFACT_IMAGES:-smartcity-ingestor smartcity-writer smartcity-streamlit smartcity-video-agent}"
    for image in ${images}; do
      gcloud artifacts docker images delete "${region}-docker.pkg.dev/${project}/${repository}/${image}" \
        --project="${project}" \
        --delete-tags \
        --quiet || true
    done
  else
    echo "Artifact Registry repository ${repository} is already absent."
  fi
else
  echo "gcloud is not installed; skipped GCS object and Artifact Registry image cleanup."
fi

if command -v bq >/dev/null 2>&1; then
  if bq --project_id="${project}" show "${dataset}" >/dev/null 2>&1; then
    while IFS= read -r row; do
      table="${row%%,*}"
      [[ -n "${table}" && "${table}" != "tableId" && "${table}" != "sensor_readings_external" ]] || continue
      bq rm -f -t "${project}:${dataset}.${table}" || true
    done < <(bq --project_id="${project}" ls --format=csv "${dataset}" 2>/dev/null || true)
  else
    echo "BigQuery dataset ${dataset} is already absent."
  fi
else
  echo "bq is not installed; skipped extra BigQuery table cleanup."
fi

cat <<EOF

Cloud data cleanup phase completed.
Terraform-managed containers were intentionally left for Terraform destroy:
  gs://${bucket}
  BigQuery dataset ${dataset} and table sensor_readings_external
  Artifact Registry repository ${repository}
EOF
