from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone


@dataclass(frozen=True)
class VideoFlag:
    event_time: datetime
    city: str
    camera_id: str
    video_uri: str
    clip_start_seconds: float
    clip_end_seconds: float
    predicted_label: str
    display_label: str
    confidence: float
    severity: str
    model_name: str
    model_version: str
    review_status: str = "pending"


@dataclass(frozen=True)
class VideoPrediction:
    event_time: datetime
    city: str
    camera_id: str
    location_name: str
    latitude: float
    longitude: float
    media_uri: str
    source_video_uri: str | None
    frame_index: int | None
    is_suspicious: bool
    predicted_label: str
    display_label: str
    crime_score: float
    type_score: float | None
    confidence: float
    severity: str
    model_name: str
    model_version: str
    review_status: str = "pending"


PREDICTION_INSERT_SQL = """
INSERT INTO video_activity_predictions (
    event_time,
    city,
    camera_id,
    location_name,
    latitude,
    longitude,
    media_uri,
    source_video_uri,
    frame_index,
    is_suspicious,
    predicted_label,
    display_label,
    crime_score,
    type_score,
    confidence,
    severity,
    model_name,
    model_version,
    review_status
) VALUES (
    %(event_time)s,
    %(city)s,
    %(camera_id)s,
    %(location_name)s,
    %(latitude)s,
    %(longitude)s,
    %(media_uri)s,
    %(source_video_uri)s,
    %(frame_index)s,
    %(is_suspicious)s,
    %(predicted_label)s,
    %(display_label)s,
    %(crime_score)s,
    %(type_score)s,
    %(confidence)s,
    %(severity)s,
    %(model_name)s,
    %(model_version)s,
    %(review_status)s
)
ON CONFLICT DO NOTHING;
"""


INSERT_SQL = """
INSERT INTO video_activity_flags (
    event_time,
    city,
    camera_id,
    video_uri,
    clip_start_seconds,
    clip_end_seconds,
    predicted_label,
    display_label,
    confidence,
    severity,
    model_name,
    model_version,
    review_status
) VALUES (
    %(event_time)s,
    %(city)s,
    %(camera_id)s,
    %(video_uri)s,
    %(clip_start_seconds)s,
    %(clip_end_seconds)s,
    %(predicted_label)s,
    %(display_label)s,
    %(confidence)s,
    %(severity)s,
    %(model_name)s,
    %(model_version)s,
    %(review_status)s
)
ON CONFLICT (video_uri, clip_start_seconds, predicted_label) DO UPDATE SET
    event_time = EXCLUDED.event_time,
    clip_end_seconds = EXCLUDED.clip_end_seconds,
    display_label = EXCLUDED.display_label,
    confidence = EXCLUDED.confidence,
    severity = EXCLUDED.severity,
    model_name = EXCLUDED.model_name,
    model_version = EXCLUDED.model_version,
    created_at = NOW();
"""

SCHEMA_SQL = """
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
"""


def now_utc() -> datetime:
    return datetime.now(timezone.utc)


def flag_to_params(flag: VideoFlag) -> dict[str, object]:
    return {
        "event_time": flag.event_time,
        "city": flag.city,
        "camera_id": flag.camera_id,
        "video_uri": flag.video_uri,
        "clip_start_seconds": flag.clip_start_seconds,
        "clip_end_seconds": flag.clip_end_seconds,
        "predicted_label": flag.predicted_label,
        "display_label": flag.display_label,
        "confidence": flag.confidence,
        "severity": flag.severity,
        "model_name": flag.model_name,
        "model_version": flag.model_version,
        "review_status": flag.review_status,
    }


def prediction_to_params(prediction: VideoPrediction) -> dict[str, object]:
    return {
        "event_time": prediction.event_time,
        "city": prediction.city,
        "camera_id": prediction.camera_id,
        "location_name": prediction.location_name,
        "latitude": prediction.latitude,
        "longitude": prediction.longitude,
        "media_uri": prediction.media_uri,
        "source_video_uri": prediction.source_video_uri,
        "frame_index": prediction.frame_index,
        "is_suspicious": prediction.is_suspicious,
        "predicted_label": prediction.predicted_label,
        "display_label": prediction.display_label,
        "crime_score": prediction.crime_score,
        "type_score": prediction.type_score,
        "confidence": prediction.confidence,
        "severity": prediction.severity,
        "model_name": prediction.model_name,
        "model_version": prediction.model_version,
        "review_status": prediction.review_status,
    }


class FlagWriter:
    def __init__(self, dsn: str, dry_run: bool = False) -> None:
        self.dsn = dsn
        self.dry_run = dry_run
        self.written: list[VideoFlag] = []
        self.predictions_written: list[VideoPrediction] = []

    def write_predictions(self, predictions: list[VideoPrediction]) -> int:
        if not predictions:
            return 0
        if self.dry_run:
            self.predictions_written.extend(predictions)
            return len(predictions)

        import psycopg

        with psycopg.connect(self.dsn) as conn:
            with conn.cursor() as cur:
                cur.execute(SCHEMA_SQL)
                for prediction in predictions:
                    cur.execute(PREDICTION_INSERT_SQL, prediction_to_params(prediction))
            conn.commit()
        return len(predictions)

    def write_many(self, flags: list[VideoFlag]) -> int:
        if not flags:
            return 0
        if self.dry_run:
            self.written.extend(flags)
            return len(flags)

        import psycopg

        with psycopg.connect(self.dsn) as conn:
            with conn.cursor() as cur:
                cur.execute(SCHEMA_SQL)
                for flag in flags:
                    cur.execute(INSERT_SQL, flag_to_params(flag))
            conn.commit()
        return len(flags)
