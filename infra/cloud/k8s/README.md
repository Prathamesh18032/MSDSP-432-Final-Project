# GKE Manifest Scaffold

These manifests describe the future GKE Autopilot workload shape for the Smart City Zero-Disk IoT project.

They are not ready to apply as-is. Replace placeholder values such as `replace-me-project`, publish real container images, update image tags, and create `smartcity-runtime-secrets` out of band before deployment.

## Included

- Namespace and a small quota guardrail.
- Kubernetes service accounts annotated for GKE Workload Identity Federation.
- Shared runtime ConfigMap.
- Deployment placeholder for the multi-source ingestor.
- CronJob placeholder for cold Parquet export.
- Streamlit and Grafana deployment/service placeholders.

## Runtime Secrets

Do not commit secret values. Create `smartcity-runtime-secrets` through your chosen secret-management workflow with keys such as:

- `OPENAQ_API_KEY`
- `TIMESCALE_DSN`
- `GRAFANA_ADMIN_USER`
- `GRAFANA_ADMIN_PASSWORD`

## Validation

Run from the repository root:

```sh
make cloud-check
```

The app image references use the same default local naming convention as `make docker-build`, but images are not pushed to Artifact Registry until a later slice.
