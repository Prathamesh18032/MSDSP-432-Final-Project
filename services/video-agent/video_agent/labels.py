from __future__ import annotations


SUSPICIOUS_LABELS = {
    "abuse",
    "arrest",
    "arson",
    "assault",
    "burglary",
    "explosion",
    "fighting",
    "road accident",
    "roadaccidents",
    "robbery",
    "shooting",
    "shoplifting",
    "stealing",
    "vandalism",
}

DISPLAY_LABELS = {
    "abuse": "abuse_like_activity",
    "arrest": "arrest_like_activity",
    "arson": "arson_like_activity",
    "assault": "assault_like_activity",
    "burglary": "burglary_like_activity",
    "explosion": "explosion_like_activity",
    "fighting": "fighting",
    "normal videos": "normal",
    "normalvideos": "normal",
    "normal": "normal",
    "road accident": "road_accident_like_activity",
    "roadaccidents": "road_accident_like_activity",
    "robbery": "robbery_like_activity",
    "shooting": "shooting_like_activity",
    "shoplifting": "shoplifting_like_activity",
    "stealing": "stealing_like_activity",
    "vandalism": "vandalism_like_activity",
}

SEVERITY = {
    "abuse": "high",
    "arrest": "medium",
    "arson": "critical",
    "assault": "high",
    "burglary": "high",
    "explosion": "critical",
    "fighting": "high",
    "road accident": "critical",
    "roadaccidents": "critical",
    "robbery": "critical",
    "shooting": "critical",
    "shoplifting": "medium",
    "stealing": "medium",
    "vandalism": "medium",
}


def normalize_label(label: str) -> str:
    normalized = str(label or "").strip().lower().replace("_", " ").replace("-", " ")
    if normalized in {"roadaccidents", "road accidents", "road accident"}:
        return "road accident"
    if normalized in {"theft", "steal", "stealing"}:
        return "stealing"
    return normalized


def display_label(label: str) -> str:
    normalized = normalize_label(label)
    return DISPLAY_LABELS.get(normalized, normalized.replace(" ", "_") or "unknown")


def severity(label: str) -> str:
    return SEVERITY.get(normalize_label(label), "low")


def is_suspicious(label: str) -> bool:
    return normalize_label(label) in SUSPICIOUS_LABELS
