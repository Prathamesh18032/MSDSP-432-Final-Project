#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${IMAGE_TAG:-}" ]]; then
  echo "ERROR: set IMAGE_TAG=<short-sha> to promote a specific published image tag." >&2
  exit 1
fi

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUNTIME_IMAGE_TAG="${IMAGE_TAG}" "${root_dir}/infra/cloud/scripts/k8s_render.sh"
"${root_dir}/infra/cloud/scripts/k8s_apply.sh"
RUNTIME_EXPECTED_IMAGE_TAG="${IMAGE_TAG}" "${root_dir}/infra/cloud/scripts/runtime_release_check.sh"
