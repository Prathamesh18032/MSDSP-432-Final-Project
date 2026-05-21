# Container Image Workflow

Slice 10 packages the local-first application into deployable container images without pushing to Google Cloud.

## Local Build

```sh
make docker-build
make docker-smoke
```

Default image names:

```text
asia-south1-docker.pkg.dev/replace-me-project/smartcity/smartcity-ingestor:local
asia-south1-docker.pkg.dev/replace-me-project/smartcity/smartcity-writer:local
asia-south1-docker.pkg.dev/replace-me-project/smartcity/smartcity-streamlit:local
```

Override the local tag when needed:

```sh
make docker-build IMAGE_TAG=dev-pr-10
```

## Images

- `smartcity-ingestor`: runs the multi-source ingestor command.
- `smartcity-writer`: runs the cold Parquet export command.
- `smartcity-streamlit`: runs the Streamlit reports app.

## Smoke Checks

`make docker-smoke` confirms the images exist and can start. The Go images are expected to fail clearly when no TimescaleDB runtime connection is provided. The Streamlit image runs Python compile checks inside the container.

## Future Artifact Registry Push

Do not push images until the team explicitly starts the Artifact Registry push slice. Before that, run the bootstrap checks:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
```

When the team is ready to push images:

1. Replace `replace-me-project` with the real `GCP_PROJECT_ID`.
2. Authenticate Docker to Artifact Registry with `gcloud auth configure-docker asia-south1-docker.pkg.dev`.
3. Rebuild images with a non-`local` tag.
4. Push images after the team confirms costs and repository permissions.

No GCP resources are created by this workflow.
