# Project Tracker

Last updated: 2026-05-24

This file is the repo-level project memory for Group 4. Read it at the start of each work session before choosing the next slice.

## Current Snapshot

- Project: Smart City Zero-Disk IoT Infrastructure.
- Strategy: local-first MVP, cloud-ready architecture.
- Current branch of record: `main`.
- Latest merged slice: Slice 14, Cloud Pub/Sub adapter readiness.
- Active slice: Slice 15, Controlled core cloud apply and Pub/Sub hot-path smoke.
- Next planned slice after this PR merges: Slice 16, Cloud cold-path GCS/BigQuery Parquet export.
- Current working capability: deterministic Go simulator, OpenAQ, Open-Meteo, Divvy GBFS, and USGS pollers can generate or fetch smart-city readings, publish through a local queue buffer or Pub/Sub, insert into local TimescaleDB, export local Parquet cold-storage files, record ingestion metrics, visualize readings through Grafana dashboards, run local Streamlit reports, provide cloud-readiness Terraform/GKE manifests, build local deployable container images, publish those images to Artifact Registry in `asia-south1`, run safe GCP bootstrap checks, produce reviewable Terraform plans, and consume Pub/Sub readings into the local hot store. This PR adds the first guarded Terraform apply path for low-cost core GCP resources and live Pub/Sub hot-path smoke validation.
- Local checks expected to pass on `main`: `make check`, `make test`.
- Known blocker: GitHub branch protection for private repositories requires GitHub Pro or making the repo public. Direct-push protection is deferred.
- Operational note: Docker Compose stack is not assumed to be running. Start it with `make run-local` when needed.

## Completed Slices

