CREATE EXTENSION IF NOT EXISTS timescaledb;

CREATE TABLE IF NOT EXISTS sensor_readings (
    time TIMESTAMPTZ NOT NULL,
    sensor_id VARCHAR(64) NOT NULL,
    metric VARCHAR(32) NOT NULL,
    value DOUBLE PRECISION NOT NULL,
    unit VARCHAR(16) NOT NULL,
    source VARCHAR(32) NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    quality_flag SMALLINT NOT NULL DEFAULT 1,
    ingested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    schema_version INTEGER NOT NULL DEFAULT 1,
    PRIMARY KEY (time, sensor_id, metric),
    CONSTRAINT sensor_readings_quality_flag_check CHECK (quality_flag IN (-1, 0, 1)),
    CONSTRAINT sensor_readings_latitude_check CHECK (latitude BETWEEN -90 AND 90),
    CONSTRAINT sensor_readings_longitude_check CHECK (longitude BETWEEN -180 AND 180)
);

SELECT create_hypertable('sensor_readings', 'time', if_not_exists => TRUE);

CREATE INDEX IF NOT EXISTS sensor_readings_sensor_metric_time_idx
    ON sensor_readings (sensor_id, metric, time DESC);

CREATE INDEX IF NOT EXISTS sensor_readings_metric_time_idx
    ON sensor_readings (metric, time DESC);

CREATE TABLE IF NOT EXISTS ingestion_metrics (
    recorded_at TIMESTAMPTZ NOT NULL PRIMARY KEY,
    readings_per_second DOUBLE PRECISION NOT NULL,
    channel_fill_pct SMALLINT NOT NULL,
    pubsub_lag_ms INTEGER,
    gcs_write_latency_ms INTEGER,
    dropped_readings_total BIGINT NOT NULL DEFAULT 0,
    CONSTRAINT ingestion_metrics_channel_fill_check CHECK (channel_fill_pct BETWEEN 0 AND 100)
);

CREATE MATERIALIZED VIEW IF NOT EXISTS hourly_aggregates
WITH (timescaledb.continuous) AS
SELECT
    time_bucket('1 hour', time) AS bucket,
    sensor_id,
    metric,
    AVG(value) AS avg_value,
    MIN(value) AS min_value,
    MAX(value) AS max_value,
    COUNT(*)::INTEGER AS reading_count
FROM sensor_readings
WHERE quality_flag = 1
GROUP BY bucket, sensor_id, metric
WITH NO DATA;
