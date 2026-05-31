from __future__ import annotations

import os
from dataclasses import dataclass
from pathlib import Path

import pandas as pd
import pyarrow.parquet as pq


DEFAULT_COLD_ROOT = "data/cold"


@dataclass(frozen=True)
class ColdStorageSummary:
    files: pd.DataFrame
    partitions: pd.DataFrame
    total_files: int
    total_rows: int
    latest_export_path: str


@dataclass(frozen=True)
class CloudColdSummary:
    configured: bool
    status: str
    bucket: str
    dataset: str
    table: str
    object_count: int
    latest_object: str
    row_count: int | None
    latest_reading_at: str
    message: str


def cold_root() -> Path:
    return Path(os.getenv("STREAMLIT_COLD_STORAGE_ROOT", DEFAULT_COLD_ROOT))


def summarize_cold_storage(root: Path | None = None) -> ColdStorageSummary:
    base = root or cold_root()
    paths = sorted(base.glob("sensor_readings/**/*.parquet"))
    rows: list[dict[str, object]] = []

    for path in paths:
        metadata = pq.ParquetFile(path).metadata
        partition = parse_partition(path)
        rows.append(
            {
                "path": str(path),
                "rows": metadata.num_rows,
                "source": partition.get("source", "unknown"),
                "metric": partition.get("metric", "unknown"),
                "year": partition.get("year", "unknown"),
                "month": partition.get("month", "unknown"),
                "day": partition.get("day", "unknown"),
                "modified_at": path.stat().st_mtime,
            }
        )

    files = pd.DataFrame(rows)
    if files.empty:
        return ColdStorageSummary(
            files=files,
            partitions=pd.DataFrame(),
            total_files=0,
            total_rows=0,
            latest_export_path="",
        )

    files["partition_date"] = files["year"].astype(str) + "-" + files["month"].astype(str) + "-" + files["day"].astype(str)
    partitions = (
        files.groupby(["source", "metric", "partition_date"], as_index=False)
        .agg(files=("path", "count"), rows=("rows", "sum"))
        .sort_values(["source", "metric", "partition_date"])
    )
    latest_export_path = files.sort_values("modified_at", ascending=False).iloc[0]["path"]
    return ColdStorageSummary(
        files=files.drop(columns=["modified_at"]),
        partitions=partitions,
        total_files=int(len(files)),
        total_rows=int(files["rows"].sum()),
        latest_export_path=str(latest_export_path),
    )


def summarize_cloud_cold_path() -> CloudColdSummary:
    bucket = os.getenv("GCS_BUCKET", "")
    dataset = os.getenv("BIGQUERY_DATASET", "")
    table = os.getenv("BIGQUERY_EXTERNAL_TABLE", "sensor_readings_external")

    if not bucket or not dataset:
        return CloudColdSummary(
            configured=False,
            status="No cold export detected",
            bucket=bucket,
            dataset=dataset,
            table=table,
            object_count=0,
            latest_object="",
            row_count=None,
            latest_reading_at="",
            message="Historical archive settings are not connected for this environment.",
        )

    object_count = 0
    latest_object = ""
    storage_message = ""
    try:
        from google.cloud import storage

        client = storage.Client()
        blobs = list(client.list_blobs(bucket, prefix="sensor_readings/", max_results=500))
        parquet_blobs = [blob for blob in blobs if blob.name.endswith(".parquet")]
        object_count = len(parquet_blobs)
        if parquet_blobs:
            latest = max(parquet_blobs, key=lambda blob: blob.updated or blob.time_created)
            latest_object = f"gs://{bucket}/{latest.name}"
    except Exception:
        storage_message = "Archive file listing is temporarily unavailable."

    row_count: int | None = None
    latest_reading_at = ""
    bq_message = ""
    try:
        from google.cloud import bigquery

        project = os.getenv("GCP_PROJECT_ID") or None
        client = bigquery.Client(project=project)
        table_id = f"{client.project}.{dataset}.{table}"
        query = f"""
            SELECT
                COUNT(*) AS row_count,
                CAST(MAX(time) AS STRING) AS latest_reading_at
            FROM `{table_id}`
        """
        result = list(client.query(query).result(max_results=1))
        if result:
            row_count = int(result[0]["row_count"])
            latest_reading_at = result[0]["latest_reading_at"] or ""
    except Exception:
        bq_message = "Analytics summary is being prepared for this environment."

    status = "Cloud archive active" if object_count or (row_count or 0) > 0 else "Cloud archive ready"
    message = "Archive storage and analytics settings are connected."
    if storage_message and bq_message:
        message = f"{storage_message} {bq_message}"
    elif storage_message:
        message = storage_message
    elif bq_message:
        message = bq_message

    return CloudColdSummary(
        configured=True,
        status=status,
        bucket=bucket,
        dataset=dataset,
        table=table,
        object_count=object_count,
        latest_object=latest_object,
        row_count=row_count,
        latest_reading_at=latest_reading_at,
        message=message,
    )


def parse_partition(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for part in path.parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        values[key] = value
    return values
