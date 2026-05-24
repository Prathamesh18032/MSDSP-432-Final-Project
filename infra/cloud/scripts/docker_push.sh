#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

registry="${IMAGE_REGISTRY:-}"
tag="${IMAGE_TAG:-local}"

if [[ -z "${registry}" ]]; then
  fail "Set IMAGE_REGISTRY before pushing images."
fi
if [[ "${registry}" != asia-south1-docker.pkg.dev/* ]]; then
  fail "IMAGE_REGISTRY should start with asia-south1-docker.pkg.dev for the India/Mumbai default. Current value: ${registry}"
fi
if [[ "${registry}" == *"replace-me-project"* || "${registry}" == *"<your-project-id>"* ]]; then
  fail "IMAGE_REGISTRY still contains a project placeholder. Set your real Artifact Registry path before pushing."
fi

images=(smartcity-ingestor smartcity-writer smartcity-streamlit)

for image in "${images[@]}"; do
  target="${registry}/${image}:${tag}"
  if ! docker image inspect "${target}" >/dev/null 2>&1; then
    fail "Local image is missing: ${target}. Run: make docker-build IMAGE_TAG=${tag}"
  fi
done

for image in "${images[@]}"; do
  target="${registry}/${image}:${tag}"
  docker push "${target}"
done

echo
echo "All configured images were pushed to ${registry} with tag ${tag}."
