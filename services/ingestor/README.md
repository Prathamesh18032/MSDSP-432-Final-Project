# Ingestor Service

Placeholder for the Go ingestion service.

Initial responsibilities:

- OpenAQ polling client.
- Go sensor simulator.
- `SensorReading` normalization.
- Validation, retries, backoff, and quality flags.
- Queue publisher abstraction for local mode and future GCP Pub/Sub mode.
