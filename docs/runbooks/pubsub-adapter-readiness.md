# Pub/Sub Adapter Readiness Runbook

Slice 14 adds Pub/Sub-compatible producer and consumer code, but it does not create Pub/Sub resources, run Terraform apply, or deploy workloads.

References:

- Pub/Sub Go client: <https://pkg.go.dev/cloud.google.com/go/pubsub>
- Publisher and subscriber flow: <https://cloud.google.com/pubsub/docs/publish-receive-messages-client-library>
- Dead-letter topics: <https://cloud.google.com/pubsub/docs/dead-letter-topics>
- Message ordering: <https://cloud.google.com/pubsub/docs/ordering>

## Local Default

The default ingestion path remains local:

```sh
INGESTION_SINK=local
make run-local
make poll-multisource-once
```

This path writes through the bounded Go queue into local TimescaleDB.

## Pub/Sub Readiness Check

Use this only after a later slice has created the topic and subscription:

```sh
make gcp-bootstrap-check
make pubsub-check
```

`make pubsub-check` describes the configured topic and subscription. It exits with a clear message if they do not exist yet.

Expected names:

```sh
GCP_PROJECT_ID=smartcity-zero-disk-iot-pa
GCP_PUBSUB_TOPIC=smartcity-readings
GCP_PUBSUB_SUBSCRIPTION=smartcity-hot-writer
```

## Publish Smoke

When the topic exists, publish one live multi-source poll:

```sh
INGESTION_SINK=pubsub make pubsub-smoke
```

OpenAQ remains optional in `poll-multisource`; Open-Meteo, Divvy GBFS, and USGS can still run without an OpenAQ key.

## Consume Smoke

Start local TimescaleDB, then consume the subscription:

```sh
make run-local
make consume-pubsub
```

The consumer validates each decoded `SensorReading`, inserts it into TimescaleDB, and acknowledges the message only after the insert succeeds. Failed validation or storage errors are nacked for retry/dead-letter handling by the configured Pub/Sub subscription policy.

## Message Contract

Message data is the existing `SensorReading` JSON contract. Message attributes include:

- `schema_version`
- `source`
- `metric`
- `sensor_id`
- `dedup_key`

Pub/Sub is treated as at-least-once delivery. TimescaleDB already upserts on `(time, sensor_id, metric)`, so duplicate deliveries do not create duplicate hot rows.
