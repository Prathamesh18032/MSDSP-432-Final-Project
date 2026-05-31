from __future__ import annotations

import json
import os
import urllib.request
from datetime import datetime, timezone
from functools import lru_cache
from typing import Any


SOURCE_LABELS = {
    "simulator": "City Sensor Network",
    "openaq": "Air Quality Network",
    "openmeteo": "Chicago Weather Station",
    "gbfs": "Divvy Bike Share",
    "usgs": "Chicago River Gauge",
}

METRIC_LABELS = {
    "PM2.5": "PM2.5",
    "O3": "Ozone",
    "NO2": "Nitrogen Dioxide",
    "temperature": "Temperature",
    "humidity": "Humidity",
    "wind_speed": "Wind Speed",
    "precipitation": "Precipitation",
    "bike_available_count": "Available Bikes",
    "dock_available_count": "Open Docks",
    "station_capacity": "Station Capacity",
    "water_gage_height": "River Gage Height",
}

METRIC_UNITS = {
    "PM2.5": "µg/m³",
    "O3": "ppm",
    "NO2": "ppm",
    "temperature": "°C",
    "humidity": "%",
    "wind_speed": "km/h",
    "precipitation": "mm",
    "bike_available_count": "bikes",
    "dock_available_count": "docks",
    "station_capacity": "spaces",
    "water_gage_height": "ft",
}

METRIC_DESCRIPTIONS = {
    "PM2.5": "Fine particulate matter measured by nearby air quality stations.",
    "O3": "Ground-level ozone conditions across the selected window.",
    "NO2": "Nitrogen dioxide readings from monitored locations.",
    "temperature": "Current outdoor temperature around Chicago.",
    "humidity": "Relative humidity from the city weather station.",
    "wind_speed": "Wind speed affecting outdoor comfort and operations.",
    "precipitation": "Recent rainfall signal for the selected window.",
    "bike_available_count": "Available bikes across monitored Divvy stations.",
    "dock_available_count": "Open docks available for bike returns.",
    "station_capacity": "Total station capacity observed across the network.",
    "water_gage_height": "Chicago River level at Columbus Drive.",
}

METRIC_DOMAINS = {
    "Air Quality": ["PM2.5", "O3", "NO2"],
    "Weather & Water": ["temperature", "humidity", "wind_speed", "precipitation", "water_gage_height"],
    "Mobility": ["bike_available_count", "dock_available_count", "station_capacity"],
    "All Metrics": [],
}

SOURCE_COLORS = {
    "simulator": "#7C3AED",
    "openaq": "#2563EB",
    "openmeteo": "#059669",
    "gbfs": "#D97706",
    "usgs": "#0891B2",
}

QUALITY_LABELS = {
    1: "Valid",
    0: "Suspect",
    -1: "Invalid",
}


def source_label(source: str | None) -> str:
    if not source:
        return "Unknown Source"
    return SOURCE_LABELS.get(str(source), str(source).replace("_", " ").title())


def metric_label(metric: str | None) -> str:
    if not metric:
        return "Unknown Metric"
    return METRIC_LABELS.get(str(metric), str(metric).replace("_", " ").title())


def metric_unit(metric: str | None, fallback: str = "") -> str:
    if not metric:
        return fallback
    return METRIC_UNITS.get(str(metric), fallback)


def metric_description(metric: str | None) -> str:
    if not metric:
        return "City signal for the selected time window."
    return METRIC_DESCRIPTIONS.get(str(metric), "City signal for the selected time window.")


def metric_group(metric: str | None) -> str:
    value = str(metric or "")
    for group, metrics in METRIC_DOMAINS.items():
        if value in metrics:
            return group
    return "Other"


def quality_label(value: Any) -> str:
    try:
        return QUALITY_LABELS.get(int(value), "Unknown")
    except (TypeError, ValueError):
        return "Unknown"


def freshness_label(latest_at: Any) -> str:
    if not latest_at:
        return "No data"
    if isinstance(latest_at, str):
        try:
            latest_at = datetime.fromisoformat(latest_at.replace("Z", "+00:00"))
        except ValueError:
            return "Unknown"
    if latest_at.tzinfo is None:
        latest_at = latest_at.replace(tzinfo=timezone.utc)
    age_seconds = max(0, (datetime.now(timezone.utc) - latest_at.astimezone(timezone.utc)).total_seconds())
    if age_seconds < 90:
        return "Live"
    if age_seconds < 3600:
        return f"{int(age_seconds // 60)} min ago"
    if age_seconds < 86400:
        return f"{int(age_seconds // 3600)} hr ago"
    return f"{int(age_seconds // 86400)} days ago"


def sensor_display_name(sensor_id: str | None, source: str | None = None) -> str:
    sensor = str(sensor_id or "unknown")
    source_value = str(source or "").lower()

    if source_value == "openmeteo":
        return "Chicago Weather Station"
    if source_value == "usgs" or sensor.startswith("USGS-"):
        return "Chicago River at Columbus Drive"
    if source_value == "gbfs" or sensor.startswith("GBFS-"):
        station_id = sensor.removeprefix("GBFS-")
        return gbfs_station_names().get(station_id, f"Divvy Bike Station {station_id}")
    if source_value == "openaq" or sensor.startswith("OPENAQ-"):
        return f"OpenAQ Air Sensor {sensor.removeprefix('OPENAQ-')}"
    if source_value == "simulator":
        return f"City Sensor {sensor}"
    return sensor


@lru_cache(maxsize=1)
def gbfs_station_names() -> dict[str, str]:
    enabled = os.getenv("STREAMLIT_ENABLE_GBFS_STATION_NAMES", "true").strip().lower()
    if enabled not in {"1", "true", "yes"}:
        return {}

    discovery_url = os.getenv("GBFS_DISCOVERY_URL", "https://gbfs.divvybikes.com/gbfs/gbfs.json")
    language = os.getenv("GBFS_LANGUAGE", "en")
    try:
        with urllib.request.urlopen(discovery_url, timeout=4) as response:
            discovery = json.loads(response.read().decode("utf-8"))
        feeds = discovery.get("data", {}).get(language, {}).get("feeds", [])
        info_url = next(
            (feed.get("url") for feed in feeds if feed.get("name") == "station_information"),
            "",
        )
        if not info_url:
            return {}
        with urllib.request.urlopen(info_url, timeout=4) as response:
            station_info = json.loads(response.read().decode("utf-8"))
    except Exception:
        return {}

    stations = station_info.get("data", {}).get("stations", [])
    return {
        str(station.get("station_id")): str(station.get("name"))
        for station in stations
        if station.get("station_id") and station.get("name")
    }


def add_display_columns(frame):
    if frame.empty:
        return frame
    enriched = frame.copy()
    if "source" in enriched.columns:
        enriched["source_name"] = enriched["source"].map(source_label)
    if "metric" in enriched.columns:
        enriched["metric_name"] = enriched["metric"].map(metric_label)
        enriched["metric_group"] = enriched["metric"].map(metric_group)
    if "quality_flag" in enriched.columns:
        enriched["quality"] = enriched["quality_flag"].map(quality_label)
    if {"sensor_id", "source"}.issubset(enriched.columns):
        enriched["sensor_name"] = enriched.apply(
            lambda row: sensor_display_name(row["sensor_id"], row["source"]),
            axis=1,
        )
    return enriched
