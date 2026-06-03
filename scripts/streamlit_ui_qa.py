#!/usr/bin/env python3
from __future__ import annotations

import os
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen

from playwright.sync_api import Page, expect, sync_playwright


ROOT = Path(__file__).resolve().parents[1]
ARTIFACT_DIR = ROOT / "artifacts" / "streamlit-ui-qa"
PASSWORD = os.getenv("STREAMLIT_DEMO_PASSWORD", "qa-demo-password")
PORT = int(os.getenv("STREAMLIT_PORT", "8501"))
BASE_URL = os.getenv("STREAMLIT_QA_URL", f"http://127.0.0.1:{PORT}")
HEALTH_URL = f"{BASE_URL}/_stcore/health"


def healthcheck() -> bool:
    try:
        with urlopen(HEALTH_URL, timeout=2) as response:
            return response.status == 200
    except (OSError, URLError):
        return False


def wait_for_streamlit(timeout_seconds: int = 45) -> None:
    deadline = time.time() + timeout_seconds
    while time.time() < deadline:
        if healthcheck():
            return
        time.sleep(1)
    raise RuntimeError(f"Streamlit did not become healthy at {HEALTH_URL}")


def start_streamlit_if_needed() -> subprocess.Popen[str] | None:
    if healthcheck():
        return None

    env = os.environ.copy()
    env.setdefault("PUBLIC_DEMO_ENABLED", "true")
    env.setdefault("STREAMLIT_DEMO_PASSWORD", PASSWORD)
    env.setdefault("STREAMLIT_REFRESH_SECONDS", "0")
    env.setdefault("STREAMLIT_THEME_BASE", "light")
    env.setdefault("STREAMLIT_THEME_BACKGROUND_COLOR", "#f7f8fb")
    env.setdefault("STREAMLIT_THEME_SECONDARY_BACKGROUND_COLOR", "#ffffff")
    env.setdefault("STREAMLIT_THEME_TEXT_COLOR", "#101828")
    env.setdefault("STREAMLIT_THEME_PRIMARY_COLOR", "#0f766e")
    env.setdefault("PYTHONPATH", str(ROOT / "apps" / "streamlit"))

    command = [
        sys.executable,
        "-m",
        "streamlit",
        "run",
        str(ROOT / "apps" / "streamlit" / "app.py"),
        "--server.port",
        str(PORT),
        "--server.headless",
        "true",
        "--browser.gatherUsageStats",
        "false",
    ]
    process = subprocess.Popen(
        command,
        cwd=str(ROOT),
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
    )
    wait_for_streamlit()
    return process


def login(page: Page) -> None:
    page.goto(BASE_URL, wait_until="networkidle")
    password_input = page.get_by_label("Demo password")
    expect(password_input).to_be_visible(timeout=15000)
    password_input.fill(PASSWORD)
    page.get_by_role("button", name="Sign in").click()
    expect(page.get_by_text("Control Center")).to_be_visible(timeout=20000)
    expect(page.get_by_text("That password did not match")).not_to_be_visible(timeout=3000)


def verify_tabs(page: Page) -> None:
    expected_content: dict[str, list[str]] = {
        "Operations": [
            "City Operations",
            "Source activity, current availability, and recent service signals.",
            "Service health",
            "No dropped readings reported at last check.",
            "Download source summary",
        ],
        "Domains": [
            "Air Quality",
            "Pollutant trends and current readings across monitored locations.",
            "Mobility",
            "Divvy station availability, dock pressure, and capacity signals.",
            "Weather & Water",
            "Download weather and river readings",
        ],
        "Sensors": [
            "Sensor Network",
            "Friendly locations, freshness, and monitored signals.",
            "Locations monitored",
            "Download sensor network",
            "Location details",
        ],
        "Quality": [
            "Data Quality",
            "Coverage and readiness indicators for trusted reporting.",
            "Readiness score",
            "Coverage by metric",
            "Download coverage summary",
        ],
        "Safety AI": [
            "Safety AI",
            "AI-flagged possible activity traces from the image inference agent.",
            "No Safety AI prediction table is available in this environment yet.",
        ],
        "Archive": [
            "Historical Archive",
            "Longer-term reporting evidence for city readings.",
            "No cold export detected",
            "No cloud report files are visible yet.",
            "Analytics row count is not available yet.",
        ],
    }
    for tab_name, expected_texts in expected_content.items():
        tab = page.get_by_role("tab", name=tab_name)
        expect(tab).to_be_visible(timeout=10000)
        tab.click()
        if tab_name == "Sensors":
            page.get_by_text("Location details", exact=True).click()
            expect(page.get_by_text("Latitude", exact=True)).to_be_visible(timeout=10000)
            expect(page.get_by_text("Longitude", exact=True)).to_be_visible(timeout=10000)
        section = page.locator(".sc-section").filter(has_text=expected_texts[0])
        expect(section).to_have_count(1, timeout=10000)
        expect(section).to_be_visible(timeout=10000)
        for expected_text in expected_texts:
            expect(page.get_by_text(expected_text, exact=False).first).to_be_visible(timeout=10000)
        verify_text_contrast(page)
        section.scroll_into_view_if_needed()
        page.screenshot(path=str(ARTIFACT_DIR / f"{tab_name.lower().replace(' ', '-')}.png"), full_page=False)


