from __future__ import annotations

import pandas as pd
import plotly.express as px
import plotly.graph_objects as go

from smartcity import metadata


PLOT_TEMPLATE = "plotly_white"
PLOT_TEXT = "#182230"
PLOT_MUTED = "#475467"
PLOT_GRID = "#e4e7ec"
PLOT_HOVER_BG = "#ffffff"
PLOT_HOVER_BORDER = "#d0d5dd"


def finish(fig: go.Figure, height: int = 340) -> go.Figure:
    fig.update_layout(
        template=PLOT_TEMPLATE,
        height=height,
        margin=dict(l=20, r=20, t=38, b=24),
        paper_bgcolor="rgba(0,0,0,0)",
        plot_bgcolor="rgba(0,0,0,0)",
        legend_title_text="",
        font=dict(
            family="Inter, -apple-system, BlinkMacSystemFont, Segoe UI, sans-serif",
            size=12,
            color=PLOT_TEXT,
        ),
        title=dict(font=dict(color=PLOT_TEXT, size=16)),
        legend=dict(font=dict(color=PLOT_TEXT)),
        hovermode="x unified",
        hoverlabel=dict(bgcolor=PLOT_HOVER_BG, bordercolor=PLOT_HOVER_BORDER, font=dict(color=PLOT_TEXT)),
    )
    fig.update_xaxes(
        showgrid=True,
        gridcolor=PLOT_GRID,
        zeroline=False,
        color=PLOT_MUTED,
        tickfont=dict(color=PLOT_MUTED),
        title_font=dict(color=PLOT_MUTED),
    )
    fig.update_yaxes(
        showgrid=True,
        gridcolor=PLOT_GRID,
        zeroline=False,
        color=PLOT_MUTED,
        tickfont=dict(color=PLOT_MUTED),
        title_font=dict(color=PLOT_MUTED),
    )
    fig.update_traces(textfont=dict(color=PLOT_TEXT), selector=dict(type="bar"))
    fig.update_traces(textfont=dict(color=PLOT_TEXT), selector=dict(type="pie"))
    return fig


def source_activity(frame: pd.DataFrame) -> go.Figure:
    data = metadata.add_display_columns(frame)
    fig = px.bar(
        data,
        x="source_name",
        y="readings",
        color="source",
        color_discrete_map=metadata.SOURCE_COLORS,
        labels={"source_name": "", "readings": "Readings"},
        title="Activity by source",
    )
    return finish(fig, 320)


def trend(frame: pd.DataFrame, title: str) -> go.Figure:
    data = metadata.add_display_columns(frame)
    data["series"] = data["source_name"] + " · " + data["metric_name"]
    fig = px.line(
        data,
        x="bucket",
        y="avg_value",
        color="series",
        markers=False,
        labels={"bucket": "", "avg_value": "Average value"},
        title=title,
    )
    return finish(fig, 360)


def metric_trend(frame: pd.DataFrame, metric: str, title: str, unit: str) -> go.Figure:
    data = metadata.add_display_columns(frame[frame["metric"] == metric].copy())
    if data.empty:
        fig = go.Figure()
        fig.update_layout(title=title)
        return finish(fig, 280)
    data["series"] = data["source_name"]
    fig = px.line(
        data,
        x="bucket",
        y="avg_value",
        color="series",
        markers=True,
        labels={"bucket": "", "avg_value": unit or "Value"},
        title=title,
        color_discrete_map=metadata.SOURCE_COLORS,
    )
    return finish(fig, 280)


def quality_donut(frame: pd.DataFrame) -> go.Figure:
    fig = px.pie(
        frame,
        names="quality",
        values="readings",
        hole=.62,
        color="quality",
        color_discrete_map={"Valid": "#16A34A", "Suspect": "#D97706", "Invalid": "#DC2626"},
        title="Quality distribution",
    )
    fig.update_traces(textposition="inside", textinfo="percent+label")
    return finish(fig, 320)


def metric_coverage(frame: pd.DataFrame) -> go.Figure:
    data = metadata.add_display_columns(frame.head(14))
    fig = px.bar(
        data.sort_values("readings", ascending=True),
        x="readings",
        y="metric_name",
        orientation="h",
        labels={"metric_name": "", "readings": "Readings"},
        title="Coverage by metric",
    )
    return finish(fig, 360)


def ingestion_trend(frame: pd.DataFrame) -> go.Figure:
    fig = go.Figure()
    fig.add_trace(
        go.Scatter(
            x=frame["bucket"],
            y=frame["readings_per_second"],
            name="Activity rate",
            mode="lines",
            line=dict(color="#2563EB", width=2),
        )
    )
    fig.add_trace(
        go.Scatter(
            x=frame["bucket"],
            y=frame["channel_fill_pct"],
            name="Service capacity used",
            mode="lines",
            line=dict(color="#D97706", width=2),
            yaxis="y2",
        )
    )
    fig.update_layout(
        title="Service activity",
        yaxis=dict(title="Activity rate"),
        yaxis2=dict(
            title="Capacity used %",
            overlaying="y",
            side="right",
            rangemode="tozero",
            color=PLOT_MUTED,
            tickfont=dict(color=PLOT_MUTED),
            title_font=dict(color=PLOT_MUTED),
            gridcolor=PLOT_GRID,
            zeroline=False,
        ),
    )
    return finish(fig, 330)


