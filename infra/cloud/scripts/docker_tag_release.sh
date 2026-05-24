#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

info() {
  echo "OK: $*"
}

registry="${IMAGE_REGISTRY:-}"
tag="${IMAGE_TAG:-local}"
source_registry="${LOCAL_IMAGE_REGISTRY:-${registry}}"
source_tag="${LOCAL_IMAGE_TAG:-local}"

if [[ -z "${registry}" ]]; then
  fail "Set IMAGE_REGISTRY before tagging release images."
fi
if [[ "${registry}" != asia-south1-docker.pkg.dev/* ]]; then
  fail "IMAGE_REGISTRY should start with asia-south1-docker.pkg.dev for the India/Mumbai default. Current value: ${registry}"
fi

if [[ "${tag}" == "local" ]]; then
  echo "IMAGE_TAG is local; release tag already points at the local build tag."
fi

images=(smartcity-ingestor smartcity-writer smartcity-streamlit)

for image in "${images[@]}"; do
  target="${registry}/${image}:${tag}"
  source="${source_registry}/${image}:${source_tag}"

  if docker image inspect "${target}" >/dev/null 2>&1; then
    info "Target image already exists locally: ${target}"
    continue
  fi

  if ! docker image inspect "${source}" >/dev/null 2>&1; then
    fail "Missing local image ${target} and source image ${source}. Run: make docker-build IMAGE_TAG=${tag}"
  fi

  docker tag "${source}" "${target}"
  info "Tagged ${source} as ${target}"
done

echo
echo "Release image tags are available locally."
