# Public Demo Runbook

This runbook exposes the Streamlit command center and, when needed for demo week, a separate login-protected Grafana endpoint. TimescaleDB, ingestor, writer, Pub/Sub, GCS, BigQuery, and Kubernetes internals remain private.

## Safety Rules

- Set `STREAMLIT_DEMO_PASSWORD` before enabling public access.
- Set `ALLOW_PUBLIC_INGRESS=yes` only for commands that create or update ingress.
- Use `PUBLIC_DEMO_DOMAIN` for HTTPS when a real domain points to the reserved IP.
- Without `PUBLIC_DEMO_DOMAIN`, the demo uses temporary HTTP on the load balancer IP.
- Run `make public-demo-disable` after the review window.
- The public page should show the branded password gate first, then the command center with city KPIs, source health, map/table views, and cold-path evidence.
- Public Grafana requires `GRAFANA_ADMIN_PASSWORD`; it must not be `admin`.
- Use `ALLOW_GRAFANA_PUBLIC_INGRESS=yes` only for commands that create or update Grafana ingress.
- Grafana uses a separate static IP from Streamlit by default.

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

## Enable Public Grafana

Preferred tracked path: run the GitHub Actions `Promote Runtime` workflow with `deploy_public_grafana=true`. Set repository secret `GRAFANA_ADMIN_PASSWORD` first; it must not be `admin`. Optional repository variables:

- `PUBLIC_GRAFANA_DOMAIN`
- `PUBLIC_GRAFANA_STATIC_IP_NAME`
- `AUTO_DEPLOY_PUBLIC_GRAFANA=true` to apply public Grafana during automatic `main` promotions.
- `AUTO_RUN_GRAFANA_SMOKE=true` to smoke-test public Grafana during automatic `main` promotions.

Local fallback:

```sh
export GRAFANA_ADMIN_PASSWORD=<share-with-reviewers>
ALLOW_GRAFANA_PUBLIC_INGRESS=yes make grafana-public-render
ALLOW_GRAFANA_PUBLIC_INGRESS=yes make grafana-public-apply
make grafana-public-status
make grafana-public-url
make grafana-public-smoke
```

The apply path expects the Grafana static IP to be reserved already. To create or repair that IP from a local admin machine, opt in explicitly:

```sh
GRAFANA_PUBLIC_MANAGE_STATIC_IP=yes ALLOW_GRAFANA_PUBLIC_INGRESS=yes make grafana-public-apply
```

If no domain is configured, share the `http://<grafana-load-balancer-ip>` URL only during the active demo window.

If a domain is configured:

```sh
export PUBLIC_GRAFANA_DOMAIN=grafana.example.com
```

Point the domain DNS record to the static IP from `make grafana-public-status`, then wait for the managed certificate to become active.

## Disable Public Grafana

```sh
make grafana-public-disable
```

The Grafana static IP is preserved by default. To delete it after a temporary demo:

```sh
PUBLIC_GRAFANA_DELETE_STATIC_IP=yes make grafana-public-disable
```

## Verify Private Surfaces

```sh
kubectl get svc -n smartcity
kubectl get ingress -n smartcity
```

Only `smartcity-streamlit-public` and, during Grafana demo windows, `smartcity-grafana-public` should be exposed by ingress. TimescaleDB must remain `ClusterIP`.
