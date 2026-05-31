from __future__ import annotations

import os
from dataclasses import dataclass
from typing import Any

import pandas as pd
import streamlit as st
try:
    from streamlit_autorefresh import st_autorefresh
except Exception:  # pragma: no cover - optional local dependency guard
    st_autorefresh = None

from smartcity import charts, cold_storage, data_access, metadata, styles


BRAND_TITLE = os.getenv("STREAMLIT_BRAND_TITLE", "Smart City Command Center")
CITY_NAME = os.getenv("STREAMLIT_CITY_NAME", "Chicago")

st.set_page_config(page_title=BRAND_TITLE, layout="wide", initial_sidebar_state="auto")
styles.inject_styles()


@dataclass(frozen=True)
class Filters:
    hours: int
    source: str | None
    metric_category: str
    metrics: list[str]
    quality: str
    refresh_seconds: int


def public_demo_enabled() -> bool:
    return os.getenv("PUBLIC_DEMO_ENABLED", "false").strip().lower() in {"1", "true", "yes"}


def require_demo_password() -> bool:
    if not public_demo_enabled():
        return True

    expected_password = os.getenv("STREAMLIT_DEMO_PASSWORD", "")
    if not expected_password:
        st.error("Demo access is not ready yet. Please contact the project team.")
        return False

    if st.session_state.get("demo_authenticated") is True:
        return True

    styles.inject_login_styles()
    left, right = st.columns([1.15, .85], gap="large", vertical_alignment="center")
    with left:
        st.markdown(
            f"""
            <div class="sc-login-copy">
                <div class="sc-login-logo">Smart City Command Center</div>
                <h1>{CITY_NAME} operations, clearly connected.</h1>
                <p>
                    Explore air quality, weather, mobility, river levels, and city service
                    readiness through a secure reviewer portal.
                </p>
                <div class="sc-login-signals">
                    <span class="sc-login-signal">Live city indicators</span>
                    <span class="sc-login-signal">Protected reviewer access</span>
                    <span class="sc-login-signal">Executive-ready reports</span>
                </div>
            </div>
            """,
            unsafe_allow_html=True,
        )

    with right:
        st.markdown(
            """
            <div class="sc-login-card-intro">
                <h2>Access the command center</h2>
                <p>Enter the shared review password, then select Sign in to continue.</p>
            </div>
            """,
            unsafe_allow_html=True,
        )
        with st.form("public_demo_gate", clear_on_submit=False):
            supplied_password = st.text_input(
                "Demo password",
                type="password",
                placeholder="Enter demo password",
                key="demo_password",
            )
            submitted = st.form_submit_button("Sign in", use_container_width=True)

        if submitted:
            if supplied_password == expected_password:
                st.session_state["demo_authenticated"] = True
                st.session_state["demo_password_invalid"] = False
                st.rerun()
            else:
                st.session_state["demo_password_invalid"] = True
        if st.session_state.get("demo_password_invalid") is True:
            st.error("That password did not match. Please check capitalization and try again.")
        st.markdown(
            '<div class="sc-login-card-note">Demo access is monitored for review use. '
            'Only this reporting experience is available to invited reviewers.</div>',
            unsafe_allow_html=True,
        )
    return False


if not require_demo_password():
    st.stop()


def format_int(value: Any) -> str:
    try:
        return f"{int(value):,}"
    except (TypeError, ValueError):
        return "0"


def format_pct(value: Any) -> str:
    try:
        return f"{float(value):.1f}%"
    except (TypeError, ValueError):
        return "0.0%"


def format_decimal(value: Any, digits: int = 1) -> str:
    try:
        number = float(value)
    except (TypeError, ValueError):
        return "n/a"
    return f"{number:,.{digits}f}"


def format_metric_value(value: Any, unit: str = "") -> str:
    formatted = format_decimal(value, 1)
    if formatted == "n/a":
        return formatted
    return f"{formatted} {unit}".strip()


def format_time(value: Any) -> str:
    if pd.isna(value) or value in ("", None):
        return "n/a"
    if hasattr(value, "strftime"):
        return value.strftime("%Y-%m-%d %H:%M UTC")
    return str(value)


