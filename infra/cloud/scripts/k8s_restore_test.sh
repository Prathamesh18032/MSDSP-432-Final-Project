#!/usr/bin/env bash
set -euo pipefail

if [[ -d "/opt/homebrew/share/google-cloud-sdk/bin" ]]; then
  export PATH="$PATH:/opt/homebrew/share/google-cloud-sdk/bin"
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
tfvars="${root_dir}/infra/cloud/terraform/terraform.tfvars"

tfvar() {
  local key="$1"
  if [[ -f "${tfvars}" ]]; then
    awk -F= -v key="${key}" '$1 ~ "^[[:space:]]*" key "[[:space:]]*$" {gsub(/[ \"\t]/, "", $2); print $2}' "${tfvars}"
  fi
}

bucket="$(tfvar gcs_bucket || true)"; bucket="${bucket:-${GCS_BUCKET:-}}"
project="$(tfvar gcp_project_id || true)"; project="${project:-${GCP_PROJECT_ID:-}}"
region="$(tfvar gcp_region || true)"; region="${region:-${GCP_REGION:-asia-south1}}"
repo="$(tfvar artifact_registry_repository || true)"; repo="${repo:-${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}}"
prefix="${TIMESCALE_BACKUP_PREFIX:-backups/timescaledb}"
restore_namespace="${RESTORE_TEST_NAMESPACE:-smartcity-restore-test}"
live_namespace="${GKE_NAMESPACE:-smartcity}"
storage_size="${RESTORE_TEST_STORAGE_SIZE:-5Gi}"
backup_uri="${RESTORE_TEST_BACKUP_URI:-latest}"
db="${K8S_TIMESCALE_DB:-smartcity_hot}"
user="${K8S_TIMESCALE_USER:-smartcity}"
password="${RESTORE_TEST_TIMESCALE_PASSWORD:-restore_test_password}"
timescale_image="${K8S_TIMESCALE_IMAGE:-timescale/timescaledb:latest-pg15}"
image_registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repo}}"
writer_image="${RESTORE_TEST_CLIENT_IMAGE:-${image_registry}/smartcity-writer:${RUNTIME_IMAGE_TAG:-latest-main}}"

if [[ -z "${bucket}" ]]; then
  echo "ERROR: GCS_BUCKET or terraform gcs_bucket is required." >&2
  exit 1
fi

if [[ "${restore_namespace}" == "${live_namespace}" || "${restore_namespace}" == "smartcity" ]]; then
  echo "ERROR: refusing to run restore test in live namespace ${restore_namespace}." >&2
  exit 1
fi

if [[ "${backup_uri}" == "latest" ]]; then
  backup_uri="$(gcloud storage ls "gs://${bucket}/${prefix}/**" 2>/dev/null | awk '/\.dump$/ {print $NF}' | sort | tail -1)"
fi

if [[ -z "${backup_uri}" ]]; then
  echo "ERROR: no TimescaleDB backup dump found under gs://${bucket}/${prefix}/." >&2
  exit 1
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "${tmp_dir}"' EXIT

echo "Using restore-test namespace: ${restore_namespace}"
echo "Using backup: ${backup_uri}"
gcloud storage cp "${backup_uri}" "${tmp_dir}/restore.dump"

kubectl delete namespace "${restore_namespace}" --ignore-not-found --wait=true --timeout=180s
kubectl create namespace "${restore_namespace}" --dry-run=client -o yaml | kubectl apply -f -
kubectl create secret generic smartcity-restore-test-secrets \
  --namespace "${restore_namespace}" \
  --from-literal "TIMESCALE_PASSWORD=${password}" \
  --dry-run=client -o yaml | kubectl apply -f -

cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: smartcity-restore-timescaledb
  namespace: ${restore_namespace}
  labels:
    app.kubernetes.io/name: smartcity-restore-timescaledb
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: smartcity-restore-timescaledb
  ports:
    - name: postgres
      port: 5432
      targetPort: postgres
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: smartcity-restore-timescaledb
  namespace: ${restore_namespace}
  labels:
    app.kubernetes.io/name: smartcity-restore-timescaledb
