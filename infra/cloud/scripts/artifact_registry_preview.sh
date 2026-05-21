#!/usr/bin/env bash
set -euo pipefail

project="${GCP_PROJECT_ID:-YOUR_PROJECT_ID}"
region="${GCP_REGION:-asia-south1}"
repository="${ARTIFACT_REGISTRY_REPOSITORY:-smartcity}"
registry="${IMAGE_REGISTRY:-${region}-docker.pkg.dev/${project}/${repository}}"
tag="${IMAGE_TAG:-local}"

if [[ "${region}" != "asia-south1" ]]; then
  cat <<EOF
ERROR: GCP_REGION should be asia-south1 for the India/Mumbai default.
Current value: ${region}

Update your local .env:

GCP_REGION=asia-south1
IMAGE_REGISTRY=asia-south1-docker.pkg.dev/<your-project-id>/smartcity
EOF
  exit 1
fi

cat <<EOF
Artifact Registry preview only. These commands are NOT executed by this target.

After project, billing, budget alert, and auth are confirmed, Slice 12 can run:

gcloud config set project ${project}
gcloud config set compute/region ${region}
gcloud services enable artifactregistry.googleapis.com
gcloud artifacts repositories create ${repository} \\
  --repository-format=docker \\
  --location=${region} \\
  --description="Smart City service container images"
gcloud auth configure-docker ${region}-docker.pkg.dev

Then image tags would be:

${registry}/smartcity-ingestor:${tag}
${registry}/smartcity-writer:${tag}
${registry}/smartcity-streamlit:${tag}

And future pushes would look like:

docker push ${registry}/smartcity-ingestor:${tag}
docker push ${registry}/smartcity-writer:${tag}
docker push ${registry}/smartcity-streamlit:${tag}
EOF