def download_csv(label: str, frame: pd.DataFrame, key: str) -> None:
    if frame.empty:
        return
    csv = frame.to_csv(index=False).encode("utf-8")
    st.download_button(
        label,
        data=csv,
        file_name=f"{key}.csv",
        mime="text/csv",
        key=f"download_{key}",
        use_container_width=True,
    )


def filter_quality(frame: pd.DataFrame, quality: str) -> pd.DataFrame:
    if frame.empty or quality == "All" or "quality" not in frame.columns:
        return frame
    return frame[frame["quality"] == quality].copy()


def apply_frame_filters(frame: pd.DataFrame, filters: Filters) -> pd.DataFrame:
    scoped = filter_quality(frame, filters.quality)
    if filters.source and "source" in scoped.columns:
        scoped = scoped[scoped["source"] == filters.source].copy()
    return scoped


@st.cache_data(ttl=30)
def load_options() -> tuple[list[str], list[str]]:
    return data_access.source_options(), data_access.metric_options()


def sidebar_filters() -> Filters:
    default_hours = int(os.getenv("STREAMLIT_DEFAULT_WINDOW_HOURS", "24"))
    default_refresh = int(os.getenv("STREAMLIT_REFRESH_SECONDS", "60"))
    try:
        sources, metrics = load_options()
    except Exception:
        st.sidebar.error("City data is currently unavailable. Please try again shortly.")
        sources, metrics = [], []

    st.sidebar.title("Command Center")
    st.sidebar.caption("Tune the city view for the story you want to inspect.")
    hours = st.sidebar.select_slider(
        "Time window",
        options=[1, 3, 6, 12, 24, 48, 72, 168],
        value=default_hours if default_hours in [1, 3, 6, 12, 24, 48, 72, 168] else 24,
    )
    source_labels = ["All Sources"] + [metadata.source_label(source) for source in sources]
    source_choice = st.sidebar.selectbox("Source", source_labels)
    source = None if source_choice == "All Sources" else sources[source_labels.index(source_choice) - 1]

    category = st.sidebar.selectbox("Metric category", list(metadata.METRIC_DOMAINS.keys()))
    category_metrics = metadata.METRIC_DOMAINS[category]
    selected_metrics = category_metrics or metrics
    selected_metrics = [metric for metric in selected_metrics if not metrics or metric in metrics]
    if not selected_metrics and metrics:
        selected_metrics = metrics

    quality = st.sidebar.selectbox("Quality flag", ["All", "Valid", "Suspect", "Invalid"])
    refresh_seconds = st.sidebar.selectbox(
        "Auto-refresh",
        [0, 30, 60, 120, 300],
        index=[0, 30, 60, 120, 300].index(default_refresh) if default_refresh in [0, 30, 60, 120, 300] else 2,
        format_func=lambda value: "Off" if value == 0 else f"{value}s",
    )
    if refresh_seconds:
        st.sidebar.caption(f"Refreshes every {refresh_seconds} seconds.")
    return Filters(hours, source, category, selected_metrics, quality, refresh_seconds)


def header(snapshot: pd.Series | None, source_summary: pd.DataFrame) -> None:
    latest = snapshot.get("latest_reading_at") if snapshot is not None else None
    freshness = metadata.freshness_label(latest)
    fresh_tone = "good" if freshness in {"Live"} or "min ago" in freshness else "warn"
    source_count = 0 if source_summary.empty else len(source_summary)
    pills = [
        styles.status_pill(f"{CITY_NAME} coverage", "good"),
        styles.status_pill(f"{source_count} sources online", "good" if source_count else "warn"),
        styles.status_pill(f"Freshness: {freshness}", fresh_tone),
        styles.status_pill("Protected access" if public_demo_enabled() else "Private view", "good"),
    ]
    st.markdown(
        f"""
        <div class="sc-header">
            <div>
                <div class="sc-kicker">{CITY_NAME} Smart City</div>
                <h1 class="sc-title">{BRAND_TITLE}</h1>
                <div class="sc-subtitle">
                    A city operations view for air quality, weather, bike-share availability,
                    river conditions, service health, and reporting evidence.
                </div>
            </div>
            <div class="sc-status-row">{''.join(pills)}</div>
        </div>
        """,
        unsafe_allow_html=True,
    )