spec:
  serviceName: smartcity-restore-timescaledb
  replicas: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: smartcity-restore-timescaledb
  template:
    metadata:
      labels:
        app.kubernetes.io/name: smartcity-restore-timescaledb
    spec:
      containers:
        - name: timescaledb
          image: ${timescale_image}
          imagePullPolicy: IfNotPresent
          ports:
            - name: postgres
              containerPort: 5432
          env:
            - name: PGDATA
              value: /var/lib/postgresql/data/pgdata
            - name: POSTGRES_DB
              value: ${db}
            - name: POSTGRES_USER
              value: ${user}
            - name: POSTGRES_PASSWORD
              valueFrom:
                secretKeyRef:
                  name: smartcity-restore-test-secrets
                  key: TIMESCALE_PASSWORD
          readinessProbe:
            exec:
              command: ["pg_isready", "-U", "${user}", "-d", "${db}"]
            initialDelaySeconds: 20
            periodSeconds: 10
          resources:
            requests:
              cpu: 250m
              memory: 1Gi
            limits:
              cpu: "1"
              memory: 2Gi
          volumeMounts:
            - name: restore-timescale-data
              mountPath: /var/lib/postgresql/data
  volumeClaimTemplates:
    - metadata:
        name: restore-timescale-data
      spec:
        accessModes: ["ReadWriteOnce"]
        resources:
          requests:
            storage: ${storage_size}
YAML

for _ in {1..30}; do
  if kubectl get pod -n "${restore_namespace}" -l app.kubernetes.io/name=smartcity-restore-timescaledb -o name 2>/dev/null | grep -q .; then
    break
  fi
  sleep 2
done
kubectl wait --for=condition=Ready pod \
  -l app.kubernetes.io/name=smartcity-restore-timescaledb \
  -n "${restore_namespace}" \
  --timeout=300s

kubectl delete pod smartcity-restore-client -n "${restore_namespace}" --ignore-not-found
cat <<YAML | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: smartcity-restore-client
  namespace: ${restore_namespace}
  labels:
    app.kubernetes.io/name: smartcity-restore-client
spec:
  restartPolicy: Never
  containers:
    - name: writer
      image: ${writer_image}
      imagePullPolicy: IfNotPresent
      command: ["sh", "-c", "sleep 3600"]
      resources:
        requests:
          cpu: 100m
          memory: 128Mi
        limits:
          cpu: 500m
          memory: 512Mi
YAML
kubectl wait --for=condition=Ready pod/smartcity-restore-client -n "${restore_namespace}" --timeout=300s
kubectl cp "${tmp_dir}/restore.dump" "${restore_namespace}/smartcity-restore-client:/tmp/restore.dump"
kubectl exec -n "${restore_namespace}" smartcity-restore-client -- \
  env "PGPASSWORD=${password}" psql -h smartcity-restore-timescaledb -U "${user}" -d "${db}" \
  -c "CREATE EXTENSION IF NOT EXISTS timescaledb; SELECT timescaledb_pre_restore();"
kubectl exec -n "${restore_namespace}" smartcity-restore-client -- \
  env "PGPASSWORD=${password}" pg_restore --clean --if-exists --no-owner --no-acl \
  -h smartcity-restore-timescaledb -U "${user}" -d "${db}" /tmp/restore.dump
kubectl exec -n "${restore_namespace}" smartcity-restore-client -- \
  env "PGPASSWORD=${password}" psql -h smartcity-restore-timescaledb -U "${user}" -d "${db}" \
  -c "SELECT timescaledb_post_restore();"

"${root_dir}/infra/cloud/scripts/k8s_restore_check.sh"
echo "Restore test completed in isolated namespace ${restore_namespace}."
