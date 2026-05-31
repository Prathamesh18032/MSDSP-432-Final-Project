#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${root_dir}"

zip_path="dist/Project_Phase_3_Group4.zip"

if [[ ! -f "${zip_path}" ]]; then
  echo "ERROR: Missing ${zip_path}. Run: make phase3-package" >&2
  exit 1
fi

unzip -l "${zip_path}"