def executive_overview(snapshot: pd.Series | None, cold_summary: cold_storage.ColdStorageSummary, cloud_summary: cold_storage.CloudColdSummary) -> None:
    styles.section("Executive Overview", "City-level operating indicators for the selected time window.")
    if snapshot is None:
        styles.empty_state("No city readings are available for this window yet.")
        return

    cold_status = "Archive available" if cold_summary.total_files else cloud_summary.status
    freshness = metadata.freshness_label(snapshot.get("latest_reading_at"))
    valid_pct = float(snapshot.get("valid_pct") or 0)
    dropped = int(snapshot.get("dropped_readings_total") or 0)
    styles.card_grid(
        [
            {
                "label": "Readings reviewed",
                "value": format_int(snapshot.get("total_readings")),
                "note": f"Across the last {format_int(snapshot.get('metrics'))} city signals.",
                "tone": "good",
            },
            {
                "label": "Active sensors",
                "value": format_int(snapshot.get("active_sensors")),
                "note": f"{format_int(snapshot.get('sources'))} source groups are contributing.",
                "tone": "good" if int(snapshot.get("active_sensors") or 0) else "warn",
            },
            {
                "label": "Data quality",
                "value": format_pct(valid_pct),
                "note": "Share of readings accepted as ready for reporting.",
                "tone": "good" if valid_pct >= 95 else "warn",
            },
            {
                "label": "Latest city update",
                "value": freshness,
                "note": format_time(snapshot.get("latest_reading_at")),
                "tone": "good" if freshness == "Live" or "min ago" in freshness else "warn",
            },
            {
                "label": "Service interruptions",
                "value": "None" if dropped == 0 else format_int(dropped),
                "note": "No recent interruptions detected." if dropped == 0 else "Some readings need service review.",
                "tone": "good" if dropped == 0 else "warn",
            },
            {
                "label": "Archive status",
                "value": cold_status,
                "note": "Historical reporting evidence for the city data record.",
                "tone": "good" if cold_status != "No cold export detected" else "warn",
            },
        ]
    )


def executive_report(snapshot: pd.Series | None, source_summary: pd.DataFrame, cloud_summary: cold_storage.CloudColdSummary, filters: Filters) -> None:
    if snapshot is None:
        return
    source_names = []
    if not source_summary.empty:
        source_names = metadata.add_display_columns(source_summary)["source_name"].astype(str).tolist()
    latest = metadata.freshness_label(snapshot.get("latest_reading_at"))
    archive_status = cloud_summary.status
    bullets = [
        f"{CITY_NAME} has {format_int(snapshot.get('active_sensors'))} monitored locations across {format_int(snapshot.get('sources'))} source groups.",
        f"The selected {filters.hours}-hour view includes {format_int(snapshot.get('total_readings'))} readings with {format_pct(snapshot.get('valid_pct'))} ready for reporting.",
        f"The latest city update is {latest}; most recent timestamp: {format_time(snapshot.get('latest_reading_at'))}.",
        f"Active source groups: {', '.join(source_names[:5]) if source_names else 'No active source groups in this window'}.",
        f"Historical archive status: {archive_status}.",
    ]
    styles.report_panel("Executive report", bullets)


