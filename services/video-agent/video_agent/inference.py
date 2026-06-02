from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from .labels import normalize_label

IMAGE_EXTENSIONS = {".png", ".jpg", ".jpeg", ".webp"}


@dataclass(frozen=True)
class Prediction:
    label: str
    confidence: float
    clip_start_seconds: float
    clip_end_seconds: float
    is_suspicious: bool
    crime_score: float
    type_score: float | None = None


class MockCrimeModel:
    """Deterministic model used for CI, demos, and local smoke checks.

    Classifies by filename keyword — works for both video and image files.
    """

    def predict(self, media_path: str, clip_seconds: int) -> list[Prediction]:
        name = Path(media_path).name.lower()
        label = "normal"
        confidence = 0.92
        is_suspicious = False
        for candidate in (
            "robbery",
            "assault",
            "fighting",
            "burglary",
            "shooting",
            "shoplifting",
            "stealing",
            "theft",
            "vandalism",
            "roadaccidents",
            "road accident",
            "accident",
            "crash",
        ):
            if candidate in name:
                label = "road accident" if candidate in {"roadaccidents", "road accident", "accident", "crash"} else candidate
                label = "stealing" if candidate in {"theft"} else label
                confidence = 0.91
                is_suspicious = True
                break
        crime_score = confidence if is_suspicious else 1.0 - confidence
        return [
            Prediction(
                label=label,
                confidence=confidence,
                clip_start_seconds=0,
                clip_end_seconds=float(clip_seconds),
                is_suspicious=is_suspicious,
                crime_score=crime_score,
                type_score=confidence if is_suspicious else None,
            )
        ]


class TwoStageImageCrimeModel:
    """HuggingFace frame classifier: Crime/Normal first, activity type second."""

    def __init__(self, binary_model_name: str, type_model_name: str, crime_threshold: float) -> None:
        self.binary_model_name = binary_model_name
        self.type_model_name = type_model_name
        self.crime_threshold = crime_threshold
        self._binary_pipeline = None
        self._type_pipeline = None

    def _load_binary_pipeline(self):
        if self._binary_pipeline is None:
            from transformers import pipeline

            self._binary_pipeline = pipeline("image-classification", model=self.binary_model_name)
        return self._binary_pipeline

    def _load_type_pipeline(self):
        if self._type_pipeline is None:
            from transformers import pipeline

            self._type_pipeline = pipeline("image-classification", model=self.type_model_name)
        return self._type_pipeline

    @staticmethod
    def _score_for(results: list[dict], wanted: set[str]) -> float | None:
        scores = [
            float(item.get("score", 0))
            for item in results
            if normalize_label(str(item.get("label", ""))).replace("-", " ") in wanted
        ]
        return max(scores) if scores else None

    @staticmethod
    def _best_label(results: list[dict], fallback: str) -> tuple[str, float]:
        if not results:
            return fallback, 0.0
        best = max(results, key=lambda item: float(item.get("score", 0)))
        return normalize_label(str(best.get("label", fallback))), float(best.get("score", 0))

    def predict(self, media_path: str, clip_seconds: int) -> list[Prediction]:
        suffix = Path(media_path).suffix.lower()
        if suffix not in IMAGE_EXTENSIONS:
            raise ValueError(
                f"TwoStageImageCrimeModel received a non-image file: {media_path}. "
                "Use VideoMAECrimeModel for video files."
            )
        binary_results = self._load_binary_pipeline()(media_path)
        if not binary_results:
            return []

        normal_score = self._score_for(binary_results, {"normal", "normal videos"})
        crime_score = self._score_for(binary_results, {"crime", "abnormal", "suspicious"})
        if crime_score is None:
            best_binary_label, best_binary_score = self._best_label(binary_results, "normal")
            is_normal = "normal" in best_binary_label
            crime_score = (1.0 - best_binary_score) if is_normal else best_binary_score
            normal_score = best_binary_score if is_normal else normal_score

        is_suspicious = crime_score >= self.crime_threshold
        if not is_suspicious:
            confidence = normal_score if normal_score is not None else max(0.0, 1.0 - crime_score)
            return [
                Prediction(
                    label="normal",
                    confidence=confidence,
                    clip_start_seconds=0,
                    clip_end_seconds=float(clip_seconds),
                    is_suspicious=False,
                    crime_score=crime_score,
                    type_score=None,
                )
            ]

        type_results = self._load_type_pipeline()(media_path)
        type_label, type_score = self._best_label(type_results, "suspicious activity")
        return [
            Prediction(
                label=type_label,
                confidence=crime_score,
                clip_start_seconds=0,
                clip_end_seconds=float(clip_seconds),
                is_suspicious=True,
                crime_score=crime_score,
                type_score=type_score,
            )
        ]


# Backwards-compatible import name for older callers/tests.
ImageClassifierModel = TwoStageImageCrimeModel


class VideoMAECrimeModel:
    """Full video classification via VideoMAE -- for .mp4/.avi etc.

    NOTE: not used when running on image frames.  Kept for when video
    ingestion (frame extraction from clips) is implemented.
    """

    def __init__(self, model_name: str) -> None:
        self.model_name = model_name
        self._pipeline = None

    def _load_pipeline(self):
        if self._pipeline is None:
            from transformers import pipeline
            self._pipeline = pipeline("video-classification", model=self.model_name)
        return self._pipeline

    def predict(self, video_path: str, clip_seconds: int) -> list[Prediction]:
        classifier = self._load_pipeline()
        results = classifier(video_path)
        if not results:
            return []
        best = max(results, key=lambda item: float(item.get("score", 0)))
        return [
            Prediction(
                label=normalize_label(str(best.get("label", "unknown"))),
                confidence=float(best.get("score", 0)),
                clip_start_seconds=0,
                clip_end_seconds=float(clip_seconds),
                is_suspicious=True,
                crime_score=float(best.get("score", 0)),
                type_score=float(best.get("score", 0)),
            )
        ]
