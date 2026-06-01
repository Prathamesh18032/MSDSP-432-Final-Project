#!/usr/bin/env python3
from __future__ import annotations

import argparse
import os
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Extract demo frames for Safety AI image inference")
    parser.add_argument("video", help="local video path")
    parser.add_argument("--output", default=os.getenv("VIDEO_AGENT_DATASET_DIR", "data/video_inbox"))
    parser.add_argument("--city", default=os.getenv("VIDEO_AGENT_CITY", "chicago"))
    parser.add_argument("--camera-id", default=os.getenv("VIDEO_AGENT_CAMERA_ID", "demo-video"))
    parser.add_argument("--every-seconds", type=float, default=float(os.getenv("VIDEO_AGENT_FRAME_EVERY_SECONDS", "2")))
    parser.add_argument("--max-frames", type=int, default=int(os.getenv("VIDEO_AGENT_FRAME_MAX_FRAMES", "60")))
    return parser.parse_args()


def output_dir(base: Path, city: str, camera_id: str, video_path: Path) -> Path:
    safe_stem = "".join(ch if ch.isalnum() or ch in {"-", "_"} else "_" for ch in video_path.stem)[:80]
    return base / f"city={city}" / f"camera={camera_id}" / f"source_video={safe_stem}"


def extract_frames(video_path: Path, target_dir: Path, every_seconds: float, max_frames: int) -> int:
    try:
        import cv2
    except Exception as exc:
        raise SystemExit("opencv-python-headless is required for frame extraction.") from exc

    capture = cv2.VideoCapture(str(video_path))
    if not capture.isOpened():
        raise SystemExit(f"Could not open video: {video_path}")

    fps = capture.get(cv2.CAP_PROP_FPS) or 30.0
    step = max(1, int(round(fps * every_seconds)))
    target_dir.mkdir(parents=True, exist_ok=True)

    frame_index = 0
    written = 0
    while written < max_frames:
        ok, frame = capture.read()
        if not ok:
            break
        if frame_index % step == 0:
            target = target_dir / f"frame{frame_index:06d}.jpg"
            cv2.imwrite(str(target), frame)
            written += 1
        frame_index += 1
    capture.release()
    return written


def main() -> int:
    args = parse_args()
    video_path = Path(args.video)
    if not video_path.exists():
        print(f"Video not found: {video_path}")
        return 1
    target_dir = output_dir(Path(args.output), args.city, args.camera_id, video_path)
    written = extract_frames(video_path, target_dir, args.every_seconds, args.max_frames)
    print(f"Extracted {written} frames under {target_dir}")
    return 0 if written else 1


if __name__ == "__main__":
    raise SystemExit(main())
