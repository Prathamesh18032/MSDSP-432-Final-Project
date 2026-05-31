#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root_dir}"

zip_path="dist/Project_Phase_3_Group4.zip"
manifest="$(mktemp)"
trap 'rm -f "${manifest}"' EXIT

mkdir -p dist
rm -f "${zip_path}"

git ls-files --cached --others --exclude-standard > "${manifest}"

while IFS= read -r file; do
  case "${file}" in
    .git/*|.cache/*|data/*|artifacts/*|outputs/*|dist/*|\
    .env|.env.local|.env.*.local|*/.env|*/.env.local|*/.env.*.local|\
    terraform.tfvars|*/terraform.tfvars|*.tfstate|*.tfstate.*|*.tfplan)
      echo "ERROR: Refusing to package forbidden path: ${file}" >&2
      exit 1
      ;;
  esac
done < "${manifest}"

zip -q -X "${zip_path}" -@ < "${manifest}"

echo "Created ${zip_path}"
