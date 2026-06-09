# Shared helpers for the final GCP teardown scripts.

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

CLOUD_TEARDOWN_SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLOUD_TEARDOWN_ROOT_DIR="$(cd "${CLOUD_TEARDOWN_SCRIPT_DIR}/../../.." && pwd)"
CLOUD_TEARDOWN_TF_DIR="${CLOUD_TEARDOWN_ROOT_DIR}/infra/cloud/terraform"
CLOUD_TEARDOWN_TFVARS="${CLOUD_TEARDOWN_TF_DIR}/terraform.tfvars"

cloud_teardown_tfvar() {
  local key="$1"
  if [[ -f "${CLOUD_TEARDOWN_TFVARS}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${CLOUD_TEARDOWN_TFVARS}"
  fi
}

cloud_teardown_project() {
  local value
  value="$(cloud_teardown_tfvar gcp_project_id || true)"
  value="${value:-${GCP_PROJECT_ID:-$(gcloud config get-value project 2>/dev/null || true)}}"
  printf '%s\n' "${value}"
}

cloud_teardown_region() {
  local value
  value="$(cloud_teardown_tfvar gcp_region || true)"
  value="${value:-${GCP_REGION:-$(gcloud config get-value compute/region 2>/dev/null || true)}}"
  printf '%s\n' "${value:-asia-south1}"
}

cloud_teardown_namespace() {
  local value
  value="$(cloud_teardown_tfvar gke_namespace || true)"
  value="${value:-${GKE_NAMESPACE:-smartcity}}"
  printf '%s\n' "${value}"
}

cloud_teardown_bucket() {
  local value
  value="$(cloud_teardown_tfvar gcs_bucket || true)"
  value="${value:-${GCS_BUCKET:-smartcity-zero-disk-iot-pa-cold}}"
  printf '%s\n' "${value}"
}

cloud_teardown_dataset() {
  local value
  value="$(cloud_teardown_tfvar bigquery_dataset || true)"
  value="${value:-${BIGQUERY_DATASET:-smartcity_iot}}"
  printf '%s\n' "${value}"
}

cloud_teardown_repository() {
  local value
  value="$(cloud_teardown_tfvar artifact_registry_repository || true)"
  value="${value:-${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}}"
  printf '%s\n' "${value}"
}

cloud_teardown_cluster() {
  local value
  value="$(cloud_teardown_tfvar gke_cluster_name || true)"
  value="${value:-${GKE_CLUSTER_NAME:-smartcity-autopilot}}"
  printf '%s\n' "${value}"
}

cloud_teardown_github_repository() {
  local value
  value="$(cloud_teardown_tfvar github_repository || true)"
  value="${value:-${GITHUB_REPOSITORY:-Prathamesh18032/MSDSP-432-Final-Project}}"
  printf '%s\n' "${value}"
}

cloud_teardown_fail() {
  echo "ERROR: $*" >&2
  exit 1
}

cloud_teardown_require_cmd() {
  local cmd="$1"
  command -v "${cmd}" >/dev/null 2>&1 || cloud_teardown_fail "${cmd} is required for this teardown phase."
}

cloud_teardown_assert_target_project() {
  local project="$1"
  local expected="${CLOUD_TEARDOWN_PROJECT_ID:-smartcity-zero-disk-iot-pa}"

  [[ -n "${project}" && "${project}" != "(unset)" ]] || cloud_teardown_fail "GCP project is not configured."

  if [[ "${project}" != "${expected}" && "${ALLOW_OTHER_PROJECT_TEARDOWN:-}" != "yes" ]]; then
    cloud_teardown_fail "Configured project is ${project}, expected ${expected}. Set ALLOW_OTHER_PROJECT_TEARDOWN=yes only if this cleanup is intentionally targeting another project."
  fi
}

cloud_teardown_require_ack() {
  local env_name="$1"
  local expected="$2"
  local explanation="$3"
  local actual="${!env_name:-}"

  if [[ "${actual}" != "${expected}" ]]; then
    echo "ERROR: ${explanation}" >&2
    echo "Set ${env_name}=${expected} to continue." >&2
    exit 1
  fi
}

cloud_teardown_run() {
  printf '+'
  printf ' %q' "$@"
  printf '\n'
  "$@"
}
