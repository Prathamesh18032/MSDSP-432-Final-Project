#!/usr/bin/env bash
set -euo pipefail

url_output="$(infra/cloud/scripts/public_demo_url.sh)"
echo "${url_output}"
url="$(awk -F': ' '/Public demo URL/ {print $2; exit}' <<<"${url_output}")"

if [[ -z "${url}" ]]; then
  echo "ERROR: public demo URL is not available." >&2
  exit 1
fi

health_url="${url%/}/_stcore/health"
curl -fsSL --max-time 20 "${health_url}" >/dev/null
echo "Public demo health check passed: ${health_url}"
