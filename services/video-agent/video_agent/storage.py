from __future__ import annotations

from pathlib import Path
from tempfile import TemporaryDirectory


class VideoResolver:
    def __init__(self) -> None:
        self._tempdir: TemporaryDirectory[str] | None = None

    def close(self) -> None:
        if self._tempdir is not None:
            self._tempdir.cleanup()
            self._tempdir = None

    def resolve(self, uri: str, local_path: str | None = None) -> str:
        if local_path:
            return local_path
        if uri.startswith("file://"):
            return uri.removeprefix("file://")
        if not uri.startswith("gs://"):
            return uri
        return self._download_gcs(uri)

    def _download_gcs(self, uri: str) -> str:
        from google.cloud import storage

        without_scheme = uri.removeprefix("gs://")
        bucket_name, object_name = without_scheme.split("/", 1)
        if self._tempdir is None:
            self._tempdir = TemporaryDirectory(prefix="smartcity-video-agent-")
        target = Path(self._tempdir.name) / Path(object_name).name
        client = storage.Client()
        bucket = client.bucket(bucket_name)
        bucket.blob(object_name).download_to_filename(target)
        return str(target)

