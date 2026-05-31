#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
RUNTIME_IMAGE_TAG=latest-main "${root_dir}/infra/cloud/scripts/k8s_render.sh"
"${root_dir}/infra/cloud/scripts/k8s_apply.sh"
RUNTIME_EXPECTED_IMAGE_TAG=latest-main "${root_dir}/infra/cloud/scripts/runtime_release_check.sh"
