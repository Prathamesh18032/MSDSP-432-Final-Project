from __future__ import annotations

import logging
from pathlib import Path

from .config import Config
from .db import FlagWriter, VideoFlag, VideoPrediction, now_utc
from .events import VideoEvent
from .inference import IMAGE_EXTENSIONS, MockCrimeModel, TwoStageImageCrimeModel, VideoMAECrimeModel
from .labels import display_label, is_suspicious, severity
from .storage import VideoResolver


LOGGER = logging.getLogger("video-agent")


def _build_model(config: Config):
    if config.mock_model:
        return MockCrimeModel()
    # Real model — chosen at predict() time based on file extension
    return None  # resolved per-event below


class VideoAgent:
    def __init__(self, config: Config, writer: FlagWriter | None = None) -> None:
        self.config = config
        self.writer = writer or FlagWriter(config.timescale_dsn, dry_run=config.dry_run)
        self._mock = MockCrimeModel() if config.mock_model else None
        self._image_model: TwoStageImageCrimeModel | None = None
        self._video_model: VideoMAECrimeModel | None = None
        self.resolver = VideoResolver()

    def _get_model(self, media_path: str):
        if self._mock is not None:
            return self._mock
        if Path(media_path).suffix.lower() in IMAGE_EXTENSIONS:
            if self._image_model is None:
                self._image_model = TwoStageImageCrimeModel(
                    self.config.binary_model_name,
                    self.config.type_model_name,
                    self.config.crime_threshold,
                )
            return self._image_model
        # video file
        if self._video_model is None:
            self._video_model = VideoMAECrimeModel(self.config.model_name)
        return self._video_model

    def _effective_model_name(self, media_path: str) -> str:
        if self.config.mock_model:
            return "mock-video-crime-model"
        if Path(media_path).suffix.lower() in IMAGE_EXTENSIONS:
            return f"{self.config.binary_model_name}+{self.config.type_model_name}[image]"
        return self.config.model_name

    def close(self) -> None:
        self.resolver.close()

    def process_event(self, event: VideoEvent) -> list[VideoFlag]:
        local_path = self.resolver.resolve(event.uri, event.local_path)
        model = self._get_model(local_path)
        predictions = model.predict(local_path, self.config.clip_seconds)
        event_time = event.event_time or now_utc()
        model_name = self._effective_model_name(local_path)
        prediction_records = [
            VideoPrediction(
                event_time=event_time,
                city=event.city,
                camera_id=event.camera_id,
                location_name=event.location_name,
                latitude=event.latitude,
                longitude=event.longitude,
                media_uri=event.uri,
                source_video_uri=event.source_video_uri,
                frame_index=event.frame_index,
                is_suspicious=prediction.is_suspicious,
                predicted_label=prediction.label,
                display_label=display_label(prediction.label),
                crime_score=prediction.crime_score,
                type_score=prediction.type_score,
                confidence=prediction.confidence,
                severity=severity(prediction.label) if prediction.is_suspicious else "low",
                model_name=model_name,
                model_version=self.config.model_version,
            )
            for prediction in predictions
        ]
        self.writer.write_predictions(prediction_records)
        flags: list[VideoFlag] = []
        for prediction in predictions:
            if prediction.confidence < self.config.threshold or not prediction.is_suspicious or not is_suspicious(prediction.label):
                LOGGER.info(
                    "media ignored uri=%s label=%s confidence=%.3f threshold=%.3f",
                    event.uri,
                    prediction.label,
                    prediction.confidence,
                    self.config.threshold,
                )
                continue
            flag = VideoFlag(
                event_time=event_time,
                city=event.city,
                camera_id=event.camera_id,
                video_uri=event.uri,
                clip_start_seconds=prediction.clip_start_seconds,
                clip_end_seconds=prediction.clip_end_seconds,
                predicted_label=prediction.label,
                display_label=display_label(prediction.label),
                confidence=prediction.confidence,
                severity=severity(prediction.label),
                model_name=model_name,
                model_version=self.config.model_version,
            )
            flags.append(flag)
        self.writer.write_many(flags)
        for flag in flags:
            LOGGER.info(
                "media flagged uri=%s camera=%s label=%s confidence=%.3f severity=%s",
                flag.video_uri,
                flag.camera_id,
                flag.display_label,
                flag.confidence,
                flag.severity,
            )
        return flags
