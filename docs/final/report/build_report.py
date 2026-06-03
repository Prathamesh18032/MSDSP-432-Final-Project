#!/usr/bin/env python3
"""Render the Phase 3 final report to PDF.

Renders the full-bleed cover (no footer) and the numbered body separately with
headless Chrome (via Playwright, using the installed Google Chrome channel), then
merges them with pypdf into the final deliverable.
"""
import pathlib
import sys
from playwright.sync_api import sync_playwright
from pypdf import PdfReader, PdfWriter

HERE = pathlib.Path(__file__).resolve().parent
COVER = HERE / "cover.html"
BODY = HERE / "report.html"
OUT_DIR = HERE.parent  # docs/final
FINAL = OUT_DIR / "Project_Phase_3_Group4_Report_Final.pdf"
TMP_COVER = HERE / ".cover.pdf"
TMP_BODY = HERE / ".body.pdf"

FOOTER = (
    '<div style="width:100%;font-size:7.5px;color:#9AA3B2;'
    'font-family:Helvetica,Arial,sans-serif;padding:0 15mm;'
    'display:flex;justify-content:space-between;align-items:center;">'
    '<span>MSDS 432 · Group 4 · Smart City Zero-Disk IoT Infrastructure</span>'
    '<span>Phase 3 Final Report &nbsp;·&nbsp; '
    '<span class="pageNumber"></span> / <span class="totalPages"></span></span>'
    "</div>"
)
EMPTY = '<div></div>'


def render():
    with sync_playwright() as p:
        try:
            browser = p.chromium.launch(channel="chrome")
        except Exception:
            browser = p.chromium.launch()  # fall back to bundled chromium
        page = browser.new_page()

        # Cover: full-bleed, no footer.
        page.goto(COVER.as_uri(), wait_until="networkidle")
        page.pdf(
            path=str(TMP_COVER),
            prefer_css_page_size=True,
            print_background=True,
            margin={"top": "0", "bottom": "0", "left": "0", "right": "0"},
        )

        # Body: A4, top/bottom margins for breathing room + footer page numbers.
        page.goto(BODY.as_uri(), wait_until="networkidle")
        page.pdf(
            path=str(TMP_BODY),
            format="A4",
            print_background=True,
            display_header_footer=True,
            header_template=EMPTY,
            footer_template=FOOTER,
            margin={"top": "15mm", "bottom": "16mm", "left": "0", "right": "0"},
        )
        browser.close()


def merge():
    writer = PdfWriter()
    for src in (TMP_COVER, TMP_BODY):
        for pg in PdfReader(str(src)).pages:
            writer.add_page(pg)
    with open(FINAL, "wb") as fh:
        writer.write(fh)
    TMP_COVER.unlink(missing_ok=True)
    TMP_BODY.unlink(missing_ok=True)


if __name__ == "__main__":
    render()
    merge()
    pages = len(PdfReader(str(FINAL)).pages)
    size_kb = FINAL.stat().st_size / 1024
    print(f"OK  {FINAL}  ({pages} pages, {size_kb:.0f} KB)")