def city_operations(filters: Filters) -> None:
    styles.section("City Operations", "Source activity, current availability, and recent service signals.")
    try:
        summary = data_access.source_summary(filters.hours)
        ops = data_access.ingestion_metrics(filters.hours)
        latest_ops = data_access.latest_ingestion_metrics(filters.hours)
    except Exception:
        st.error("Operations view is temporarily unavailable.")
        return

    if filters.source and not summary.empty:
        summary = summary[summary["source"] == filters.source].copy()

    if summary.empty:
        styles.empty_state("No city activity was recorded in the selected time window.")
        return

    total_readings = int(summary["readings"].sum())
    latest_at = summary["latest_reading_at"].max()
    service_note = "Service activity is available for the selected window."
    service_tone = "good"
    if latest_ops.empty:
        service_note = "No service events were reported during the selected window."
    else:
        latest = latest_ops.iloc[0]
        service_note = f"{format_decimal(latest.get('readings_per_second'), 2)} new readings each second at last check."
        service_tone = "warn" if int(latest.get("dropped_readings_total") or 0) else "good"

    styles.card_grid(
        [
            {
                "label": "City activity",
                "value": format_int(total_readings),
                "note": f"Latest update: {metadata.freshness_label(latest_at)}.",
                "tone": "good",
            },
            {
                "label": "Sources reporting",
                "value": format_int(len(summary)),
                "note": "Active city data groups in this view.",
                "tone": "good",
            },
            {
                "label": "Service health",
                "value": "Healthy" if service_tone == "good" else "Needs review",
                "note": service_note,
                "tone": service_tone,
            },
        ]
    )

    left, right = st.columns([1.1, 1])
    with left:
        st.plotly_chart(charts.source_activity(summary), use_container_width=True)
    with right:
        enriched = metadata.add_display_columns(summary)
        table = enriched[["source_name", "readings", "sensors", "metrics", "valid_pct", "latest_reading_at"]].copy()
        table["valid_pct"] = table["valid_pct"].map(format_pct)
        table["latest_reading_at"] = table["latest_reading_at"].map(format_time)
        table.columns = ["Source", "Readings", "Sensors", "Signals", "Ready %", "Latest update"]
        st.dataframe(table, use_container_width=True, hide_index=True)
        download_csv("Download source summary", table, "source-summary")

    if ops.empty:
        styles.mini_panels(
            [
                {
                    "title": "No service alerts in this window",
                    "note": "The city readings are still available above. Service trend lines appear after the next activity sample.",
                }
            ]
        )
    else:
        st.plotly_chart(charts.ingestion_trend(ops), use_container_width=True)


def air_quality(filters: Filters) -> None:
    styles.section("Air Quality", "Pollutant trends and current readings across monitored locations.")
    metrics = [metric for metric in ["PM2.5", "O3", "NO2"] if metric in filters.metrics or filters.metric_category == "All Metrics"]
    if not metrics:
        metrics = ["PM2.5", "O3", "NO2"]
    try:
        trend = data_access.trend(metrics, filters.hours, filters.source)
        summary = data_access.metric_summary(metrics, filters.hours, filters.source)
        latest = apply_frame_filters(metadata.add_display_columns(data_access.domain_latest(metrics, filters.hours)), filters)
    except Exception:
        st.error("Air quality view is temporarily unavailable.")
        return
    if trend.empty and latest.empty:
        styles.empty_state("No air quality readings match the selected filters.")
        return
    if not summary.empty:
        cards = []
        for _, row in metadata.add_display_columns(summary).iterrows():
            unit = row.get("unit") or metadata.metric_unit(row.get("metric"))
            cards.append(
                {
                    "label": row.get("metric_name", row.get("metric")),
                    "value": format_metric_value(row.get("latest_value"), unit),
                    "note": f"Average {format_metric_value(row.get('avg_value'), unit)} across {format_int(row.get('readings'))} readings.",
                    "tone": "good",
                }
            )
        styles.card_grid(cards)
    if not trend.empty:
        st.plotly_chart(charts.trend(trend, "Air quality trend"), use_container_width=True)
    if not latest.empty:
        table = latest[["sensor_name", "metric_name", "value", "unit", "quality", "time"]].copy()
        table["time"] = table["time"].map(format_time)
        table.columns = ["Location", "Signal", "Latest", "Unit", "Status", "Updated"]
        st.dataframe(table, use_container_width=True, hide_index=True)
        download_csv("Download air quality readings", table, "air-quality-readings")