def safety_ai_timeline(frame: pd.DataFrame) -> go.Figure:
    fig = px.bar(
        frame,
        x="bucket",
        y="predictions",
        color="prediction_type",
        barmode="stack",
        labels={"bucket": "", "predictions": "Predictions", "prediction_type": ""},
        title="Prediction activity over time",
        color_discrete_map={
            "AI-flagged possible activity": "#B42318",
            "Normal review frame": "#067647",
        },
    )
    return finish(fig, 300)


def safety_ai_by_camera(frame: pd.DataFrame) -> go.Figure:
    fig = px.bar(
        frame,
        x="flagged",
        y="location_name",
        orientation="h",
        color="avg_confidence",
        color_continuous_scale=["#FEF3C7", "#B42318"],
        labels={"flagged": "AI-flagged frames", "location_name": "", "avg_confidence": "Avg confidence"},
        title="AI-flagged frames by camera zone",
    )
    fig.update_layout(coloraxis_colorbar=dict(tickfont=dict(color=PLOT_MUTED), title_font=dict(color=PLOT_MUTED)))
    return finish(fig, 320)


def safety_ai_by_label(frame: pd.DataFrame) -> go.Figure:
    severity_colors = {"critical": "#B42318", "high": "#DC6803", "medium": "#F79009", "low": "#067647"}
    fig = px.bar(
        frame,
        x="count",
        y="display_label",
        orientation="h",
        color="severity",
        color_discrete_map=severity_colors,
        labels={"count": "Flagged frames", "display_label": "", "severity": "Severity"},
        title="Possible activity type breakdown",
    )
    return finish(fig, 300)


def safety_ai_day_type(frame: pd.DataFrame) -> go.Figure:
    fig = px.bar(
        frame,
        x="day_type",
        y=["flagged", "normal"],
        barmode="group",
        labels={"value": "Frames", "day_type": "", "variable": ""},
        title="Weekday vs weekend activity",
        color_discrete_map={"flagged": "#B42318", "normal": "#067647"},
    )
    return finish(fig, 260)


def latest_domain_bar(frame: pd.DataFrame, title: str) -> go.Figure:
    data = metadata.add_display_columns(frame)
    if {"sensor_name", "metric_name"}.issubset(data.columns):
        data["label"] = data["sensor_name"] + " · " + data["metric_name"]
    else:
        data["label"] = data.get("metric", "")
    fig = px.bar(
        data.sort_values("value", ascending=True).tail(12),
        x="value",
        y="label",
        orientation="h",
        color="metric_name",
        labels={"value": "Latest value", "label": ""},
        title=title,
    )
    return finish(fig, 360)


def mobility_utilization(frame: pd.DataFrame) -> go.Figure:
    data = metadata.add_display_columns(frame)
    if data.empty:
        return go.Figure()
    pivot = data.pivot_table(
        index=["sensor_name"],
        columns="metric",
        values="value",
        aggfunc="max",
    ).reset_index()
    if "station_capacity" in pivot.columns and "bike_available_count" in pivot.columns:
        pivot["Bike availability %"] = (
            100 * pivot["bike_available_count"] / pivot["station_capacity"].replace(0, pd.NA)
        ).fillna(0)
    else:
        pivot["Bike availability %"] = 0
    fig = px.bar(
        pivot.sort_values("Bike availability %", ascending=True).tail(15),
        x="Bike availability %",
        y="sensor_name",
        orientation="h",
        range_x=[0, 100],
        labels={"sensor_name": ""},
        title="Bike availability by station",
    )
    return finish(fig, 350)


def map_points(frame: pd.DataFrame) -> go.Figure:
    data = metadata.add_display_columns(frame.dropna(subset=["latitude", "longitude"]))
    if data.empty:
        return go.Figure()
    data["size"] = data["readings"].clip(lower=6, upper=42)
    fig = px.scatter_mapbox(
        data,
        lat="latitude",
        lon="longitude",
        color="source",
        size="size",
        color_discrete_map=metadata.SOURCE_COLORS,
        hover_name="sensor_name",
        hover_data={
            "source": False,
            "source_name": True,
            "metrics": True,
            "readings": True,
            "latitude": ":.4f",
            "longitude": ":.4f",
            "size": False,
        },
        zoom=10,
        height=420,
    )
    fig.update_layout(mapbox_style="open-street-map", margin=dict(l=0, r=0, t=0, b=0))
    fig.update_layout(font=dict(color=PLOT_TEXT), legend=dict(font=dict(color=PLOT_TEXT)))
    return fig
