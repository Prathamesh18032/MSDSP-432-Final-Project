from __future__ import annotations

import pandas as pd
import streamlit as st

from smartcity import cold_storage, data_access


st.set_page_config(page_title="Smart City Reports", layout="wide")

st.title("Smart City Reports")


def show_empty(message: str) -> None:
    st.info(message)


def show_overview() -> None:
    st.subheader("Overview")
    try:
        frame = data_access.overview()
    except Exception as exc:
        st.error(f"TimescaleDB query failed: {exc}")
        return

    if frame.empty or int(frame.iloc[0]["total_readings"]) == 0:
        show_empty("No readings found in TimescaleDB.")
        return

    row = frame.iloc[0]
    col1, col2, col3, col4, col5 = st.columns(5)
    col1.metric("Readings", f"{int(row['total_readings']):,}")
    col2.metric("Sensors", f"{int(row['active_sensors']):,}")
    col3.metric("Metrics", f"{int(row['metrics']):,}")
    col4.metric("Sources", f"{int(row['sources']):,}")
    latest = row["latest_reading_at"]
    col5.metric("Latest", latest.strftime("%Y-%m-%d %H:%M UTC") if pd.notna(latest) else "n/a")


def show_trends() -> None:
    st.subheader("Air Quality Trends")
    try:
        metrics = data_access.metric_options()
    except Exception as exc:
        st.error(f"Metric lookup failed: {exc}")
        return

    if not metrics:
        show_empty("No metrics available.")
        return

    col1, col2 = st.columns([2, 1])
    metric = col1.selectbox("Metric", metrics, index=0)
    hours = col2.slider("Window (hours)", min_value=1, max_value=168, value=24)

    try:
        frame = data_access.trend(metric, hours)
    except Exception as exc:
        st.error(f"Trend query failed: {exc}")
        return

    if frame.empty:
        show_empty("No trend rows match the selected window.")
        return

    chart_frame = frame.set_index("bucket")[["avg_value"]]
    st.line_chart(chart_frame)
    st.dataframe(frame, use_container_width=True, hide_index=True)


def show_quality() -> None:
    st.subheader("Data Quality")
    col1, col2 = st.columns(2)

    try:
        quality = data_access.quality_distribution()
        counts = data_access.source_metric_counts()
        coverage = data_access.metric_coverage()
    except Exception as exc:
        st.error(f"Quality query failed: {exc}")
        return

    with col1:
        st.caption("Quality Flags")
        if quality.empty:
            show_empty("No quality rows available.")
        else:
            st.bar_chart(quality.set_index("quality")["readings"])

    with col2:
        st.caption("Source and Metric Counts")
        if counts.empty:
            show_empty("No source or metric rows available.")
        else:
            st.dataframe(counts, use_container_width=True, hide_index=True)

    st.caption("Metric Coverage")
    if coverage.empty:
        show_empty("No coverage rows available.")
    else:
        st.dataframe(coverage, use_container_width=True, hide_index=True)


def show_sensor_health() -> None:
    st.subheader("Sensor Health")
    stale_after = st.slider("Stale after (hours)", min_value=1, max_value=168, value=24)

    try:
        frame = data_access.sensor_health(stale_after)
    except Exception as exc:
        st.error(f"Sensor health query failed: {exc}")
        return

    if frame.empty:
        show_empty("No sensor rows available.")
        return

    status_counts = frame["status"].value_counts().rename_axis("status").reset_index(name="sensors")
    col1, col2 = st.columns([1, 3])
    with col1:
        st.bar_chart(status_counts.set_index("status")["sensors"])
    with col2:
        st.dataframe(frame, use_container_width=True, hide_index=True)


def show_cold_storage() -> None:
    st.subheader("Cold Storage")
    try:
        summary = cold_storage.summarize_cold_storage()
    except Exception as exc:
        st.error(f"Cold storage scan failed: {exc}")
        return

    col1, col2 = st.columns(2)
    col1.metric("Parquet Files", f"{summary.total_files:,}")
    col2.metric("Parquet Rows", f"{summary.total_rows:,}")

    if summary.total_files == 0:
        show_empty("No local Parquet files found under the configured cold storage root.")
        return

    st.caption("Latest Export")
    st.code(summary.latest_export_path)
    st.caption("Partition Coverage")
    st.dataframe(summary.partitions, use_container_width=True, hide_index=True)
    st.caption("Files")
    st.dataframe(summary.files, use_container_width=True, hide_index=True)


show_overview()

tab_trends, tab_quality, tab_health, tab_cold = st.tabs(
    ["Air Quality Trends", "Data Quality", "Sensor Health", "Cold Storage"]
)

with tab_trends:
    show_trends()
with tab_quality:
    show_quality()
with tab_health:
    show_sensor_health()
with tab_cold:
    show_cold_storage()
