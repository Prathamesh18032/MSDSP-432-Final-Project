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

CREATE TABLE IF NOT EXISTS video_activity_predictions (
    id BIGSERIAL PRIMARY KEY,
    event_time TIMESTAMPTZ NOT NULL,
    city VARCHAR(64) NOT NULL,
    camera_id VARCHAR(128) NOT NULL,
    location_name TEXT NOT NULL,
    latitude DECIMAL(9,6) NOT NULL,
    longitude DECIMAL(9,6) NOT NULL,
    media_uri TEXT NOT NULL,
    source_video_uri TEXT,
    frame_index INTEGER,
    is_suspicious BOOLEAN NOT NULL,
    predicted_label VARCHAR(64) NOT NULL,
    display_label VARCHAR(96) NOT NULL,
    crime_score DOUBLE PRECISION NOT NULL,
    type_score DOUBLE PRECISION,
    confidence DOUBLE PRECISION NOT NULL,
    severity VARCHAR(16) NOT NULL,
    model_name TEXT NOT NULL,
    model_version VARCHAR(64) NOT NULL DEFAULT 'mvp',
    review_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT video_activity_predictions_crime_score_check CHECK (crime_score BETWEEN 0 AND 1),
    CONSTRAINT video_activity_predictions_type_score_check CHECK (type_score IS NULL OR type_score BETWEEN 0 AND 1),
    CONSTRAINT video_activity_predictions_confidence_check CHECK (confidence BETWEEN 0 AND 1),
    CONSTRAINT video_activity_predictions_severity_check CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT video_activity_predictions_review_status_check CHECK (review_status IN ('pending', 'reviewed', 'dismissed'))
);

CREATE UNIQUE INDEX IF NOT EXISTS video_activity_predictions_dedup_idx
    ON video_activity_predictions (media_uri, COALESCE(frame_index, -1), predicted_label);

CREATE INDEX IF NOT EXISTS video_activity_predictions_time_idx
    ON video_activity_predictions (event_time DESC);

CREATE INDEX IF NOT EXISTS video_activity_predictions_camera_time_idx
    ON video_activity_predictions (camera_id, event_time DESC);

CREATE INDEX IF NOT EXISTS video_activity_predictions_label_time_idx
    ON video_activity_predictions (display_label, event_time DESC);

CREATE INDEX IF NOT EXISTS video_activity_predictions_suspicious_time_idx
    ON video_activity_predictions (is_suspicious, event_time DESC);

CREATE TABLE IF NOT EXISTS video_activity_flags (
    id BIGSERIAL PRIMARY KEY,
    event_time TIMESTAMPTZ NOT NULL,
    city VARCHAR(64) NOT NULL,
    camera_id VARCHAR(128) NOT NULL,
    video_uri TEXT NOT NULL,
    clip_start_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
    clip_end_seconds DOUBLE PRECISION NOT NULL DEFAULT 0,
    predicted_label VARCHAR(64) NOT NULL,
    display_label VARCHAR(96) NOT NULL,
    confidence DOUBLE PRECISION NOT NULL,
    severity VARCHAR(16) NOT NULL,
    model_name TEXT NOT NULL,
    model_version VARCHAR(64) NOT NULL DEFAULT 'mvp',
    review_status VARCHAR(32) NOT NULL DEFAULT 'pending',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT video_activity_flags_confidence_check CHECK (confidence BETWEEN 0 AND 1),
    CONSTRAINT video_activity_flags_severity_check CHECK (severity IN ('low', 'medium', 'high', 'critical')),
    CONSTRAINT video_activity_flags_review_status_check CHECK (review_status IN ('pending', 'reviewed', 'dismissed'))
);

CREATE UNIQUE INDEX IF NOT EXISTS video_activity_flags_dedup_idx
    ON video_activity_flags (video_uri, clip_start_seconds, predicted_label);

CREATE INDEX IF NOT EXISTS video_activity_flags_time_idx
    ON video_activity_flags (event_time DESC);

CREATE INDEX IF NOT EXISTS video_activity_flags_camera_time_idx
    ON video_activity_flags (camera_id, event_time DESC);

CREATE INDEX IF NOT EXISTS video_activity_flags_label_time_idx
    ON video_activity_flags (display_label, event_time DESC);

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
