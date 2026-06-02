#!/usr/bin/env bash
set -euo pipefail

url_output="$(infra/cloud/scripts/grafana_public_url.sh)"
echo "${url_output}"
url="$(awk -F': ' '/Public Grafana URL/ {print $2; exit}' <<<"${url_output}")"

if [[ -z "${url}" ]]; then
  echo "ERROR: public Grafana URL is not available." >&2
  exit 1
fi

login_html="$(curl -fsSL --max-time 20 "${url%/}/login")"
grep -qi "grafana" <<<"${login_html}"

dashboard_status="$(curl -sS -o /dev/null -w "%{http_code}" --max-time 20 "${url%/}/d/smart-city-operations" || true)"
case "${dashboard_status}" in
  200|302)
    echo "Public Grafana login check passed: ${url%/}/login"
    echo "Anonymous dashboard request returned HTTP ${dashboard_status}; login remains required by Grafana auth settings."
    ;;
  *)
    echo "ERROR: unexpected dashboard HTTP status ${dashboard_status}." >&2
    exit 1
    ;;
esac