def mobility(filters: Filters) -> None:
    styles.section("Mobility", "Divvy station availability, dock pressure, and capacity signals.")
    metrics = ["bike_available_count", "dock_available_count", "station_capacity"]
    try:
        summary = data_access.metric_summary(metrics, filters.hours, filters.source)
        latest = apply_frame_filters(metadata.add_display_columns(data_access.domain_latest(metrics, filters.hours)), filters)
    except Exception:
        st.error("Mobility view is temporarily unavailable.")
        return
    if latest.empty:
        styles.empty_state("No Divvy bike-share readings match the selected filters.")
        return

    if not summary.empty:
        cards = []
        for _, row in metadata.add_display_columns(summary).iterrows():
            unit = row.get("unit") or metadata.metric_unit(row.get("metric"))
            cards.append(
                {
                    "label": row.get("metric_name", row.get("metric")),
                    "value": format_metric_value(row.get("latest_value"), unit),
                    "note": f"Observed across {format_int(row.get('sensors'))} stations.",
                    "tone": "good",
                }
            )
        styles.card_grid(cards)

    left, right = st.columns([1, 1])
    with left:
        st.plotly_chart(charts.latest_domain_bar(latest, "Latest station signals"), use_container_width=True)
    with right:
        st.plotly_chart(charts.mobility_utilization(latest), use_container_width=True)
    table = latest[["sensor_name", "metric_name", "value", "unit", "time"]].copy()
    table["time"] = table["time"].map(format_time)
    table.columns = ["Station", "Signal", "Latest", "Unit", "Updated"]
    st.dataframe(table, use_container_width=True, hide_index=True)
    download_csv("Download mobility readings", table, "mobility-readings")


def weather_water(filters: Filters) -> None:
    styles.section("Weather & Water", "Weather conditions and river level context for city operations.")
    metrics = ["temperature", "humidity", "wind_speed", "precipitation", "water_gage_height"]
    try:
        trend = data_access.trend(metrics, filters.hours, filters.source)
        summary = data_access.metric_summary(metrics, filters.hours, filters.source)
        latest = apply_frame_filters(metadata.add_display_columns(data_access.domain_latest(metrics, filters.hours)), filters)
    except Exception:
        st.error("Weather and river view is temporarily unavailable.")
        return
    if trend.empty and latest.empty:
        styles.empty_state("No weather or river readings match the selected filters.")
        return

    if not summary.empty:
        cards = []
        for _, row in metadata.add_display_columns(summary).iterrows():
            unit = row.get("unit") or metadata.metric_unit(row.get("metric"))
            cards.append(
                {
                    "label": row.get("metric_name", row.get("metric")),
                    "value": format_metric_value(row.get("latest_value"), unit),
                    "note": f"Range {format_metric_value(row.get('min_value'), unit)} to {format_metric_value(row.get('max_value'), unit)}.",
                    "tone": "good",
                }
            )
        styles.card_grid(cards)

    if not trend.empty:
        chart_metrics = [metric for metric in metrics if metric in set(trend["metric"].astype(str))]
        for index in range(0, len(chart_metrics), 2):
            cols = st.columns(2)
            for col, metric in zip(cols, chart_metrics[index:index + 2]):
                with col:
                    unit = metadata.metric_unit(metric)
                    st.plotly_chart(
                        charts.metric_trend(
                            trend,
                            metric,
                            f"{metadata.metric_label(metric)} trend",
                            unit,
                        ),
                        use_container_width=True,
                    )
    if not latest.empty:
        table = latest[["sensor_name", "metric_name", "value", "unit", "quality", "time"]].copy()
        table["time"] = table["time"].map(format_time)
        table.columns = ["Location", "Signal", "Latest", "Unit", "Status", "Updated"]
        st.dataframe(table, use_container_width=True, hide_index=True)
        download_csv("Download weather and river readings", table, "weather-river-readings")


