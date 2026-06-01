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


def cutoff(hours: int) -> datetime:
    return datetime.now(timezone.utc) - timedelta(hours=hours)


def overview(hours: int) -> pd.DataFrame:
    return query_dataframe(
        """
        WITH scoped AS (
            SELECT *
            FROM sensor_readings
            WHERE time >= %s
        ), all_rows AS (
            SELECT MAX(time) AS latest_reading_at, MAX(ingested_at) AS latest_ingested_at
            FROM sensor_readings
        ), quality AS (
            SELECT
                COUNT(*)::BIGINT AS total_readings,
                COUNT(DISTINCT sensor_id)::BIGINT AS active_sensors,
                COUNT(DISTINCT metric)::BIGINT AS metrics,
                COUNT(DISTINCT source)::BIGINT AS sources,
                COALESCE(100.0 * SUM(CASE WHEN quality_flag = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0)::DOUBLE PRECISION AS valid_pct
            FROM scoped
        ), ops AS (
            SELECT
                COALESCE(MAX(dropped_readings_total), 0)::BIGINT AS dropped_readings_total,
                COALESCE(MAX(channel_fill_pct), 0)::INTEGER AS channel_fill_pct,
                COALESCE(AVG(readings_per_second), 0)::DOUBLE PRECISION AS avg_readings_per_second
            FROM ingestion_metrics
            WHERE recorded_at >= %s
        ), derived_ops AS (
            SELECT
                0::BIGINT AS dropped_readings_total,
                0::INTEGER AS channel_fill_pct,
                COALESCE(
                    COUNT(*)::DOUBLE PRECISION / NULLIF(
                        EXTRACT(EPOCH FROM (MAX(COALESCE(ingested_at, time)) - MIN(COALESCE(ingested_at, time)))),
                        0
                    ),
                    0
                )::DOUBLE PRECISION AS avg_readings_per_second
            FROM sensor_readings
            WHERE COALESCE(ingested_at, time) >= %s
        ), latest_metrics AS (
            SELECT * FROM ops
            WHERE EXISTS (SELECT 1 FROM ingestion_metrics WHERE recorded_at >= %s)
            UNION ALL
            SELECT * FROM derived_ops
            WHERE NOT EXISTS (SELECT 1 FROM ingestion_metrics WHERE recorded_at >= %s)
        )
        SELECT *
        FROM quality, all_rows, latest_metrics;
        """,
        (cutoff(hours), cutoff(hours), cutoff(hours), cutoff(hours), cutoff(hours)),
    )


def source_options() -> list[str]:
    frame = query_dataframe("SELECT DISTINCT source FROM sensor_readings ORDER BY source;")
    if frame.empty:
        return []
    return frame["source"].dropna().astype(str).tolist()


def metric_options() -> list[str]:
    frame = query_dataframe("SELECT DISTINCT metric FROM sensor_readings ORDER BY metric;")
    if frame.empty:
        return []
    return frame["metric"].dropna().astype(str).tolist()


