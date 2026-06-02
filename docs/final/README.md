# Phase 3 Final Submission Guide

Phase 3 is the final implementation submission for Group 4's Smart City Zero-Disk IoT Infrastructure project.

## Official Rubric

- Due: Monday, June 8, 2026 at 10:29am.
- Total: 60 points.
- Code submission: 45 points. Submit all project code as `Project_Phase_3_GroupName.zip`; for this team, use `Project_Phase_3_Group4.zip`.
- Class presentation: 15 points. Present the implemented backend/data engineering pipeline and the reporting surfaces during the Week 10 sync session.

One team member should submit the zip file. Before submission, run:

```sh
make phase3-check
make phase3-package
make phase3-package-list
```

The package target writes `dist/Project_Phase_3_Group4.zip` and excludes local secrets, caches, runtime data, generated evidence, and cloud state.

## Implementation Story

The Phase 3 story should be implementation-first. Phase 2 remains the design blueprint; Phase 3 proves the system was built.

Backend/data engineering proof:

- Go ingestion services poll simulator, OpenAQ, Open-Meteo, Divvy GBFS, and USGS data.
- Readings are validated, normalized, quality-flagged, and published through local buffering or Pub/Sub.
- TimescaleDB is the hot operational store for current city readings and ingestion metrics.
- Parquet exports support the cold path locally and through GCS-backed BigQuery external-table validation.
- GKE Autopilot runs the cloud runtime with internal TimescaleDB, workload identity, CI-published images, runtime promotion, health checks, backups, restore tests, and cost controls.

Reporting proof:

- Streamlit is the polished public command center for executive review, city operations, source-specific reporting, maps, and historical/cold-path evidence.
- Grafana is the local enterprise operations dashboard for ingestion observability, sensor estate, source/metric coverage, geomap, and data quality.

## Demo Path

Local reviewer path:

```sh
make run-local
make seed-simulator
make poll-multisource-once
make grafana-demo-ready
make run-streamlit
```

Open:

- Grafana: `http://localhost:3000`, local default login `admin / admin`, dashboard `Smart City Enterprise Operations`.
- Streamlit: `http://localhost:8501`.

Cloud/runtime path, when credentials and live project access are configured:

```sh
make runtime-demo-mode
make runtime-health
make runtime-release-check
make runtime-cost-report
make runtime-evidence
make public-demo-url
make public-demo-smoke
```

After review windows, use the project runbooks to disable public ingress or idle optional runtime workloads.

## Presentation Guide

Use `docs/final/Project_Phase_3_Group4_Presentation.pptx` for the Week 10 presentation. A PDF backup is available at `docs/final/Project_Phase_3_Group4_Presentation.pdf`.

The deck should spend minimal time repeating Phase 2 design material. The preferred flow is:

1. Anchor the original Phase 2 blueprint.
2. Show the implemented backend and reporting architecture.
3. Prove live-data ingestion, hot/cold storage, cloud runtime, CI/CD, backups, restore tests, and cost controls.
4. Demo Streamlit and Grafana as complementary reporting and operations surfaces.
5. Close with safety, privacy, security, and future AI Agent scope.

## Safety, Privacy, And Security

This project is intentionally reviewer-safe:

- The final zip excludes `.env`, Terraform state, local data, generated evidence, caches, and package output.
- Public demo ingress exposes Streamlit with `STREAMLIT_DEMO_PASSWORD`; Grafana can be exposed separately with a non-default `GRAFANA_ADMIN_PASSWORD` for demo week.
- Backend services remain private inside the runtime network.
- GCP apply and public ingress flows are guarded by explicit environment flags.
- Runtime cost controls support demo, idle, resume, and scale-down modes.
- Backup and restore workflows validate recoverability without deleting hot TimescaleDB data.
- No service-account keys are committed; cloud flows use local credentials or GitHub OIDC.

## Optional Scope: AI Agents In Smart City IoT

AI Agent features are optional demo scope above the implemented data platform. If enabled, the video agent runs local/open-source inference over public demo clips and writes human-review flags into TimescaleDB for Grafana:

- Inference-only video safety agent; no LLM API key, training job, or fine-tuning is required.
- Demo data lands under `gs://$GCS_BUCKET/video_inbox/...` or local `data/video_inbox/...`.
- All image/frame predictions are stored in `video_activity_predictions`; suspicious compatibility flags are stored in `video_activity_flags`.
- Grafana and Streamlit include Safety AI views for recent AI-flagged possible suspicious activity and normal review-frame traces.

The wording should stay reviewer-safe: the model produces possible activity labels for human review, not confirmed crime determinations.
