#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
port="${STREAMLIT_PORT:-8501}"

"${root_dir}/infra/cloud/scripts/runtime_scale_down.sh"

cat <<EOF
Demo runtime scale-down completed.

If a Streamlit port-forward is still running, stop it with Ctrl+C in that terminal.
If needed, find local listeners on port ${port} with:
  lsof -i tcp:${port}

TimescaleDB, PVC, backup CronJob, GCS, Pub/Sub, BigQuery, and Artifact Registry were not deleted.
EOF
