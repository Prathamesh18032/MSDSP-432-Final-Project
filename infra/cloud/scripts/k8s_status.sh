#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
rendered_namespace="$(awk '/^  name: / {print $2; exit}' "${root_dir}/infra/cloud/k8s/rendered/namespace.yaml" 2>/dev/null || true)"
namespace="${GKE_NAMESPACE:-${rendered_namespace:-smartcity}}"

kubectl get namespace "${namespace}"
kubectl get serviceaccount -n "${namespace}"
kubectl get statefulset,deploy,cronjob,svc,pod -n "${namespace}" -o wide