def source_summary(hours: int) -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            source,
            COUNT(*)::BIGINT AS readings,
            COUNT(DISTINCT sensor_id)::BIGINT AS sensors,
            COUNT(DISTINCT metric)::BIGINT AS metrics,
            MAX(time) AS latest_reading_at,
            MAX(ingested_at) AS latest_ingested_at,
            COALESCE(100.0 * SUM(CASE WHEN quality_flag = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0)::DOUBLE PRECISION AS valid_pct
        FROM sensor_readings
        WHERE time >= %s
        GROUP BY source
        ORDER BY readings DESC;
        """,
        (cutoff(hours),),
    )


def trend(metrics: list[str], hours: int, source: str | None = None) -> pd.DataFrame:
    if not metrics:
        return pd.DataFrame()
    source_clause = "AND source = %s" if source else ""
    params: list[Any] = [cutoff(hours), metrics]
    if source:
        params.append(source)
    return query_dataframe(
        f"""
        SELECT
            time_bucket('5 minutes', time) AS bucket,
            source,
            metric,
            AVG(value)::DOUBLE PRECISION AS avg_value,
            MIN(value)::DOUBLE PRECISION AS min_value,
            MAX(value)::DOUBLE PRECISION AS max_value,
            COUNT(*)::BIGINT AS readings
        FROM sensor_readings
        WHERE time >= %s
          AND metric = ANY(%s)
          AND quality_flag = 1
          {source_clause}
        GROUP BY bucket, source, metric
        ORDER BY bucket, source, metric;
        """,
        tuple(params),
    )


def metric_summary(metrics: list[str], hours: int, source: str | None = None) -> pd.DataFrame:
    if not metrics:
        return pd.DataFrame()
    source_clause = "AND source = %s" if source else ""
    params: list[Any] = [cutoff(hours), metrics]
    if source:
        params.append(source)
    return query_dataframe(
        f"""
        WITH scoped AS (
            SELECT *
            FROM sensor_readings
            WHERE time >= %s
              AND metric = ANY(%s)
              AND quality_flag = 1
              {source_clause}
        ), latest AS (
            SELECT DISTINCT ON (metric)
                metric,
                value AS latest_value,
                unit,
                time AS latest_reading_at
            FROM scoped
            ORDER BY metric, time DESC
        ), stats AS (
            SELECT
                metric,
                AVG(value)::DOUBLE PRECISION AS avg_value,
                MIN(value)::DOUBLE PRECISION AS min_value,
                MAX(value)::DOUBLE PRECISION AS max_value,
                COUNT(*)::BIGINT AS readings,
                COUNT(DISTINCT sensor_id)::BIGINT AS sensors
            FROM scoped
            GROUP BY metric
        )
        SELECT
            stats.metric,
            latest.latest_value,
            latest.unit,
            stats.avg_value,
            stats.min_value,
            stats.max_value,
            stats.readings,
            stats.sensors,
            latest.latest_reading_at
        FROM stats
        JOIN latest USING (metric)
        ORDER BY stats.metric;
        """,
        tuple(params),
    )


def latest_readings(hours: int, source: str | None = None, metrics: list[str] | None = None) -> pd.DataFrame:
    source_clause = "AND source = %s" if source else ""
    metric_clause = "AND metric = ANY(%s)" if metrics else ""
    params: list[Any] = [cutoff(hours)]
    if source:
        params.append(source)
    if metrics:
        params.append(metrics)
    return query_dataframe(
        f"""
        SELECT DISTINCT ON (sensor_id, metric)
            time,
            sensor_id,
            source,
            metric,
            value,
            unit,
            latitude::DOUBLE PRECISION AS latitude,
            longitude::DOUBLE PRECISION AS longitude,
            quality_flag,
            ingested_at
        FROM sensor_readings
        WHERE time >= %s
          {source_clause}
          {metric_clause}
        ORDER BY sensor_id, metric, time DESC;
        """,
        tuple(params),
    )


def sensor_network(hours: int, stale_after_hours: int) -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            sensor_id,
            source,
            COUNT(*)::BIGINT AS readings,
            COUNT(DISTINCT metric)::BIGINT AS metric_count,
            STRING_AGG(DISTINCT metric, ', ' ORDER BY metric) AS metrics,
            MAX(time) AS latest_reading_at,
            MAX(ingested_at) AS latest_ingested_at,
            AVG(latitude)::DOUBLE PRECISION AS latitude,
            AVG(longitude)::DOUBLE PRECISION AS longitude,
            COALESCE(100.0 * SUM(CASE WHEN quality_flag = 1 THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 0)::DOUBLE PRECISION AS valid_pct,
            CASE WHEN MAX(time) >= %s THEN 'fresh' ELSE 'stale' END AS status
        FROM sensor_readings
        WHERE time >= %s
        GROUP BY sensor_id, source
        ORDER BY latest_reading_at DESC, source, sensor_id;
        """,
        (cutoff(stale_after_hours), cutoff(hours)),
    )


def source_metric_counts(hours: int) -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            source,
            metric,
            COUNT(*)::BIGINT AS readings,
            COUNT(DISTINCT sensor_id)::BIGINT AS sensors,
            MAX(time) AS latest_reading_at
        FROM sensor_readings
        WHERE time >= %s
        GROUP BY source, metric
        ORDER BY source, metric;
        """,
        (cutoff(hours),),
    )


def quality_distribution(hours: int) -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            CASE quality_flag
                WHEN 1 THEN 'Valid'
                WHEN 0 THEN 'Suspect'
                ELSE 'Invalid'
            END AS quality,
            COUNT(*)::BIGINT AS readings
        FROM sensor_readings
        WHERE time >= %s
        GROUP BY quality_flag
        ORDER BY quality;
        """,
        (cutoff(hours),),
    )


