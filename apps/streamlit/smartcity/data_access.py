from __future__ import annotations

import os
from datetime import datetime, timedelta, timezone
from typing import Any

import pandas as pd
import psycopg


DEFAULT_DSN = "postgresql://smartcity:smartcity_dev_password@localhost:5432/smartcity_hot"


def timescale_dsn() -> str:
    return os.getenv("STREAMLIT_TIMESCALE_DSN") or os.getenv("TIMESCALE_DSN") or DEFAULT_DSN


def query_dataframe(sql: str, params: tuple[Any, ...] = ()) -> pd.DataFrame:
    with psycopg.connect(timescale_dsn()) as conn:
        with conn.cursor() as cur:
            cur.execute(sql, params)
            columns = [column.name for column in cur.description or []]
            rows = cur.fetchall()
    return pd.DataFrame(rows, columns=columns)


def overview() -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            COUNT(*)::BIGINT AS total_readings,
            COUNT(DISTINCT sensor_id)::BIGINT AS active_sensors,
            COUNT(DISTINCT metric)::BIGINT AS metrics,
            COUNT(DISTINCT source)::BIGINT AS sources,
            MAX(time) AS latest_reading_at
        FROM sensor_readings;
        """
    )


def metric_options() -> list[str]:
    frame = query_dataframe("SELECT DISTINCT metric FROM sensor_readings ORDER BY metric;")
    if frame.empty:
        return []
    return frame["metric"].dropna().astype(str).tolist()


def trend(metric: str, hours: int) -> pd.DataFrame:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=hours)
    return query_dataframe(
        """
        SELECT
            time_bucket('5 minutes', time) AS bucket,
            metric,
            AVG(value)::DOUBLE PRECISION AS avg_value,
            COUNT(*)::BIGINT AS readings
        FROM sensor_readings
        WHERE metric = %s
          AND time >= %s
          AND quality_flag = 1
        GROUP BY bucket, metric
        ORDER BY bucket;
        """,
        (metric, cutoff),
    )


def quality_distribution() -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            CASE quality_flag
                WHEN 1 THEN 'valid'
                WHEN 0 THEN 'suspect'
                ELSE 'invalid'
            END AS quality,
            COUNT(*)::BIGINT AS readings
        FROM sensor_readings
        GROUP BY quality_flag
        ORDER BY quality;
        """
    )


def source_metric_counts() -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            source,
            metric,
            COUNT(*)::BIGINT AS readings
        FROM sensor_readings
        GROUP BY source, metric
        ORDER BY source, metric;
        """
    )


def metric_coverage() -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            metric,
            COUNT(DISTINCT sensor_id)::BIGINT AS sensors,
            COUNT(*)::BIGINT AS readings,
            MIN(time) AS first_reading_at,
            MAX(time) AS latest_reading_at
        FROM sensor_readings
        GROUP BY metric
        ORDER BY metric;
        """
    )


def sensor_health(stale_after_hours: int) -> pd.DataFrame:
    cutoff = datetime.now(timezone.utc) - timedelta(hours=stale_after_hours)
    frame = query_dataframe(
        """
        SELECT
            sensor_id,
            source,
            COUNT(*)::BIGINT AS readings,
            MAX(time) AS latest_reading_at,
            STRING_AGG(DISTINCT metric, ', ' ORDER BY metric) AS metrics
        FROM sensor_readings
        GROUP BY sensor_id, source
        ORDER BY latest_reading_at DESC, sensor_id;
        """
    )
    if not frame.empty:
        frame["status"] = frame["latest_reading_at"].apply(
            lambda value: "fresh" if pd.notna(value) and value >= cutoff else "stale"
        )
    return frame
