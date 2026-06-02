#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"
base_dir="${root_dir}/infra/cloud/k8s/base"
rendered_dir="${root_dir}/infra/cloud/k8s/rendered"
schema_file="${root_dir}/infra/local/timescaledb/init/001_schema.sql"
grafana_dir="${root_dir}/infra/local/grafana/provisioning"

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
video_topic="$(tfvar video_pubsub_topic_name || true)"; video_topic="${video_topic:-${VIDEO_AGENT_PUBSUB_TOPIC:-smartcity-video-events}}"
video_subscription="$(tfvar video_pubsub_subscription_name || true)"; video_subscription="${video_subscription:-${VIDEO_AGENT_PUBSUB_SUBSCRIPTION:-smartcity-video-agent}}"
video_prefix="${VIDEO_AGENT_GCS_PREFIX:-video_inbox}"
video_agent_replicas="${VIDEO_AGENT_REPLICAS:-1}"
image_registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repository}}"
runtime_tag="${RUNTIME_IMAGE_TAG:-latest-main}"
timescale_db="${K8S_TIMESCALE_DB:-smartcity_hot}"
timescale_user="${K8S_TIMESCALE_USER:-smartcity}"
timescale_storage="${K8S_TIMESCALE_STORAGE_SIZE:-10Gi}"
timescale_image="${K8S_TIMESCALE_IMAGE:-timescale/timescaledb:latest-pg15}"
backup_schedule="${TIMESCALE_BACKUP_SCHEDULE:-0 */6 * * *}"
backup_prefix="${TIMESCALE_BACKUP_PREFIX:-backups/timescaledb}"
backup_retention_days="${TIMESCALE_BACKUP_RETENTION_DAYS:-14}"
public_demo_enabled="${PUBLIC_DEMO_ENABLED:-false}"
public_demo_domain="${PUBLIC_DEMO_DOMAIN:-}"
grafana_admin_user="${GRAFANA_ADMIN_USER:-admin}"
grafana_root_url="${GRAFANA_ROOT_URL:-}"
backup_schedule="${backup_schedule%\"}"
backup_schedule="${backup_schedule#\"}"

[[ -n "${project}" ]] || { echo "ERROR: GCP_PROJECT_ID is required for k8s rendering." >&2; exit 1; }
[[ -n "${bucket}" ]] || { echo "ERROR: GCS_BUCKET or terraform gcs_bucket is required for k8s rendering." >&2; exit 1; }
[[ -f "${schema_file}" ]] || { echo "ERROR: Timescale schema not found at ${schema_file}." >&2; exit 1; }
[[ -f "${grafana_dir}/dashboards/dashboard-provider.yml" ]] || { echo "ERROR: Grafana dashboard provider not found." >&2; exit 1; }
[[ -f "${grafana_dir}/dashboards/smart-city-operations.json" ]] || { echo "ERROR: Grafana dashboard JSON not found." >&2; exit 1; }
[[ -f "${grafana_dir}/datasources/timescaledb.yml" ]] || { echo "ERROR: Grafana datasource provisioning not found." >&2; exit 1; }
[[ -f "${grafana_dir}/alerting/smart-city-alerts.yml" ]] || { echo "ERROR: Grafana alert provisioning not found." >&2; exit 1; }

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
    -e "s|__VIDEO_AGENT_PUBSUB_TOPIC__|${video_topic}|g" \
    -e "s|__VIDEO_AGENT_PUBSUB_SUBSCRIPTION__|${video_subscription}|g" \
    -e "s|__VIDEO_AGENT_GCS_PREFIX__|${video_prefix}|g" \
    -e "s|__VIDEO_AGENT_REPLICAS__|${video_agent_replicas}|g" \
    -e "s|__GCS_BUCKET__|${bucket}|g" \
    -e "s|__BIGQUERY_DATASET__|${dataset}|g" \
    -e "s|__IMAGE_REGISTRY__|${image_registry}|g" \
    -e "s|__RUNTIME_IMAGE_TAG__|${runtime_tag}|g" \
    -e "s|__K8S_TIMESCALE_DB__|${timescale_db}|g" \
    -e "s|__K8S_TIMESCALE_USER__|${timescale_user}|g" \
    -e "s|__K8S_TIMESCALE_STORAGE_SIZE__|${timescale_storage}|g" \
    -e "s|__K8S_TIMESCALE_IMAGE__|${timescale_image}|g" \
    -e "s|__TIMESCALE_BACKUP_SCHEDULE__|${backup_schedule}|g" \
    -e "s|__TIMESCALE_BACKUP_PREFIX__|${backup_prefix}|g" \
    -e "s|__TIMESCALE_BACKUP_RETENTION_DAYS__|${backup_retention_days}|g" \
    -e "s|__PUBLIC_DEMO_ENABLED__|${public_demo_enabled}|g" \
    -e "s|__PUBLIC_DEMO_DOMAIN__|${public_demo_domain}|g" \
    -e "s|__GRAFANA_ADMIN_USER__|${grafana_admin_user}|g" \
    -e "s|__GRAFANA_ROOT_URL__|${grafana_root_url}|g" \
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

{
  cat <<YAML
apiVersion: v1
kind: ConfigMap
metadata:
  name: smartcity-grafana-provisioning
  namespace: ${namespace}
data:
  dashboard-provider.yml: |
YAML
  sed 's/^/    /' "${grafana_dir}/dashboards/dashboard-provider.yml"
  cat <<YAML
  smart-city-operations.json: |
YAML
  sed 's/^/    /' "${grafana_dir}/dashboards/smart-city-operations.json"
  cat <<YAML
  timescaledb.yml: |
YAML
  sed 's/^/    /' "${grafana_dir}/datasources/timescaledb.yml"
  cat <<YAML
  smart-city-alerts.yml: |
YAML
  sed 's/^/    /' "${grafana_dir}/alerting/smart-city-alerts.yml"
} > "${rendered_dir}/grafana-provisioning.yaml"

echo "Rendered Kubernetes manifests to ${rendered_dir}"
echo "Image tag: ${runtime_tag}"
echo "Namespace: ${namespace}"
echo "TimescaleDB service: smartcity-timescaledb.${namespace}.svc.cluster.local"
