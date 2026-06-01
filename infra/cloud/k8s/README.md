# GKE Runtime Manifests

These manifests describe the first cloud runtime for the Smart City Zero-Disk IoT project. They are templates under `base/` and must be rendered before apply so project, region, namespace, bucket, image registry, image tag, and Workload Identity values come from local config.

## Included

- Namespace and quota guardrail.
- Kubernetes service accounts annotated for GKE Workload Identity Federation.
- Shared runtime ConfigMap.
- Internal TimescaleDB StatefulSet, PVC, and ClusterIP service for the hot store.
- TimescaleDB schema init ConfigMap generated from `infra/local/timescaledb/init/001_schema.sql`.
- Multi-source ingestor publishing readings to Pub/Sub.
- Pub/Sub hot writer consuming readings into TimescaleDB.
- TimescaleDB backup CronJob writing `pg_dump` files to GCS.
- Cold export CronJob writing Parquet to GCS.
- Streamlit internal service reading TimescaleDB.
- Optional video AI agent deployment reading GCS image/frame object notifications, writing all rows to `video_activity_predictions`, and writing suspicious compatibility rows to `video_activity_flags`.
- Optional Streamlit-only public demo ingress templates.

Grafana remains local/demo-only for now and is not deployed in the cloud runtime.
Grafana can still show Safety AI panels locally when connected to the TimescaleDB schema.

## Render And Apply

Run from the repository root:

```sh
make k8s-render
K8S_TIMESCALE_PASSWORD=<strong-password> make k8s-apply
make k8s-status
make k8s-smoke
make k8s-backup-once
make k8s-backup-check
make k8s-restore-test
make k8s-restore-check
make k8s-restore-clean
make k8s-port-forward-streamlit
```

The video agent is rendered with `VIDEO_AGENT_REPLICAS=0` by default. For a Safety AI demo, publish the `smartcity-video-agent` image, set `VIDEO_AGENT_REPLICAS=1`, render/apply the manifests, and upload sampled images or extracted frames under `gs://$GCS_BUCKET/video_inbox/...`.

To expose Streamlit temporarily for reviewers:

```sh
export STREAMLIT_DEMO_PASSWORD=<share-with-reviewers>
ALLOW_PUBLIC_INGRESS=yes make public-demo-apply
make public-demo-url
```

Disable the public endpoint after review:

```sh
make public-demo-disable
```

Rendered files are written to `infra/cloud/k8s/rendered/` and are ignored by Git. Do not edit rendered files directly; update the templates or renderer instead.

## Runtime Secrets

Do not commit secret values. `make k8s-apply` creates `smartcity-runtime-secrets` when it is missing and `K8S_TIMESCALE_PASSWORD` is set. The secret contains:

- `TIMESCALE_PASSWORD`
- `TIMESCALE_DSN`
- optional `OPENAQ_API_KEY`
- optional `STREAMLIT_DEMO_PASSWORD`

The TimescaleDB service is internal only:

```text
smartcity-timescaledb.<namespace>.svc.cluster.local:5432
```

## Validation

```sh
make cloud-check
make runtime-check
make k8s-render
```

After a real cluster exists and credentials are configured, use:

```sh
make k8s-apply
make k8s-status
make k8s-smoke
```

Set `RUN_COLD_EXPORT_SMOKE=yes` with `make k8s-smoke` to trigger one cold-export Job from the CronJob as part of runtime validation.

Use `make k8s-restore-test` only for isolated restore validation. It creates a temporary namespace from `RESTORE_TEST_NAMESPACE` and refuses to run against the live runtime namespace.
