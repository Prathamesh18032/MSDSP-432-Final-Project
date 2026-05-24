# Container Image Workflow

Slice 10 packaged the local-first application into deployable container images. Slice 12 adds the controlled Artifact Registry publishing workflow for those images.

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
make docker-build IMAGE_TAG=dev-pr-12
```

## Images

- `smartcity-ingestor`: runs the multi-source ingestor command.
- `smartcity-writer`: runs the cold Parquet export command.
- `smartcity-streamlit`: runs the Streamlit reports app.

## Smoke Checks

`make docker-smoke` confirms the images exist and can start. The Go images are expected to fail clearly when no TimescaleDB runtime connection is provided. The Streamlit image runs Python compile checks inside the container.

## Artifact Registry Push

Before the first push, run the bootstrap checks:

```sh
make gcp-bootstrap-check
make gcp-cost-guard-check
make artifact-registry-preview
```

Then create or verify the repository:

```sh
make artifact-registry-create
make artifact-registry-check
```

Build and publish with a reviewable tag:

```sh
make docker-build IMAGE_TAG=<tag>
make docker-smoke IMAGE_TAG=<tag>
make docker-tag-release IMAGE_TAG=<tag>
make docker-push IMAGE_TAG=<tag>
make artifact-registry-list
```

`artifact-registry-create` is the only setup command here that creates a live GCP resource. It enables Artifact Registry and creates one Docker repository if it is missing. The push commands publish images only; they do not deploy workloads.
