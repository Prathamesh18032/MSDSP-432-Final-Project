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
- Public demo ingress exposes only Streamlit and requires `STREAMLIT_DEMO_PASSWORD`.
- Backend services remain private inside the runtime network.
- GCP apply and public ingress flows are guarded by explicit environment flags.
- Runtime cost controls support demo, idle, resume, and scale-down modes.
- Backup and restore workflows validate recoverability without deleting hot TimescaleDB data.
- No service-account keys are committed; cloud flows use local credentials or GitHub OIDC.

## Future Scope: AI Agents In Smart City IoT

AI Agent features are future scope unless a later teammate implementation is merged before final submission. The Phase 3 narrative may mention them as the next layer above the implemented data platform:

- Incident triage agents that summarize abnormal city readings and recommend operator actions.
- Anomaly explanation agents that connect air, weather, mobility, and water signals.
- Operator copilots that answer questions over recent TimescaleDB readings and cold BigQuery history.
- Policy-aware alert routing that respects safety, privacy, and data-access boundaries.

If AI Agent code lands later, pull latest `main`, update this guide and the deck, rerun `make phase3-check`, rebuild the zip, and submit the refreshed package.
