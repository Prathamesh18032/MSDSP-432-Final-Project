from __future__ import annotations

import json
import os
import importlib.util
import tempfile
import unittest
from pathlib import Path

from video_agent.agent import VideoAgent
from video_agent.config import Config
from video_agent.db import FlagWriter, flag_to_params
from video_agent.events import discover_local_videos, discover_local_media, infer_city_camera, infer_demo_metadata, parse_gcs_notification
from video_agent.inference import TwoStageImageCrimeModel
from video_agent.labels import display_label, is_suspicious, severity


def test_config(tmp: str) -> Config:
    return Config(
        timescale_dsn="postgres://example",
        input_dir=tmp,
        gcs_bucket="bucket",
        gcs_prefix="video_inbox/",
        pubsub_subscription="smartcity-video-agent",
        city="chicago",
        camera_id="demo-001",
        model_name="test-model",
        binary_model_name="binary-test-model",
        type_model_name="type-test-model",
        model_version="test",
        threshold=0.65,
        crime_threshold=0.50,
        mock_model=True,
        poll_seconds=1,
        clip_seconds=10,
        dry_run=True,
    )


class VideoAgentTests(unittest.TestCase):
    def test_infer_city_camera_from_partitioned_path(self) -> None:
        city, camera = infer_city_camera("video_inbox/city=chicago/camera=cam-7/robbery.mp4", "x", "y")
        self.assertEqual(city, "chicago")
        self.assertEqual(camera, "cam-7")

    def test_parse_gcs_notification(self) -> None:
        payload = json.dumps({"bucket": "demo-bucket", "name": "video_inbox/city=chicago/camera=cam-1/assault.mp4"})
        event = parse_gcs_notification(payload, "default-city", "default-camera")
        self.assertEqual(event.uri, "gs://demo-bucket/video_inbox/city=chicago/camera=cam-1/assault.mp4")
        self.assertEqual(event.city, "chicago")
        self.assertEqual(event.camera_id, "cam-1")

    def test_label_mapping(self) -> None:
        self.assertTrue(is_suspicious("Robbery"))
        self.assertEqual(display_label("Robbery"), "robbery_like_activity")
        self.assertEqual(severity("Robbery"), "critical")
        self.assertFalse(is_suspicious("Normal Videos"))
        self.assertFalse(is_suspicious("NormalVideos"))
        self.assertTrue(is_suspicious("RoadAccidents"))
        self.assertEqual(display_label("RoadAccidents"), "road_accident_like_activity")
        self.assertEqual(display_label("theft"), "stealing_like_activity")

    def test_local_discovery_and_mock_flag(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "city=chicago" / "camera=demo-001"
            path.mkdir(parents=True)
            video = path / "robbery-sample.mp4"
            video.write_bytes(b"fake")

            events = discover_local_videos(tmp, "default-city", "default-camera")
            self.assertEqual(len(events), 1)

            writer = FlagWriter("postgres://unused", dry_run=True)
            agent = VideoAgent(test_config(tmp), writer=writer)
            try:
                flags = agent.process_event(events[0])
            finally:
                agent.close()

            self.assertEqual(len(flags), 1)
            self.assertEqual(flags[0].display_label, "robbery_like_activity")
            self.assertEqual(flags[0].severity, "critical")
            self.assertEqual(len(writer.written), 1)
            self.assertEqual(len(writer.predictions_written), 1)
            self.assertTrue(writer.predictions_written[0].is_suspicious)
            self.assertEqual(writer.predictions_written[0].location_name, events[0].location_name)
            params = flag_to_params(flags[0])
            self.assertEqual(params["camera_id"], "demo-001")

    def test_mock_normal_video_below_threshold(self) -> None:
        with tempfile.TemporaryDirectory() as tmp:
            video = Path(tmp) / "normal-walk.mp4"
            video.write_bytes(b"fake")
            event = discover_local_videos(tmp, "chicago", "demo-001")[0]
            writer = FlagWriter("postgres://unused", dry_run=True)
            agent = VideoAgent(test_config(tmp), writer=writer)
            try:
                flags = agent.process_event(event)
            finally:
                agent.close()

            self.assertEqual(flags, [])
            self.assertEqual(writer.written, [])
            self.assertEqual(len(writer.predictions_written), 1)
            self.assertFalse(writer.predictions_written[0].is_suspicious)
            self.assertEqual(writer.predictions_written[0].display_label, "normal")


    def test_image_png_discovery_and_mock_flag(self) -> None:
        """PNG frames from UCF-Crime dataset should be discovered and flagged."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "city=chicago" / "camera=demo-assault"
            path.mkdir(parents=True)
            # Simulate a frame extracted from an Assault video
            img = path / "Assault001_frame0042.png"
            img.write_bytes(b"\x89PNG\r\n\x1a\n")  # minimal PNG header

            events = discover_local_media(tmp, "chicago", "demo-001")
            self.assertEqual(len(events), 1)
            self.assertEqual(events[0].camera_id, "demo-assault")

            writer = FlagWriter("postgres://unused", dry_run=True)
            agent = VideoAgent(test_config(tmp), writer=writer)
            try:
                flags = agent.process_event(events[0])
            finally:
                agent.close()

            self.assertEqual(len(flags), 1)
            self.assertEqual(flags[0].display_label, "assault_like_activity")
            self.assertEqual(flags[0].severity, "high")
            self.assertEqual(len(writer.predictions_written), 1)

    def test_image_mixed_with_video_discovery(self) -> None:
        """discover_local_media picks up both .mp4 and .png in the same inbox."""
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "city=chicago" / "camera=demo-001"
            path.mkdir(parents=True)
            (path / "robbery-clip.mp4").write_bytes(b"fake")
            (path / "fighting-frame.png").write_bytes(b"\x89PNG\r\n\x1a\n")
            (path / "readme.txt").write_bytes(b"ignored")

            events = discover_local_media(tmp, "chicago", "demo-001")
            self.assertEqual(len(events), 2)
            suffixes = {Path(e.local_path).suffix.lower() for e in events}
            self.assertIn(".mp4", suffixes)
            self.assertIn(".png", suffixes)

    def test_parse_gcs_notification_png(self) -> None:
        """GCS notifications for .png frames should parse correctly."""
        payload = json.dumps({
            "bucket": "demo-bucket",
            "name": "video_inbox/city=chicago/camera=demo-assault/Assault001_frame0042.png",
        })
        event = parse_gcs_notification(payload, "default-city", "default-camera")
        self.assertEqual(event.city, "chicago")
        self.assertEqual(event.camera_id, "demo-assault")
        self.assertTrue(event.uri.endswith(".png"))

    def test_demo_metadata_is_populated_from_path(self) -> None:
        event_time, location_name, latitude, longitude, source_video_uri, frame_index = infer_demo_metadata(
            "video_inbox/city=chicago/camera=demo-video/source_video=clip-01/frame000042.jpg"
        )
        self.assertIsNotNone(event_time.tzinfo)
        self.assertTrue(location_name)
        self.assertGreater(latitude, 41.0)
        self.assertLess(longitude, -87.0)
        self.assertEqual(source_video_uri, "clip-01")
        self.assertEqual(frame_index, 42)

    def test_two_stage_model_instantiates_without_loading_model(self) -> None:
        model = TwoStageImageCrimeModel("binary-model", "type-model", 0.5)
        self.assertEqual(model.binary_model_name, "binary-model")
        self.assertEqual(model.type_model_name, "type-model")
        self.assertEqual(model.crime_threshold, 0.5)

    def test_dataset_sampler_size_cap_with_local_fixture(self) -> None:
        script_path = Path(__file__).resolve().parents[3] / "scripts" / "video_dataset_seed.py"
        spec = importlib.util.spec_from_file_location("video_dataset_seed", script_path)
        self.assertIsNotNone(spec)
        module = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(module)

        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            source = root / "Test"
            assault = source / "Assault"
            # Use Kaggle folder name (no space) — normalize_class_name must map this to "normal"
            normal = source / "NormalVideos"
            assault.mkdir(parents=True)
            normal.mkdir(parents=True)
            (assault / "a1.jpg").write_bytes(b"a" * 10)
            (assault / "a2.jpg").write_bytes(b"a" * 10)
            (normal / "n1.jpg").write_bytes(b"n" * 10)
            output = root / "video_inbox"

            copied, total_bytes = module.copy_sampled_dataset(
                source_dir=source,
                output_dir=output,
                wanted_classes={"assault", "normal"},
                limit_bytes=25,
                max_normal=10,
                max_anomaly=10,
                city="chicago",
            )

            self.assertEqual(copied, 2)
            self.assertLessEqual(total_bytes, 25)
            self.assertTrue((output / "city=chicago" / "camera=demo-assault").exists())
            self.assertTrue((output / "city=chicago" / "camera=demo-normal").exists())

    def test_dataset_sampler_normalvideos_folder_name(self) -> None:
        """NormalVideos (Kaggle folder, no space) must normalize to 'normal' and be discovered."""
        script_path = Path(__file__).resolve().parents[3] / "scripts" / "video_dataset_seed.py"
        spec = importlib.util.spec_from_file_location("video_dataset_seed", script_path)
        module = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(module)

        # Both spellings must normalize to "normal"
        self.assertEqual(module.normalize_class_name("NormalVideos"), "normal")
        self.assertEqual(module.normalize_class_name("Normal Videos"), "normal")
        self.assertEqual(module.normalize_class_name("normal"), "normal")

        # class_from_path must match a path containing "NormalVideos"
        from pathlib import Path as _Path
        wanted = {"normal", "assault"}
        result = module.class_from_path(_Path("Test/NormalVideos/NormalVideos001/img001.jpg"), wanted)
        self.assertEqual(result, "normal")

    def test_frame_extraction_output_dir_is_discoverable(self) -> None:
        script_path = Path(__file__).resolve().parents[3] / "scripts" / "video_extract_frames.py"
        spec = importlib.util.spec_from_file_location("video_extract_frames", script_path)
        self.assertIsNotNone(spec)
        module = importlib.util.module_from_spec(spec)
        assert spec and spec.loader
        spec.loader.exec_module(module)
        target = module.output_dir(Path("data/video_inbox"), "chicago", "demo-video", Path("road clip.mp4"))
        self.assertEqual(str(target), "data/video_inbox/city=chicago/camera=demo-video/source_video=road_clip")


if __name__ == "__main__":
    unittest.main()
