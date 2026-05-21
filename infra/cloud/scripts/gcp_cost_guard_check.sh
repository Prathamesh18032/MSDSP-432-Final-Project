#!/usr/bin/env bash
set -euo pipefail

fail() {
  echo "ERROR: $*" >&2
  exit 1
}

budget="${BUDGET_ALERT_AMOUNT_USD:-}"
if [[ -z "${budget}" ]]; then
  fail "Set BUDGET_ALERT_AMOUNT_USD in your local .env after creating a Google Cloud budget alert."
fi

if ! [[ "${budget}" =~ ^[0-9]+([.][0-9]+)?$ ]]; then
  fail "BUDGET_ALERT_AMOUNT_USD must be numeric. Current value: ${budget}"
fi

project="${GCP_PROJECT_ID:-}"
if [[ -z "${project}" ]]; then
  fail "Set GCP_PROJECT_ID in your local .env before cloud work."
fi

region="${GCP_REGION:-}"
if [[ "${region}" != "asia-south1" ]]; then
  fail "Set GCP_REGION=asia-south1 in your local .env for the India/Mumbai default."
fi

echo "OK: Cost guard values are documented locally for project ${project}, region ${region}, budget alert USD ${budget}."
echo "This check did not create or inspect any billing resources."
