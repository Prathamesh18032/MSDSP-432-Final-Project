from __future__ import annotations

import os
from dataclasses import dataclass


DEFAULT_MODEL = "OPear/videomae-large-finetuned-UCF-Crime"
DEFAULT_BINARY_MODEL = "dima806/crime_cctv_image_detection"
DEFAULT_TYPE_MODEL = "dima806/crime_type_cctv_image_detection"


def _bool_env(name: str, default: bool = False) -> bool:
    value = os.getenv(name)
    if value is None:
        return default
    return value.strip().lower() in {"1", "true", "yes", "on"}


@dataclass(frozen=True)
class Config:
    timescale_dsn: str
    input_dir: str
    gcs_bucket: str
    gcs_prefix: str
    pubsub_subscription: str
    city: str
    camera_id: str
    model_name: str
    binary_model_name: str
    type_model_name: str
    model_version: str
    threshold: float
    crime_threshold: float
    mock_model: bool
    poll_seconds: int
    clip_seconds: int
    dry_run: bool


def load_config() -> Config:
    return Config(
        timescale_dsn=os.getenv(
            "VIDEO_AGENT_TIMESCALE_DSN",
            os.getenv("TIMESCALE_DSN", "postgres://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot?sslmode=disable"),
        ),
        input_dir=os.getenv("VIDEO_AGENT_INPUT_DIR", "data/video_inbox"),
        gcs_bucket=os.getenv("VIDEO_AGENT_GCS_BUCKET", os.getenv("GCS_BUCKET", "")),
        gcs_prefix=os.getenv("VIDEO_AGENT_GCS_PREFIX", "video_inbox/"),
        pubsub_subscription=os.getenv("VIDEO_AGENT_PUBSUB_SUBSCRIPTION", "smartcity-video-agent"),
        city=os.getenv("VIDEO_AGENT_CITY", "chicago"),
        camera_id=os.getenv("VIDEO_AGENT_CAMERA_ID", "demo-001"),
        model_name=os.getenv("VIDEO_AGENT_MODEL", DEFAULT_MODEL),
        binary_model_name=os.getenv("VIDEO_AGENT_BINARY_MODEL", DEFAULT_BINARY_MODEL),
        type_model_name=os.getenv("VIDEO_AGENT_TYPE_MODEL", DEFAULT_TYPE_MODEL),
        model_version=os.getenv("VIDEO_AGENT_MODEL_VERSION", "mvp"),
        threshold=float(os.getenv("VIDEO_AGENT_THRESHOLD", "0.65")),
        crime_threshold=float(os.getenv("VIDEO_AGENT_CRIME_THRESHOLD", "0.50")),
        mock_model=_bool_env("VIDEO_AGENT_MOCK_MODEL", False),
        poll_seconds=int(os.getenv("VIDEO_AGENT_POLL_SECONDS", "10800")),
        clip_seconds=int(os.getenv("VIDEO_AGENT_CLIP_SECONDS", "10")),
        dry_run=_bool_env("VIDEO_AGENT_DRY_RUN", False),
    )
