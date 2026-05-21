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


def parse_partition(path: Path) -> dict[str, str]:
    values: dict[str, str] = {}
    for part in path.parts:
        if "=" not in part:
            continue
        key, value = part.split("=", 1)
        values[key] = value
    return values
