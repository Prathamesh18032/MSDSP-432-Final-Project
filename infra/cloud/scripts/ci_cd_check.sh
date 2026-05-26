#!/usr/bin/env bash
set -euo pipefail

workflow=".github/workflows/publish-images.yml"

test -f "${workflow}"
grep -q "id-token: write" "${workflow}"
grep -q "google-github-actions/auth" "${workflow}"
grep -q "docker/login-action" "${workflow}"
grep -q "docker/build-push-action" "${workflow}"
grep -q "asia-south1-docker.pkg.dev" "${workflow}"
! grep -q "terraform apply" "${workflow}"
! grep -q "kubectl apply" "${workflow}"

echo "CI/CD image publishing workflow check passed."