def verify_sidebar_controls(page: Page) -> None:
    for label in ["Time window", "Source", "Metric category", "Quality flag", "Auto-refresh"]:
        expect(page.get_by_text(label, exact=True)).to_be_visible(timeout=10000)


def verify_text_contrast(page: Page) -> None:
    failures = page.evaluate(
        """
        () => {
            const selectors = [
                '[data-testid="stHeader"]',
                '[data-testid="stSidebar"] [data-testid="stMarkdownContainer"]',
                '[data-testid="stSidebar"] label',
                '[role="tab"]',
                '[data-testid="stButton"] button',
                '[data-testid="stDownloadButton"] button',
                '[data-testid="stMarkdownContainer"] p',
                '.sc-title',
                '.sc-section',
                '.sc-card-value',
                '.sc-table-wrap th',
                '.sc-table-wrap td',
                '.js-plotly-plot text'
            ];

            function parseRgb(value) {
                const match = String(value).match(/rgba?\\(([^)]+)\\)/);
                if (!match) return null;
                const parts = match[1].split(',').map((part) => Number.parseFloat(part.trim()));
                return { r: parts[0], g: parts[1], b: parts[2], a: parts.length > 3 ? parts[3] : 1 };
            }

            function luminance(color) {
                const values = [color.r, color.g, color.b].map((channel) => {
                    const normalized = channel / 255;
                    return normalized <= 0.03928
                        ? normalized / 12.92
                        : Math.pow((normalized + 0.055) / 1.055, 2.4);
                });
                return 0.2126 * values[0] + 0.7152 * values[1] + 0.0722 * values[2];
            }

            function contrast(foreground, background) {
                const fg = luminance(foreground);
                const bg = luminance(background);
                return (Math.max(fg, bg) + 0.05) / (Math.min(fg, bg) + 0.05);
            }

            function effectiveBackground(element) {
                let current = element;
                while (current) {
                    const parsed = parseRgb(getComputedStyle(current).backgroundColor);
                    if (parsed && parsed.a > 0.95) return parsed;
                    current = current.parentElement;
                }
                return { r: 255, g: 255, b: 255, a: 1 };
            }

            function isVisible(element) {
                const rect = element.getBoundingClientRect();
                const style = getComputedStyle(element);
                return rect.width > 0 && rect.height > 0 && style.visibility !== 'hidden' && style.display !== 'none';
            }

            const failures = [];
            for (const selector of selectors) {
                const candidates = Array.from(document.querySelectorAll(selector))
                    .filter((element) => isVisible(element) && element.textContent.trim().length > 0)
                    .slice(0, 6);
                for (const element of candidates) {
                    const style = getComputedStyle(element);
                    const foreground = parseRgb(style.color) || parseRgb(style.fill);
                    const background = effectiveBackground(element);
                    if (!foreground) continue;
                    const ratio = contrast(foreground, background);
                    const fontSize = Number.parseFloat(getComputedStyle(element).fontSize);
                    const minRatio = fontSize >= 18 ? 3 : 4.5;
                    if (ratio < minRatio) {
                        failures.push({
                            selector,
                            text: element.textContent.trim().slice(0, 80),
                            ratio: Number(ratio.toFixed(2)),
                            minRatio
                        });
                    }
                }
            }
            return failures;
        }
        """
    )
    if failures:
        raise AssertionError(f"Contrast failures: {failures}")

    native_dataframes = page.locator('[data-testid="stDataFrame"]')
    if native_dataframes.count() != 0:
        raise AssertionError("Native Streamlit dataframe renderer is present; use app-owned responsive tables.")

    header_too_dark = page.evaluate(
        """
        () => {
            const header = document.querySelector('[data-testid="stHeader"]');
            if (!header) return false;
            const match = getComputedStyle(header).backgroundColor.match(/rgba?\\(([^)]+)\\)/);
            if (!match) return false;
            const [r, g, b] = match[1].split(',').map((part) => Number.parseFloat(part.trim()));
            return ((0.2126 * r + 0.7152 * g + 0.0722 * b) / 255) < 0.82;
        }
        """
    )
    if header_too_dark:
        raise AssertionError("Streamlit header is rendering as a dark strip in the controlled light theme.")


def main() -> int:
    ARTIFACT_DIR.mkdir(parents=True, exist_ok=True)
    process = start_streamlit_if_needed()
    try:
        with sync_playwright() as playwright:
            browser = playwright.chromium.launch()
            page = browser.new_page(viewport={"width": 1440, "height": 1100})
            login(page)
            verify_sidebar_controls(page)
            verify_tabs(page)
            verify_text_contrast(page)
            page.screenshot(path=str(ARTIFACT_DIR / "final-dashboard.png"), full_page=True)
            browser.close()
    finally:
        if process is not None:
            process.terminate()
            try:
                process.wait(timeout=8)
            except subprocess.TimeoutExpired:
                process.kill()
    print(f"Streamlit UI QA passed. Screenshots saved to {ARTIFACT_DIR}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
