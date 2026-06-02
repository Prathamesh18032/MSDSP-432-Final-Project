from __future__ import annotations

import json
import hashlib
from dataclasses import dataclass
from datetime import datetime, timedelta, timezone
from pathlib import Path
from urllib.parse import unquote


VIDEO_EXTENSIONS = {".mp4", ".mov", ".m4v", ".avi", ".mkv", ".webm"}
IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}
MEDIA_EXTENSIONS = VIDEO_EXTENSIONS | IMAGE_EXTENSIONS


@dataclass(frozen=True)
class VideoEvent:
    uri: str
    city: str
    camera_id: str
    local_path: str | None = None
    event_time: datetime | None = None
    location_name: str = "Chicago demo corridor"
    latitude: float = 41.8781
    longitude: float = -87.6298
    source_video_uri: str | None = None
    frame_index: int | None = None


DEMO_LOCATIONS = (
    ("Loop transit corridor", 41.8787, -87.6298),
    ("Near West Side arterial", 41.8819, -87.6501),
    ("River North intersection", 41.8925, -87.6341),
    ("South Loop camera zone", 41.8569, -87.6240),
    ("West Town commercial block", 41.8957, -87.6722),
)


def infer_city_camera(path_or_uri: str, default_city: str, default_camera: str) -> tuple[str, str]:
    city = default_city
    camera_id = default_camera
    parts = [part for part in path_or_uri.replace("\\", "/").split("/") if part]
    for part in parts:
        if part.startswith("city="):
            city = part.split("=", 1)[1] or city
        if part.startswith("camera="):
            camera_id = part.split("=", 1)[1] or camera_id
    return city, camera_id


def infer_demo_metadata(path_or_uri: str) -> tuple[datetime, str, float, float, str | None, int | None]:
    digest = hashlib.sha1(path_or_uri.encode("utf-8")).hexdigest()
    location_index = int(digest[:2], 16) % len(DEMO_LOCATIONS)
    minutes_ago = int(digest[2:6], 16) % (12 * 60)
    location_name, latitude, longitude = DEMO_LOCATIONS[location_index]
    event_time = datetime.now(timezone.utc) - timedelta(minutes=minutes_ago)

    source_video_uri = None
    frame_index = None
    name = Path(path_or_uri.replace("\\", "/")).name
    stem = Path(name).stem
    for token in stem.replace("-", "_").split("_"):
        if token.lower().startswith("frame"):
            suffix = token[5:]
            if suffix.isdigit():
                frame_index = int(suffix)
    if "source_video=" in path_or_uri:
        for part in path_or_uri.replace("\\", "/").split("/"):
            if part.startswith("source_video="):
                source_video_uri = part.split("=", 1)[1] or None
    return event_time, location_name, latitude, longitude, source_video_uri, frame_index


def discover_local_media(root: str, default_city: str, default_camera: str) -> list[VideoEvent]:
    """Discover local video and image files for inference.

    Images (PNG/JPG) are supported directly -- video-to-frame slicing is a
    future enhancement.  The VideoEvent dataclass is reused for both media
    types; the uri field carries a file:// URI in both cases.
    """
    base = Path(root)
    if not base.exists():
        return []
    events: list[VideoEvent] = []
    for path in sorted(base.rglob("*")):
        if not path.is_file() or path.suffix.lower() not in MEDIA_EXTENSIONS:
            continue
        city, camera_id = infer_city_camera(str(path), default_city, default_camera)
        event_time, location_name, latitude, longitude, source_video_uri, frame_index = infer_demo_metadata(str(path))
        events.append(
            VideoEvent(
                uri=path.resolve().as_uri(),
                city=city,
                camera_id=camera_id,
                local_path=str(path),
                event_time=event_time,
                location_name=location_name,
                latitude=latitude,
                longitude=longitude,
                source_video_uri=source_video_uri,
                frame_index=frame_index,
            )
        )
    return events


# backwards-compat alias so existing tests keep passing without changes
discover_local_videos = discover_local_media


def discover_gcs_media(bucket: str, prefix: str, default_city: str, default_camera: str) -> list[VideoEvent]:
    """List images under gs://<bucket>/<prefix> and return VideoEvents (no download).

    Requires google-cloud-storage to be installed and GCP credentials
    (GOOGLE_APPLICATION_CREDENTIALS or ADC).
    """
    try:
        from google.cloud import storage as gcs
    except ImportError as exc:
        raise RuntimeError("google-cloud-storage is required for GCS scan mode") from exc

    client = gcs.Client()
    blobs = client.list_blobs(bucket, prefix=prefix.rstrip("/") + "/")
    events: list[VideoEvent] = []
    for blob in blobs:
        name = blob.name
        if Path(name).suffix.lower() not in MEDIA_EXTENSIONS:
            continue
        city, camera_id = infer_city_camera(name, default_city, default_camera)
        event_time, location_name, latitude, longitude, source_video_uri, frame_index = infer_demo_metadata(name)
        events.append(
            VideoEvent(
                uri=f"gs://{bucket}/{name}",
                city=city,
                camera_id=camera_id,
                local_path=None,
                event_time=event_time,
                location_name=location_name,
                latitude=latitude,
                longitude=longitude,
                source_video_uri=source_video_uri,
                frame_index=frame_index,
            )
        )
    return events


def parse_gcs_notification(payload: bytes | str, default_city: str, default_camera: str) -> VideoEvent:
    if isinstance(payload, bytes):
        payload = payload.decode("utf-8")
    data = json.loads(payload)
    bucket = data.get("bucket")
    name = unquote(data.get("name", ""))
    if not bucket or not name:
        raise ValueError("GCS notification must include bucket and name")
    if Path(name).suffix.lower() not in MEDIA_EXTENSIONS:
        raise ValueError(f"not a supported media object: {name}")
    city, camera_id = infer_city_camera(name, default_city, default_camera)
    event_time, location_name, latitude, longitude, source_video_uri, frame_index = infer_demo_metadata(name)
    return VideoEvent(
        uri=f"gs://{bucket}/{name}",
        city=city,
        camera_id=camera_id,
        event_time=event_time,
        location_name=location_name,
        latitude=latitude,
        longitude=longitude,
        source_video_uri=source_video_uri,
        frame_index=frame_index,
    )