def sensor_network(filters: Filters) -> None:
    styles.section("Sensor Network", "Friendly locations, freshness, and monitored signals.")
    try:
        network = metadata.add_display_columns(data_access.sensor_network(filters.hours, stale_after_hours=24))
    except Exception:
        st.error("Sensor network view is temporarily unavailable.")
        return
    if network.empty:
        styles.empty_state("No sensors are available for this time window.")
        return

    if filters.source:
        network = network[network["source"] == filters.source].copy()

    fresh = int((network["status"] == "fresh").sum()) if "status" in network.columns else 0
    total = int(len(network))
    styles.card_grid(
        [
            {
                "label": "Locations monitored",
                "value": format_int(total),
                "note": "Unique reporting points in the selected window.",
                "tone": "good" if total else "warn",
            },
            {
                "label": "Recently updated",
                "value": format_int(fresh),
                "note": "Locations refreshed in the last day.",
                "tone": "good" if fresh else "warn",
            },
            {
                "label": "Signals tracked",
                "value": format_int(network["metric_count"].sum() if "metric_count" in network.columns else 0),
                "note": "Air, weather, water, and mobility signals combined.",
                "tone": "good",
            },
        ]
    )

    left, right = st.columns([1, 1.05])
    with left:
        map_frame = network.dropna(subset=["latitude", "longitude"])
        if map_frame.empty:
            styles.empty_state("Map coordinates are not available for the selected sensors.")
        else:
            st.plotly_chart(charts.map_points(map_frame), use_container_width=True)
    with right:
        table = network[
            ["sensor_name", "source_name", "status", "metric_count", "readings", "valid_pct", "latest_reading_at"]
        ].copy()
        table["status"] = table["status"].map(lambda value: "Current" if value == "fresh" else "Needs update")
        table["valid_pct"] = table["valid_pct"].map(format_pct)
        table["latest_reading_at"] = table["latest_reading_at"].map(format_time)
        table.columns = ["Location", "Category", "Status", "Signals", "Readings", "Ready %", "Updated"]
        styles.responsive_table(table, max_rows=16)
        download_csv("Download sensor network", table, "sensor-network")

    with st.expander("Location details"):
        details = network[
            ["sensor_name", "source_name", "metrics", "latitude", "longitude", "latest_reading_at"]
        ].copy()
        details["latest_reading_at"] = details["latest_reading_at"].map(format_time)
        details.columns = ["Location", "Category", "Signals", "Latitude", "Longitude", "Updated"]
        st.dataframe(details, use_container_width=True, hide_index=True)


def data_quality(filters: Filters) -> None:
    styles.section("Data Quality", "Coverage and readiness indicators for trusted reporting.")
    try:
        quality = data_access.quality_distribution(filters.hours)
        coverage = data_access.metric_coverage(filters.hours)
    except Exception:
        st.error("Data quality view is temporarily unavailable.")
        return
    if not quality.empty:
        valid_row = quality[quality["quality"] == "Valid"]
        valid_readings = int(valid_row["readings"].sum()) if not valid_row.empty else 0
        total_readings = int(quality["readings"].sum())
        valid_pct = (100 * valid_readings / total_readings) if total_readings else 0
    else:
        total_readings = 0
        valid_pct = 0
    styles.card_grid(
        [
            {
                "label": "Readiness score",
                "value": format_pct(valid_pct),
                "note": "Share of records ready for reporting.",
                "tone": "good" if valid_pct >= 95 else "warn",
            },
            {
                "label": "Records checked",
                "value": format_int(total_readings),
                "note": f"Within the last {filters.hours} hours.",
                "tone": "good" if total_readings else "warn",
            },
            {
                "label": "Signals covered",
                "value": format_int(len(coverage)) if not coverage.empty else "0",
                "note": "Distinct city signals with recent coverage.",
                "tone": "good" if not coverage.empty else "warn",
            },
        ]
    )
    left, right = st.columns([.8, 1.2])
    with left:
        if quality.empty:
            styles.empty_state("No quality status is available for this window.")
        else:
            st.plotly_chart(charts.quality_donut(quality), use_container_width=True)
    with right:
        if coverage.empty:
            styles.empty_state("No coverage summary is available for this window.")
        else:
            st.plotly_chart(charts.metric_coverage(coverage), use_container_width=True)
            export = metadata.add_display_columns(coverage).copy()
            export = export[["metric_name", "sources", "sensors", "readings", "latest_reading_at"]]
            export["latest_reading_at"] = export["latest_reading_at"].map(format_time)
            export.columns = ["Signal", "Sources", "Locations", "Readings", "Latest update"]
            download_csv("Download coverage summary", export, "coverage-summary")


