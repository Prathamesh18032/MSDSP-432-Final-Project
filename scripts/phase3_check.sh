#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root_dir}"

required_files=(
  "docs/final/README.md"
  "docs/final/Project_Phase_3_Group4_Presentation.pptx"
  "docs/final/Project_Phase_3_Group4_Presentation.pdf"
  "docs/design/Project_Phase_2_Group4_Presentation.pdf"
  "infra/local/grafana/provisioning/dashboards/smart-city-operations.json"
)

for file in "${required_files[@]}"; do
  if [[ ! -s "${file}" ]]; then
    echo "ERROR: Missing or empty required Phase 3 file: ${file}" >&2
    exit 1
  fi
done

jq empty infra/local/grafana/provisioning/dashboards/smart-city-operations.json

make check
make test
make streamlit-check
make cloud-check
make ci-cd-check
docker compose config >/dev/null
git diff --check

manifest="$(mktemp)"
trap 'rm -f "${manifest}"' EXIT
git ls-files --cached --others --exclude-standard > "${manifest}"

while IFS= read -r file; do
  case "${file}" in
    .git/*|.cache/*|data/*|artifacts/*|outputs/*|dist/*|\
    .env|.env.local|.env.*.local|*/.env|*/.env.local|*/.env.*.local|\
    terraform.tfvars|*/terraform.tfvars|*.tfstate|*.tfstate.*|*.tfplan)
      echo "ERROR: Phase 3 package manifest contains forbidden path: ${file}" >&2
      exit 1
      ;;
  esac
done < "${manifest}"

echo "Phase 3 submission check passed."
