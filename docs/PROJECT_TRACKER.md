# Project Tracker

Last updated: 2026-05-20

This file is the repo-level project memory for Group 4. Read it at the start of each work session before choosing the next slice.

## Current Snapshot

- Project: Smart City Zero-Disk IoT Infrastructure.
- Strategy: local-first MVP, cloud-ready architecture.
- Current branch of record: `main`.
- Latest merged slice: Slice 5, Queue abstraction and local buffering.
- Next planned slice: Slice 6, Cold path and Parquet writer.
- Current working capability: deterministic Go simulator and OpenAQ poller can generate or fetch smart-city readings, publish through a local queue buffer, insert into local TimescaleDB, record ingestion metrics, and visualize readings through provisioned Grafana dashboards.
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
| 5 | Queue abstraction and local buffering | This PR | Completes on merge | `make check`, `make test`, `docker compose config`, local buffer tests, Timescale `ingestion_metrics` row checks |

## Next Planned Slices

| Slice | Goal | Status | Default Owner |
| --- | --- | --- | --- |
| 6 | Cold path and Parquet writer | Backlog | Storage workstream |
| 7 | Streamlit reports from local/seeded data | Backlog | Analytics workstream |
| 8 | GCP infrastructure readiness docs/manifests | Backlog | DevOps workstream |

## Team Work Board

### Backlog

- Slice 6: Cold path and Parquet writer.
- Slice 7: Streamlit reports from local/seeded data.
- Slice 8: GCP infrastructure readiness docs/manifests.

### In Progress

- None.

### In Review

- None.

### Done

- Slice 1: Repo Foundation, PR #3.
- Slice 2: Simulator to TimescaleDB Vertical Slice, PR #4.
- Slice 3: Grafana datasource and starter dashboard provisioning, PR #6.
- Slice 4: OpenAQ poller integration, PR #8.
- Slice 5: Queue abstraction and local buffering, this PR after merge.

## Workstreams

- Go ingestion: source clients, simulator, validator, retry/backoff, quality flags.
- Storage: TimescaleDB schema, inserts, aggregates, retention flush, Parquet path.
- Dashboards and analytics: Grafana provisioning, Streamlit reports, data-quality views.
- DevOps and cloud readiness: Compose, CI, Makefile, Terraform/Kubernetes placeholders, setup docs.

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

- 2026-05-21: Completed and merged Slice 1 through Slice 4. Started Slice 5 queue abstraction and local buffering. Local `main` was updated after PR #9. `gh` CLI was installed and authenticated. Branch protection attempt was blocked by GitHub plan/private repo limitations.