def cold_path() -> None:
    styles.section("Historical Archive", "Longer-term reporting evidence for city readings.")
    try:
        local = cold_storage.summarize_cold_storage()
        cloud = cold_storage.summarize_cloud_cold_path()
    except Exception:
        st.error("Archive summary is temporarily unavailable.")
        return

    if local.total_files:
        styles.card_grid(
            [
                {
                    "label": "Archive status",
                    "value": "Local archive available",
                    "note": "Historical files are mounted for this review.",
                    "tone": "good",
                },
                {
                    "label": "Archive files",
                    "value": format_int(local.total_files),
                    "note": "Partitioned report files detected.",
                    "tone": "good",
                },
                {
                    "label": "Archived readings",
                    "value": format_int(local.total_rows),
                    "note": "Rows available for historical reporting.",
                    "tone": "good",
                },
            ]
        )
        partitions = local.partitions.copy()
        partitions["source"] = partitions["source"].map(metadata.source_label)
        partitions["metric"] = partitions["metric"].map(metadata.metric_label)
        partitions = partitions[["source", "metric", "partition_date", "files", "rows"]]
        partitions.columns = ["Source", "Signal", "Date", "Files", "Rows"]
        styles.responsive_table(partitions, max_rows=20)
        download_csv("Download archive summary", partitions, "archive-summary")
        return

    analytics_status = "Available" if cloud.row_count is not None else "Preparing"
    styles.card_grid(
        [
            {
                "label": "Archive status",
                "value": cloud.status,
                "note": "Cloud archive configured for historical reporting." if cloud.configured else "No archive has been detected yet.",
                "tone": "good" if cloud.configured else "warn",
            },
            {
                "label": "Archive files",
                "value": format_int(cloud.object_count),
                "note": "Cloud report files available for review.",
                "tone": "good" if cloud.object_count else "warn",
            },
            {
                "label": "Analytics status",
                "value": analytics_status,
                "note": "Historical summary can be queried by the reporting app." if cloud.row_count is not None else cloud.message,
                "tone": "good" if cloud.row_count is not None else "warn",
            },
            {
                "label": "Archived readings",
                "value": "n/a" if cloud.row_count is None else format_int(cloud.row_count),
                "note": "Rows currently visible to the reporting view.",
                "tone": "good" if cloud.row_count is not None else "warn",
            },
        ]
    )
    if not cloud.configured:
        styles.empty_state("No historical archive is connected to this review environment yet.")


def render_dashboard() -> None:
    filters = sidebar_filters()
    if filters.refresh_seconds and st_autorefresh is not None:
        st_autorefresh(interval=filters.refresh_seconds * 1000, key="command_center_refresh")
    elif filters.refresh_seconds:
        st.sidebar.caption("Automatic refresh is not available in this environment.")

    try:
        snapshot_frame = data_access.overview(filters.hours)
        snapshot = None if snapshot_frame.empty else snapshot_frame.iloc[0]
        source_summary = data_access.source_summary(filters.hours)
    except Exception:
        header(None, pd.DataFrame())
        st.error("City data is currently unavailable. Please try again shortly.")
        return

    local_cold = cold_storage.summarize_cold_storage()
    cloud_cold = cold_storage.summarize_cloud_cold_path()
    header(snapshot, source_summary)
    executive_overview(snapshot, local_cold, cloud_cold)
    executive_report(snapshot, source_summary, cloud_cold, filters)

    tab_overview, tab_domains, tab_network, tab_quality, tab_cold = st.tabs(
        ["Operations", "Domains", "Sensors", "Quality", "Archive"]
    )
    with tab_overview:
        city_operations(filters)
    with tab_domains:
        air_quality(filters)
        mobility(filters)
        weather_water(filters)
    with tab_network:
        sensor_network(filters)
    with tab_quality:
        data_quality(filters)
    with tab_cold:
        cold_path()

render_dashboard()