def metric_coverage(hours: int) -> pd.DataFrame:
    return query_dataframe(
        """
        SELECT
            metric,
            COUNT(DISTINCT source)::BIGINT AS sources,
            COUNT(DISTINCT sensor_id)::BIGINT AS sensors,
            COUNT(*)::BIGINT AS readings,
            MIN(time) AS first_reading_at,
            MAX(time) AS latest_reading_at
        FROM sensor_readings
        WHERE time >= %s
        GROUP BY metric
        ORDER BY readings DESC, metric;
        """,
        (cutoff(hours),),
    )


def ingestion_metrics(hours: int) -> pd.DataFrame:
    frame = query_dataframe(
        """
        SELECT
            time_bucket('1 minute', recorded_at) AS bucket,
            AVG(readings_per_second)::DOUBLE PRECISION AS readings_per_second,
            MAX(channel_fill_pct)::INTEGER AS channel_fill_pct,
            MAX(dropped_readings_total)::BIGINT AS dropped_readings_total,
            AVG(pubsub_lag_ms)::DOUBLE PRECISION AS pubsub_lag_ms,
            AVG(gcs_write_latency_ms)::DOUBLE PRECISION AS gcs_write_latency_ms
        FROM ingestion_metrics
        WHERE recorded_at >= %s
        GROUP BY bucket
        ORDER BY bucket;
        """,
        (cutoff(hours),),
    )
    if not frame.empty:
        return frame
    return query_dataframe(
        """
        SELECT
            time_bucket('1 minute', COALESCE(ingested_at, time)) AS bucket,
            (COUNT(*)::DOUBLE PRECISION / 60.0)::DOUBLE PRECISION AS readings_per_second,
            0::INTEGER AS channel_fill_pct,
            0::BIGINT AS dropped_readings_total,
            NULL::DOUBLE PRECISION AS pubsub_lag_ms,
            NULL::DOUBLE PRECISION AS gcs_write_latency_ms
        FROM sensor_readings
        WHERE COALESCE(ingested_at, time) >= %s
        GROUP BY bucket
        ORDER BY bucket;
        """,
        (cutoff(hours),),
    )


def latest_ingestion_metrics(hours: int) -> pd.DataFrame:
    frame = query_dataframe(
        """
        SELECT
            recorded_at,
            readings_per_second::DOUBLE PRECISION AS readings_per_second,
            channel_fill_pct::INTEGER AS channel_fill_pct,
            dropped_readings_total::BIGINT AS dropped_readings_total,
            pubsub_lag_ms::DOUBLE PRECISION AS pubsub_lag_ms,
            gcs_write_latency_ms::DOUBLE PRECISION AS gcs_write_latency_ms
        FROM ingestion_metrics
        WHERE recorded_at >= %s
        ORDER BY recorded_at DESC
        LIMIT 1;
        """,
        (cutoff(hours),),
    )
    if not frame.empty:
        return frame
    frame = query_dataframe(
        """
        SELECT
            recorded_at,
            readings_per_second::DOUBLE PRECISION AS readings_per_second,
            channel_fill_pct::INTEGER AS channel_fill_pct,
            dropped_readings_total::BIGINT AS dropped_readings_total,
            pubsub_lag_ms::DOUBLE PRECISION AS pubsub_lag_ms,
            gcs_write_latency_ms::DOUBLE PRECISION AS gcs_write_latency_ms
        FROM ingestion_metrics
        ORDER BY recorded_at DESC
        LIMIT 1;
        """,
    )
    if not frame.empty:
        return frame
    return query_dataframe(
        """
        SELECT
            MAX(COALESCE(ingested_at, time)) AS recorded_at,
            COALESCE(
                COUNT(*)::DOUBLE PRECISION / NULLIF(
                    EXTRACT(EPOCH FROM (MAX(COALESCE(ingested_at, time)) - MIN(COALESCE(ingested_at, time)))),
                    0
                ),
                0
            )::DOUBLE PRECISION AS readings_per_second,
            0::INTEGER AS channel_fill_pct,
            0::BIGINT AS dropped_readings_total,
            NULL::DOUBLE PRECISION AS pubsub_lag_ms,
            NULL::DOUBLE PRECISION AS gcs_write_latency_ms
        FROM sensor_readings
        WHERE COALESCE(ingested_at, time) >= %s;
        """,
        (cutoff(hours),),
    )


def domain_latest(domain_metrics: list[str], hours: int) -> pd.DataFrame:
    if not domain_metrics:
        return pd.DataFrame()
    return latest_readings(hours, metrics=domain_metrics)
