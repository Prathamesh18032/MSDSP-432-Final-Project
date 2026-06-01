#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source_dir="${VIDEO_AGENT_DATASET_DIR:-${root_dir}/data/video_inbox}"
bucket="${VIDEO_AGENT_GCS_BUCKET:-${GCS_BUCKET:-}}"
prefix="${VIDEO_AGENT_GCS_PREFIX:-video_inbox}"
dry_run="${1:-}"

if [[ -z "${bucket}" ]]; then
  echo "ERROR: set GCS_BUCKET or VIDEO_AGENT_GCS_BUCKET before uploading." >&2
  exit 1
fi
if [[ ! -d "${source_dir}" ]]; then
  echo "ERROR: dataset directory not found: ${source_dir}" >&2
  echo "Populate data/video_inbox/ with your image frames first." >&2
  exit 1
fi

total_mb=$(du -sm "${source_dir}" | cut -f1)
file_count=$(find "${source_dir}" -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.mp4" -o -iname "*.avi" \) | wc -l | tr -d ' ')
echo "Dataset: ${file_count} media files, ${total_mb} MB in ${source_dir}"

if [[ "${total_mb}" -gt 250 ]]; then
  echo "WARNING: ${total_mb} MB exceeds the expected 200 MB cap." >&2
  read -rp "Continue anyway? [y/N] " confirm
  [[ "${confirm}" =~ ^[Yy]$ ]] || exit 1
fi

if [[ "${dry_run}" == "--dry-run" ]]; then
  echo "DRY RUN — showing what would be uploaded:"
  gcloud storage rsync --recursive --dry-run "${source_dir}" "gs://${bucket}/${prefix}"
  echo "DRY RUN complete — nothing uploaded."
  exit 0
fi

gcloud storage rsync --recursive "${source_dir}" "gs://${bucket}/${prefix}"
echo "Uploaded ${file_count} files (${total_mb} MB) to gs://${bucket}/${prefix}"
echo ""
echo "Online inference pipeline is now active."
echo "Each new file in gs://${bucket}/${prefix} triggers:"
echo "  GCS notification -> Pub/Sub smartcity-video-events -> video-agent -> TimescaleDB -> Grafana"