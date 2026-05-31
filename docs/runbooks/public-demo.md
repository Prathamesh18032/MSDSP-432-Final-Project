# Public Demo Runbook

This runbook exposes only the Streamlit command center for short review windows. TimescaleDB, ingestor, writer, Pub/Sub, GCS, BigQuery, Grafana, and Kubernetes internals remain private.

## Safety Rules

- Set `STREAMLIT_DEMO_PASSWORD` before enabling public access.
- Set `ALLOW_PUBLIC_INGRESS=yes` only for commands that create or update ingress.
- Use `PUBLIC_DEMO_DOMAIN` for HTTPS when a real domain points to the reserved IP.
- Without `PUBLIC_DEMO_DOMAIN`, the demo uses temporary HTTP on the load balancer IP.
- Run `make public-demo-disable` after the review window.
- The public page should show the branded password gate first, then the command center with city KPIs, source health, map/table views, and cold-path evidence.

## Enable

```sh
export STREAMLIT_DEMO_PASSWORD=<share-with-reviewers>
ALLOW_PUBLIC_INGRESS=yes make public-demo-render
ALLOW_PUBLIC_INGRESS=yes make public-demo-apply
make public-demo-status
make public-demo-url
make public-demo-smoke
```

If no domain is configured, share the `http://<load-balancer-ip>` URL only during the active demo window.

If a domain is configured:

```sh
export PUBLIC_DEMO_DOMAIN=demo.example.com
```

Point the domain DNS record to the static IP from `make public-demo-status`, then wait for the managed certificate to become active.

## Disable

```sh
make public-demo-disable
```

The static IP is preserved by default so DNS does not churn. To delete it after a temporary demo:

```sh
PUBLIC_DEMO_DELETE_STATIC_IP=yes make public-demo-disable
```

## Verify Private Surfaces

```sh
kubectl get svc -n smartcity
kubectl get ingress -n smartcity
```

Only `smartcity-streamlit-public` should be exposed by ingress. TimescaleDB must remain `ClusterIP`; Grafana is not deployed in cloud.