| Slice | Description | PR | Status | Validation |
| --- | --- | --- | --- | --- |
| 1 | Repo Foundation | [#3](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/3) | Merged into `main` | `make check`, `docker compose config` |
| 2 | Simulator to TimescaleDB Vertical Slice | [#4](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/4) | Merged into `main` | `make test`, `make check`, `docker compose config`, `make seed-simulator`, Timescale row checks |
| 3 | Grafana datasource and starter dashboard provisioning | [#6](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/6) | Merged into `main` | `make check`, `make test`, `docker compose config`, Grafana datasource/dashboard API checks, Timescale row checks |
| 4 | OpenAQ poller integration | [#8](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/8) | Merged into `main` | `make check`, `make test`, `docker compose config`, live OpenAQ poll with API key, Timescale `source = 'openaq'` row checks |
| 5 | Queue abstraction and local buffering | [#10](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/10) | Merged into `main` | `make check`, `make test`, `docker compose config`, local buffer tests, Timescale `ingestion_metrics` row checks |
| 6 | Cold path and Parquet writer | [#11](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/11) | Merged into `main` | `make check`, `make test`, `docker compose config`, `make export-cold-demo`, Parquet file readback checks |
| 7 | Streamlit reports from local/seeded data | [#12](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/12) | Merged into `main` | `make check`, `make test`, `make streamlit-check`, `docker compose config`, Streamlit local and Compose smoke checks |
| 8 | Multi-source smart city sensor integration | [#13](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/13) | Merged into `main` | `make check`, `make test`, `docker compose config`, `make poll-multisource-once`, Timescale source checks for `openmeteo`, `gbfs`, and `usgs` |
| 9 | GCP infrastructure readiness docs/manifests | [#14](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/14) | Merged into `main` | `make check`, `make test`, `make streamlit-check`, `make cloud-check`, `docker compose config`, `git diff --check` |
| 10 | Container image packaging and deployment artifact readiness | [#15](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/15) | Merged into `main` | `make check`, `make test`, `make streamlit-check`, `make cloud-check`, `make docker-build`, `make docker-smoke`, `docker compose config`, `git diff --check` |
| 11 | GCP account bootstrap and Artifact Registry readiness | [#16](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/16) | Merged into `main` | `make check`, `make test`, `make streamlit-check`, `make cloud-check`, `make artifact-registry-preview`, expected bootstrap failure without local `gcloud`, `docker compose config`, `git diff --check` |
| 12 | Artifact Registry image publish readiness | [#17](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/17) | Merged into `main` | `make check`, `make test`, `make streamlit-check`, `make cloud-check`, `make gcp-bootstrap-check`, `make gcp-cost-guard-check`, `make artifact-registry-create`, `make artifact-registry-check`, `make docker-build IMAGE_TAG=slice12`, `make docker-smoke IMAGE_TAG=slice12`, `make docker-push IMAGE_TAG=slice12`, `make artifact-registry-list`, `docker compose config`, `git diff --check` |
| 13 | Terraform plan review for core GCP resources | [#18](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/18) | Merged into `main` | `make check`, `make test`, `make streamlit-check`, `make cloud-check`, `make gcp-bootstrap-check`, `make gcp-cost-guard-check`, `make terraform-check`, `make terraform-init`, `make terraform-validate`, `make terraform-plan`, `make terraform-show-plan`, `docker compose config`, `git diff --check` |
| 14 | Cloud Pub/Sub adapter readiness | [#19](https://github.com/Prathamesh18032/MSDSP-432-Final-Project/pull/19) | Merged into `main` | `make check`, `make test`, `make streamlit-check`, `make cloud-check`, `docker compose config`, `git diff --check`, `make docker-build`, `make docker-smoke` |
| 15 | Controlled core cloud apply and Pub/Sub hot-path smoke | This PR | Completes on merge | `make check`, `make test`, `make streamlit-check`, `make cloud-check`, `make gcp-bootstrap-check`, `make gcp-cost-guard-check`, `make terraform-check`, `make terraform-init`, `make terraform-import-artifact-registry`, `make terraform-validate`, `make terraform-plan`, `ALLOW_TERRAFORM_APPLY_CORE=yes make terraform-apply-core`, `make gcp-core-check`, `make pubsub-check`, `make docker-build IMAGE_TAG=slice15`, `make docker-smoke IMAGE_TAG=slice15`, `make docker-push IMAGE_TAG=slice15`, `make artifact-registry-list`, `make pubsub-hotpath-smoke`, `docker compose config`, `git diff --check` |

## Next Planned Slices

| Slice | Goal | Status | Default Owner |
| --- | --- | --- | --- |
| 16 | Cloud cold-path GCS/BigQuery Parquet export | Backlog | Storage / DevOps workstreams |

## Team Work Board

### Backlog

- Slice 16: Cloud cold-path GCS/BigQuery Parquet export.

### In Progress

- Slice 15: Controlled core cloud apply and Pub/Sub hot-path smoke, branch `codex/slice-15-core-cloud-apply`.

### In Review

- None.

### Done

- Slice 1: Repo Foundation, PR #3.
- Slice 2: Simulator to TimescaleDB Vertical Slice, PR #4.
- Slice 3: Grafana datasource and starter dashboard provisioning, PR #6.
- Slice 4: OpenAQ poller integration, PR #8.
- Slice 5: Queue abstraction and local buffering, PR #10.
- Slice 6: Cold path and Parquet writer, PR #11.
- Slice 7: Streamlit reports from local/seeded data, PR #12.
- Slice 8: Multi-source smart city sensor integration, PR #13.
- Slice 9: GCP infrastructure readiness docs/manifests, PR #14.
- Slice 10: Container image packaging and deployment artifact readiness, PR #15.
- Slice 11: GCP account bootstrap and Artifact Registry readiness, PR #16.
- Slice 12: Artifact Registry image publish readiness, PR #17.
- Slice 13: Terraform plan review for core GCP resources, PR #18.
- Slice 14: Cloud Pub/Sub adapter readiness, PR #19.
- Slice 15: Controlled core cloud apply and Pub/Sub hot-path smoke, this PR after merge.

## Workstreams

- Go ingestion: OpenAQ, Open-Meteo, GBFS, USGS, simulator, validator, retry/backoff, quality flags.
- Storage: TimescaleDB schema, inserts, aggregates, retention flush, Parquet path.
- Dashboards and analytics: Grafana provisioning, Streamlit reports, data-quality views.
- DevOps and cloud readiness: Compose, container images, GCP bootstrap checks, Artifact Registry publish workflow, Terraform plan/apply workflow, Pub/Sub adapter readiness, CI, Makefile, Terraform/GKE readiness manifests, setup docs.

## Update Protocol

- Mark a slice `Done` only after its PR is merged into `main`.
- Every PR that starts, changes, or completes a slice must update this file.
- Each active task should record owner, branch, PR number, status, validation, and blockers.
- Keep updates short and factual; put deeper technical details in runbooks or service docs.
- If a team member takes a slice, move it from `Backlog` to `In Progress` with their name and branch.
- For future implementation PRs, update the tracker to show the completed outcome for the slice and identify the next planned backlog slice before the PR is merged.
- After merge, pull `main` locally and confirm the tracker already reflects the completed slice.

## Resume Protocol

At the start of a new day, new branch, or new chat:

```sh
git switch main
git pull origin main
git status --short --branch
make check
make test
```

Then read this tracker, pick the next `Backlog` slice, create a `codex/<slice-name>` or teammate feature branch, and update this file in the PR.

## Handoff Notes

- 2026-05-21: Completed and merged Slice 1 through Slice 11. Started Slice 12 Artifact Registry image publish readiness on branch `codex/slice-12-artifact-registry-publish`. Local `main` was updated after PR #16. Branch protection attempt was blocked by GitHub plan/private repo limitations.
- 2026-05-24: Completed Slice 12 local and live GCP validation. Configured `gcloud` for project `smartcity-zero-disk-iot-pa` in `asia-south1`, created Artifact Registry repository `smartcity`, and pushed `slice12` images for ingestor, writer, and Streamlit.
- 2026-05-24: Started Slice 13 Terraform plan review on branch `codex/slice-13-terraform-plan-review`. Slice 13 is plan-only and must not run `terraform apply`.
- 2026-05-24: Completed and merged Slice 13 / PR #18. Started Slice 14 Pub/Sub adapter readiness on branch `codex/slice-14-pubsub-adapter-readiness`. Slice 14 must not create Pub/Sub resources or run Terraform apply.
- 2026-05-24: Completed and merged Slice 14 / PR #19. Started Slice 15 controlled core cloud apply on branch `codex/slice-15-core-cloud-apply`. Slice 15 may apply only low-cost core GCP resources behind the explicit `ALLOW_TERRAFORM_APPLY_CORE=yes` guard.
