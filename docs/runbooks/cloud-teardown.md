# Final GCP Teardown Runbook

Use this runbook after Phase 3 submission and demo completion to remove the Smart City cloud environment and stop future billing. The target project is `smartcity-zero-disk-iot-pa` in `asia-south1`.

This is intentionally destructive. The only data expected to remain after this runbook is local repo and submission material.

## Safety Rules

- Do not run teardown from a different project context. The scripts refuse to run unless the project is `smartcity-zero-disk-iot-pa`, unless `ALLOW_OTHER_PROJECT_TEARDOWN=yes` is set intentionally.
- Run inventory first and keep the generated evidence under ignored `artifacts/evidence/cloud-teardown/`.
- Empty cloud data before Terraform destroy because the Terraform bucket has `force_destroy = false` and the BigQuery dataset has `delete_contents_on_destroy = false`.
- After Terraform cleanup, shut down the project. Google Cloud project shutdown stops billing and resource usage, starts a 30-day recovery window, and permanently deletes the project after that period. If shutdown is initiated on June 9, 2026, the recovery window ends around July 9, 2026.

References:

- [Delete and restore projects](https://docs.cloud.google.com/resource-manager/docs/delete-restore-projects)
- [Enable, disable, or change billing for a project](https://docs.cloud.google.com/billing/docs/how-to/modify-project)
- [Close or reopen your Cloud Billing account](https://docs.cloud.google.com/billing/docs/how-to/close-or-reopen-billing-account)
- [Deleting a GKE cluster](https://docs.cloud.google.com/kubernetes-engine/docs/how-to/deleting-a-cluster)
- [Delete Cloud Storage objects](https://docs.cloud.google.com/storage/docs/deleting-objects)
- [gcloud billing projects unlink](https://docs.cloud.google.com/sdk/gcloud/reference/billing/projects/unlink)

## 1. Inventory

Confirm local tooling and capture the final state without deleting anything:

```sh
make gcp-bootstrap-check
make terraform-check
make cloud-teardown-inventory
```

Review the generated files under:

```text
artifacts/evidence/cloud-teardown/<timestamp>/
```

Expected Terraform-owned resources include Artifact Registry, Pub/Sub topics/subscriptions, GCS cold bucket, BigQuery dataset/table, service accounts, Workload Identity, and the GKE Autopilot runtime.

## 2. Freeze Runtime And Public Entry Points

Disable public ingress, delete demo static IPs, suspend CronJobs, scale runtime deployments and TimescaleDB to zero, and optionally remove GitHub Actions variables used for GCP promotion:

```sh
ALLOW_CLOUD_TEARDOWN_FREEZE=yes make cloud-teardown-freeze
```

To remove GitHub Actions promotion variables in the same run:

```sh
ALLOW_CLOUD_TEARDOWN_FREEZE=yes TEARDOWN_REMOVE_GITHUB_VARS=yes make cloud-teardown-freeze
```

If GitHub variable deletion is skipped, manually remove these repository variables:

```text
GCP_WORKLOAD_IDENTITY_PROVIDER
GCP_CI_SERVICE_ACCOUNT
```

After the project is deleted, keep the CD workflows decommissioned before pushing cleanup commits. `Publish Images` and `Promote Runtime` should not have automatic `push` or `workflow_run` triggers; keep them manual-only for archival reference so a push to `main` cannot publish images or promote to the deleted GKE runtime.

## 3. Empty Kubernetes And Durable Data

Delete Kubernetes app/public manifests, PVCs, the restore-test namespace, GCS objects, non-Terraform BigQuery tables, and Artifact Registry images:

```sh
ALLOW_CLOUD_TEARDOWN_EMPTY_DATA=yes make cloud-teardown-empty-data
```

This leaves Terraform-managed containers in place for Terraform destroy:

```text
gs://smartcity-zero-disk-iot-pa-cold
BigQuery dataset smartcity_iot and table sensor_readings_external
Artifact Registry repository smartcity
```

## 4. Review Terraform Destroy

Create and review a saved destroy plan:

```sh
make cloud-teardown-destroy-plan
terraform -chdir=infra/cloud/terraform show smartcity-destroy.tfplan
```

The plan should remove Terraform-managed GCP resources. If the plan fails because the bucket, dataset, or repository is not empty, rerun the empty-data phase and check for drift.

## 5. Destroy Terraform Resources

After reviewing the plan, destroy Terraform-managed cloud resources:

```sh
ALLOW_CLOUD_TEARDOWN_DESTROY=yes \
CLOUD_TEARDOWN_ACK=destroy-smartcity-zero-disk-iot-pa \
make cloud-teardown-destroy
```

By default this applies the saved `smartcity-destroy.tfplan` if present. Set `CLOUD_TEARDOWN_APPLY_SAVED_PLAN=no` to run a fresh `terraform destroy` with the same guards.

## 6. Verify Drift Is Gone

Run the verification sweep:

```sh
make cloud-teardown-verify
```

This checks Terraform state plus active GKE clusters, disks, snapshots, addresses, forwarding rules, Pub/Sub resources, buckets, BigQuery datasets, Artifact Registry repositories, smartcity service accounts, and Workload Identity pools.

If verification finds anything, delete the listed resource in Google Cloud Console or with `gcloud`, then rerun verification.

Pay special attention to resources that might have been created outside the current Terraform state:

```text
optional video Pub/Sub/GCS notification resources
static IPs
forwarding rules
orphan persistent disks
snapshots
service accounts
```

## 7. Stop Billing And Shut Down Project

When verification passes, unlink billing and shut down the project:

```sh
gcloud billing projects unlink smartcity-zero-disk-iot-pa
gcloud projects delete smartcity-zero-disk-iot-pa
```

Confirm the project is pending deletion:

```sh
gcloud projects describe smartcity-zero-disk-iot-pa --format='value(lifecycleState)'
```

Expected value:

```text
DELETE_REQUESTED
```

Finally, verify in the Cloud Billing console that `smartcity-zero-disk-iot-pa` is no longer linked to an active billing account. You remain responsible for charges already incurred before unlinking or deletion; Google Cloud can report some charges after a delay.

## Emergency Stop

If Terraform cleanup blocks and billing risk is urgent, stop billing first and then shut down the project:

```sh
gcloud billing projects unlink smartcity-zero-disk-iot-pa
gcloud projects delete smartcity-zero-disk-iot-pa
```

After the emergency stop, keep the local Terraform state and teardown evidence for records, but do not attempt more applies against the deleted project.
