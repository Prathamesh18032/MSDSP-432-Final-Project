#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"

"${root_dir}/infra/cloud/scripts/terraform_check.sh"

cd "${root_dir}/infra/cloud/terraform"
terraform init
