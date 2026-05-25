#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"
base_dir="${root_dir}/infra/cloud/k8s/base"
rendered_dir="${root_dir}/infra/cloud/k8s/rendered"
schema_file="${root_dir}/infra/local/timescaledb/init/001_schema.sql"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-}}"
region="$(tfvar gcp_region || true)"; region="${region:-${GCP_REGION:-asia-south1}}"
repository="$(tfvar artifact_registry_repository || true)"; repository="${repository:-${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}}"
namespace="$(tfvar gke_namespace || true)"; namespace="${namespace:-${GKE_NAMESPACE:-smartcity}}"
bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-}}"
dataset="$(tfvar bigquery_dataset || true)"; dataset="${dataset:-${BIGQUERY_DATASET:-smartcity_iot}}"
topic="$(tfvar pubsub_topic_name || true)"; topic="${topic:-${GCP_PUBSUB_TOPIC:-smartcity-readings}}"
dlq_topic="$(tfvar pubsub_dlq_topic_name || true)"; dlq_topic="${dlq_topic:-${GCP_PUBSUB_DLQ_TOPIC:-smartcity-dlq}}"
subscription="$(tfvar pubsub_subscription_name || true)"; subscription="${subscription:-${GCP_PUBSUB_SUBSCRIPTION:-smartcity-hot-writer}}"
image_registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repository}}"
runtime_tag="${RUNTIME_IMAGE_TAG:-slice17}"
timescale_db="${K8S_TIMESCALE_DB:-smartcity_hot}"
timescale_user="${K8S_TIMESCALE_USER:-smartcity}"
timescale_storage="${K8S_TIMESCALE_STORAGE_SIZE:-10Gi}"
timescale_image="${K8S_TIMESCALE_IMAGE:-timescale/timescaledb:latest-pg15}"

[[ -n "${project}" ]] || { echo "ERROR: GCP_PROJECT_ID is required for k8s rendering." >&2; exit 1; }
[[ -n "${bucket}" ]] || { echo "ERROR: GCS_BUCKET or terraform gcs_bucket is required for k8s rendering." >&2; exit 1; }
[[ -f "${schema_file}" ]] || { echo "ERROR: Timescale schema not found at ${schema_file}." >&2; exit 1; }

rm -rf "${rendered_dir}"
mkdir -p "${rendered_dir}"

render_file() {
  local source="$1"
  local target="$2"
  sed \
    -e "s|__GCP_PROJECT_ID__|${project}|g" \
    -e "s|__GCP_REGION__|${region}|g" \
    -e "s|__GKE_NAMESPACE__|${namespace}|g" \
    -e "s|__GCP_PUBSUB_TOPIC__|${topic}|g" \
    -e "s|__GCP_PUBSUB_DLQ_TOPIC__|${dlq_topic}|g" \
    -e "s|__GCP_PUBSUB_SUBSCRIPTION__|${subscription}|g" \
    -e "s|__GCS_BUCKET__|${bucket}|g" \
    -e "s|__BIGQUERY_DATASET__|${dataset}|g" \
    -e "s|__IMAGE_REGISTRY__|${image_registry}|g" \
    -e "s|__RUNTIME_IMAGE_TAG__|${runtime_tag}|g" \
    -e "s|__K8S_TIMESCALE_DB__|${timescale_db}|g" \
    -e "s|__K8S_TIMESCALE_USER__|${timescale_user}|g" \
    -e "s|__K8S_TIMESCALE_STORAGE_SIZE__|${timescale_storage}|g" \
    -e "s|__K8S_TIMESCALE_IMAGE__|${timescale_image}|g" \
    "${source}" > "${target}"
}

for file in namespace.yaml serviceaccounts.yaml configmap.yaml workloads.yaml; do
  render_file "${base_dir}/${file}" "${rendered_dir}/${file}"
done

{
  cat <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: smartcity-timescale-init
  namespace: ${namespace}
data:
  001_schema.sql: |
YAML
  sed 's/^/    /' "${schema_file}"
} > "${rendered_dir}/timescaledb-init.yaml"

echo "Rendered Kubernetes manifests to ${rendered_dir}"
echo "Image tag: ${runtime_tag}"
echo "Namespace: ${namespace}"
echo "TimescaleDB service: smartcity-timescaledb.${namespace}.svc.cluster.local"
