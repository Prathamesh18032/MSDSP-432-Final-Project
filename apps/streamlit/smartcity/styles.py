from __future__ import annotations

from html import escape
from typing import Any

import streamlit as st


def inject_styles() -> None:
    st.markdown(
        """
        <style>
        :root {
            --sc-bg: #f7f8fb;
            --sc-panel: #ffffff;
            --sc-panel-soft: #f8fafc;
            --sc-border: #dce1ea;
            --sc-border-soft: #eef2f7;
            --sc-text: #101828;
            --sc-muted: #667085;
            --sc-accent: #0f766e;
            --sc-accent-2: #2563eb;
            --sc-good: #067647;
            --sc-warn: #b54708;
            --sc-bad: #b42318;
        }
        .stApp {
            background: var(--sc-bg);
            color: var(--sc-text);
            color-scheme: light;
        }
        .stApp,
        [data-testid="stMarkdownContainer"],
        [data-testid="stMarkdownContainer"] p,
        [data-testid="stMarkdownContainer"] li,
        [data-testid="stCaptionContainer"],
        [data-testid="stWidgetLabel"],
        [data-testid="stWidgetLabel"] label {
            color: var(--sc-text);
        }
        .block-container {
            padding-top: 1.4rem;
            padding-bottom: 2.5rem;
            max-width: 1440px;
        }
        h1, h2, h3 {
            letter-spacing: 0;
        }
        [data-testid="stHeader"],
        header[data-testid="stHeader"] {
            background: var(--sc-bg) !important;
            color: var(--sc-text) !important;
            border-bottom: 1px solid rgba(220, 225, 234, .72);
        }
        [data-testid="stToolbar"],
        [data-testid="stToolbar"] *,
        [data-testid="collapsedControl"],
        [data-testid="collapsedControl"] * {
            color: var(--sc-text) !important;
            -webkit-text-fill-color: var(--sc-text) !important;
        }
        [data-testid="stDecoration"] {
            background: var(--sc-accent) !important;
        }
        [data-testid="stSidebar"] {
            background: #ffffff;
            border-right: 1px solid var(--sc-border);
        }
        [data-testid="stSidebar"] [data-testid="stMarkdownContainer"],
        [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p,
        [data-testid="stSidebar"] [data-testid="stCaptionContainer"],
        [data-testid="stSidebar"] label,
        [data-testid="stSidebar"] span {
            color: var(--sc-text);
        }
        [data-testid="stSidebar"] [data-testid="stCaptionContainer"],
        [data-testid="stSidebar"] [data-testid="stMarkdownContainer"] p {
            color: var(--sc-muted);
        }
        [data-testid="stSidebar"] h1 {
            color: #182230;
            font-size: 1.32rem;
            line-height: 1.2;
            margin-bottom: .2rem;
        }
        [data-testid="stSelectbox"] label,
        [data-testid="stSlider"] label,
        [data-testid="stTextInput"] label,
        [data-testid="stDownloadButton"] button,
        [data-testid="stButton"] button,
        [data-testid="stTabs"] button,
        [role="tab"],
        [data-testid="stExpander"] details summary {
            color: var(--sc-text) !important;
            -webkit-text-fill-color: var(--sc-text) !important;
        }
        [data-baseweb="select"] > div,
        [data-baseweb="select"] input,
        [data-baseweb="popover"],
        [data-baseweb="popover"] ul,
        [data-testid="stSelectbox"] [role="button"] {
            background: #ffffff !important;
            color: var(--sc-text) !important;
            -webkit-text-fill-color: var(--sc-text) !important;
        }
        [data-baseweb="select"] span,
        [data-baseweb="popover"] li,
        [data-baseweb="popover"] [role="option"] {
            color: var(--sc-text) !important;
            -webkit-text-fill-color: var(--sc-text) !important;
        }
        [data-testid="stSlider"] [role="slider"] {
            background: var(--sc-accent) !important;
            border-color: var(--sc-accent) !important;
        }
        [data-testid="stSlider"] [data-testid="stThumbValue"] {
            color: var(--sc-text) !important;
        }
        [data-testid="stTabs"] [role="tablist"] {
            border-bottom: 1px solid var(--sc-border);
        }
        [data-testid="stTabs"] [role="tab"][aria-selected="true"] {
            color: var(--sc-accent) !important;
            border-color: var(--sc-accent) !important;
        }
        [data-testid="stAlert"] {
            color: var(--sc-text);
        }
        [data-testid="stAlert"] *,
        [data-testid="stExpander"] *,
        [data-testid="stDataFrame"] * {
            color: inherit;
        }
        [data-testid="stMetric"] {
            background: var(--sc-panel);
            border: 1px solid var(--sc-border);
            border-radius: 8px;
            padding: 1rem 1rem .8rem;
            box-shadow: 0 1px 2px rgba(16, 24, 40, .04);
        }
        [data-testid="stMetricLabel"] {
            color: var(--sc-muted);
            font-size: .78rem;
        }
        [data-testid="stMetricValue"] {
            color: var(--sc-text);
            font-size: 1.52rem;
            font-weight: 680;
        }
        .sc-header {
            display: flex;
            align-items: flex-start;
            justify-content: space-between;
            gap: 1rem;
            padding: .4rem 0 1rem;
        }
        .sc-kicker {
            color: var(--sc-accent);
            font-size: .78rem;
            font-weight: 760;
            text-transform: uppercase;
            letter-spacing: .08em;
            margin-bottom: .25rem;
        }
        .sc-title {
            font-size: 2.15rem;
            line-height: 1.08;
            margin: 0;
            font-weight: 760;
        }
        .sc-subtitle {
            color: var(--sc-muted);
            max-width: 780px;
            margin-top: .45rem;
            font-size: .98rem;
        }
        .sc-card-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(190px, 1fr));
            gap: .85rem;
            margin: .75rem 0 1rem;
        }
        .sc-insight-card {
            min-height: 118px;
            border: 1px solid var(--sc-border);
            background: var(--sc-panel);
            border-radius: 8px;
            padding: 1rem;
            box-shadow: 0 1px 2px rgba(16, 24, 40, .04);
        }
        .sc-insight-card-good {
            border-color: #abefc6;
            background: linear-gradient(180deg, #ffffff 0%, #f0fdf4 100%);
        }
        .sc-insight-card-warn {
            border-color: #fedf89;
            background: linear-gradient(180deg, #ffffff 0%, #fffbeb 100%);
        }
        .sc-insight-card-bad {
            border-color: #fecaca;
            background: linear-gradient(180deg, #ffffff 0%, #fef2f2 100%);
        }
        .sc-card-label {
            color: var(--sc-muted);
            font-size: .75rem;
            font-weight: 720;
            text-transform: uppercase;
            letter-spacing: .04em;
            margin-bottom: .45rem;
        }
        .sc-card-value {
            color: var(--sc-text);
            font-size: 1.45rem;
            line-height: 1.15;
            font-weight: 760;
            overflow-wrap: anywhere;
        }
        .sc-card-note {
            color: var(--sc-muted);
            font-size: .82rem;
            margin-top: .45rem;
            line-height: 1.38;
        }
        .sc-mini-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
            gap: .85rem;
            margin: .75rem 0 1rem;
        }
        .sc-mini-panel {
            border: 1px solid var(--sc-border);
            border-radius: 8px;
            background: #ffffff;
            padding: .95rem;
            box-shadow: 0 1px 2px rgba(16, 24, 40, .04);
        }
        .sc-mini-title {
            color: #182230;
            font-size: .96rem;
            font-weight: 740;
            margin-bottom: .28rem;
        }
        .sc-mini-note {
            color: var(--sc-muted);
            font-size: .82rem;
            line-height: 1.38;
        }
        .sc-report-panel {
            border: 1px solid var(--sc-border);
            border-radius: 8px;
            background: #ffffff;
            padding: 1rem;
            margin: .75rem 0 1rem;
            box-shadow: 0 1px 2px rgba(16, 24, 40, .04);
        }
        .sc-report-panel h3 {
            font-size: 1rem;
            line-height: 1.25;
            margin: 0 0 .6rem;
            color: #182230;
        }
        .sc-report-panel ul {
            margin: 0;
            padding-left: 1.05rem;
            color: #344054;
        }
        .sc-report-panel li {
            margin: .32rem 0;
            line-height: 1.42;
        }
        .sc-status-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(210px, 1fr));
            gap: .75rem;
            margin: .75rem 0 1rem;
        }
        .sc-status-card {
            border: 1px solid var(--sc-border);
            border-radius: 8px;
            background: #ffffff;
            padding: .85rem;
        }
        .sc-status-card strong {
            display: block;
            color: #182230;
            font-size: .92rem;
            margin-bottom: .28rem;
        }
        .sc-status-card span {
            color: var(--sc-muted);
            font-size: .82rem;
            line-height: 1.36;
        }
        .sc-table-wrap {
            width: 100%;
            border: 1px solid var(--sc-border);
            border-radius: 8px;
            background: #ffffff;
            overflow: auto;
            max-height: 520px;
            box-shadow: 0 1px 2px rgba(16, 24, 40, .04);
            scrollbar-color: #cbd5e1 #f8fafc;
        }
        .sc-table-wrap table {
            width: 100%;
            border-collapse: collapse;
            table-layout: fixed;
        }
        .sc-table-wrap th,
        .sc-table-wrap td {
            padding: .68rem .7rem;
            border-bottom: 1px solid var(--sc-border-soft);
            text-align: left;
            vertical-align: top;
            overflow-wrap: anywhere;
            white-space: normal;
            font-size: .82rem;
            line-height: 1.32;
            color: var(--sc-text);
            background: #ffffff;
        }
        .sc-table-wrap th {
            color: #475467;
            background: var(--sc-panel-soft);
            font-size: .74rem;
            font-weight: 760;
            text-transform: uppercase;
            letter-spacing: .03em;
            position: sticky;
            top: 0;
            z-index: 1;
        }
        .sc-table-wrap tr:nth-child(even) td {
            background: #fbfcfe;
        }
        .sc-table-wrap tr:last-child td {
            border-bottom: 0;
        }
        .sc-status-row {
            display: flex;
            gap: .55rem;
            flex-wrap: wrap;
            justify-content: flex-end;
            padding-top: .25rem;
        }
        .sc-pill {
            display: inline-flex;
            align-items: center;
            min-height: 2rem;
            padding: .35rem .62rem;
            border-radius: 999px;
            border: 1px solid var(--sc-border);
            background: #ffffff;
            color: #344054;
            font-size: .78rem;
            font-weight: 650;
            white-space: nowrap;
        }
        .sc-pill-good {
            border-color: #abefc6;
            background: #ecfdf3;
            color: var(--sc-good);
        }
        .sc-pill-warn {
            border-color: #fedf89;
            background: #fffaeb;
            color: var(--sc-warn);
        }
        .sc-section {
            color: #182230;
            font-size: 1.1rem;
            font-weight: 720;
            margin: 1.2rem 0 .35rem;
        }
        .sc-note {
            color: var(--sc-muted);
            font-size: .9rem;
            margin-bottom: .55rem;
        }
        .sc-panel {
            border: 1px solid var(--sc-border);
            background: var(--sc-panel);
            border-radius: 8px;
            padding: 1rem;
            box-shadow: 0 1px 2px rgba(16, 24, 40, .04);
        }
        .sc-empty {
            border: 1px dashed #cbd5e1;
            background: #ffffff;
            border-radius: 8px;
            padding: 1rem;
            color: var(--sc-muted);
            font-size: .92rem;
        }
        .sc-login {
            max-width: 460px;
            margin: 10vh auto 0;
            border: 1px solid var(--sc-border);
            background: #ffffff;
            border-radius: 8px;
            padding: 1.4rem;
            box-shadow: 0 12px 36px rgba(16, 24, 40, .08);
        }
        div[data-testid="stDataFrame"] {
            border: 1px solid var(--sc-border);
            border-radius: 8px;
            overflow: hidden;
        }
        div[data-testid="stDataFrame"] > div {
            max-width: 100%;
        }
        [data-testid="stDownloadButton"] button {
            border-radius: 8px;
            border: 1px solid var(--sc-border);
            background: #ffffff;
            color: #182230;
            font-weight: 680;
        }
        @media (max-width: 900px) {
            .block-container {
                padding-left: 1rem;
                padding-right: 1rem;
            }
            .sc-header {
                display: block;
            }
            .sc-title {
                font-size: 1.72rem;
            }
            .sc-subtitle {
                font-size: .92rem;
            }
            .sc-status-row {
                justify-content: flex-start;
                margin-top: .8rem;
            }
            .sc-pill {
                white-space: normal;
            }
        }
        @media (max-width: 620px) {
            .block-container {
                padding-top: .9rem;
                padding-left: .75rem;
                padding-right: .75rem;
            }
            [data-testid="stMetric"] {
                padding: .82rem;
            }
            [data-testid="stMetricValue"] {
                font-size: 1.2rem;
            }
            .sc-card-grid,
            .sc-mini-grid,
            .sc-status-grid {
                grid-template-columns: 1fr;
            }
            .sc-card-value {
                font-size: 1.22rem;
            }
            .sc-section {
                font-size: 1rem;
            }
            .sc-note {
                font-size: .84rem;
            }
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def inject_login_styles() -> None:
    st.markdown(
        """
        <style>
        .stApp {
            background:
                linear-gradient(90deg, rgba(3, 7, 18, .9) 0%, rgba(15, 23, 42, .76) 42%, rgba(15, 118, 110, .26) 100%),
                url("https://images.unsplash.com/photo-1449824913935-59a10b8d2000?auto=format&fit=crop&w=2200&q=85");
            background-size: cover;
            background-position: center;
            background-attachment: fixed;
        }
        [data-testid="stHeader"] {
            background: transparent;
        }
        [data-testid="stToolbar"] {
            display: none;
        }
        .block-container {
            max-width: 1180px;
            padding-top: 5.5rem;
            padding-bottom: 3rem;
        }
        .sc-login-copy {
            color: #ffffff;
            text-shadow: 0 2px 18px rgba(0, 0, 0, .3);
            padding-top: 2rem;
        }
        .sc-login-logo {
            display: inline-flex;
            align-items: center;
            gap: .55rem;
            padding: .44rem .72rem;
            border-radius: 999px;
            background: rgba(255, 255, 255, .12);
            border: 1px solid rgba(255, 255, 255, .22);
            color: #d1fae5;
            font-size: .78rem;
            font-weight: 780;
            text-transform: uppercase;
            letter-spacing: .08em;
            backdrop-filter: blur(14px);
        }
        .sc-login-copy h1 {
            color: #ffffff;
            font-size: 3.35rem;
            line-height: 1;
            margin: 1.35rem 0 1rem;
            max-width: 680px;
            font-weight: 780;
        }
        .sc-login-copy p {
            color: rgba(255, 255, 255, .82);
            font-size: 1.05rem;
            line-height: 1.65;
            max-width: 640px;
            margin: 0;
        }
        .sc-login-signals {
            display: flex;
            flex-wrap: wrap;
            gap: .65rem;
            margin-top: 1.4rem;
        }
        .sc-login-signal {
            padding: .58rem .78rem;
            border-radius: 999px;
            background: rgba(255, 255, 255, .12);
            border: 1px solid rgba(255, 255, 255, .2);
            color: rgba(255, 255, 255, .9);
            font-size: .84rem;
            font-weight: 650;
            backdrop-filter: blur(12px);
        }
        .sc-login-card {
            padding: 1.45rem 1.35rem .85rem;
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, .24);
            background: rgba(15, 23, 42, .72);
            box-shadow: 0 28px 80px rgba(0, 0, 0, .38);
            backdrop-filter: blur(22px);
        }
        .sc-login-card-intro {
            padding: 1.35rem 1.35rem .15rem;
            border-radius: 8px 8px 0 0;
            border: 1px solid rgba(255, 255, 255, .24);
            border-bottom: 0;
            background: rgba(15, 23, 42, .76);
            box-shadow: 0 28px 80px rgba(0, 0, 0, .32);
            backdrop-filter: blur(22px);
        }
        .sc-login-card h2 {
            color: #ffffff;
            font-size: 1.42rem;
            line-height: 1.2;
            margin: 0 0 .45rem;
            font-weight: 740;
        }
        .sc-login-card-intro h2 {
            color: #ffffff;
            font-size: 1.42rem;
            line-height: 1.2;
            margin: 0 0 .45rem;
            font-weight: 740;
        }
        .sc-login-card p {
            color: rgba(255, 255, 255, .72);
            font-size: .93rem;
            line-height: 1.5;
            margin: 0 0 1rem;
        }
        .sc-login-card-intro p {
            color: rgba(255, 255, 255, .72);
            font-size: .93rem;
            line-height: 1.5;
            margin: 0 0 1rem;
        }
        .sc-login-card-note {
            color: rgba(255, 255, 255, .58);
            font-size: .78rem;
            line-height: 1.45;
            margin-top: .9rem;
        }
        [data-testid="stTextInput"],
        [data-testid="stButton"] {
            border-left: 1px solid rgba(255, 255, 255, .24);
            border-right: 1px solid rgba(255, 255, 255, .24);
            background: rgba(15, 23, 42, .76);
            backdrop-filter: blur(22px);
            padding-left: 1.35rem;
            padding-right: 1.35rem;
        }
        [data-testid="stTextInput"] {
            padding-top: .15rem;
            padding-bottom: .75rem;
        }
        [data-testid="stButton"] {
            border-bottom: 1px solid rgba(255, 255, 255, .24);
            border-radius: 0 0 8px 8px;
            padding-bottom: 1.35rem;
            box-shadow: 0 28px 80px rgba(0, 0, 0, .32);
        }
        [data-testid="stButton"] + [data-testid="stAlert"],
        [data-testid="stButton"] + div [data-testid="stAlert"] {
            margin-top: .75rem;
        }
        [data-testid="stForm"] {
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, .24);
            padding: 1.35rem;
            background: rgba(15, 23, 42, .76);
            box-shadow: 0 28px 80px rgba(0, 0, 0, .32);
            backdrop-filter: blur(22px);
        }
        [data-testid="stTextInput"] label {
            color: rgba(255, 255, 255, .8);
        }
        [data-testid="stTextInput"] input {
            height: 3.05rem;
            min-height: 3.05rem;
            line-height: 1.25rem;
            padding: .9rem .95rem;
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, .72);
            background: #ffffff !important;
            color: #0f172a !important;
            -webkit-text-fill-color: #0f172a !important;
            caret-color: #0f766e;
            box-shadow: inset 0 1px 0 rgba(15, 23, 42, .08);
        }
        [data-testid="stTextInput"] input::placeholder {
            color: #64748b !important;
            -webkit-text-fill-color: #64748b !important;
            opacity: 1;
        }
        [data-testid="stTextInput"] input:-webkit-autofill,
        [data-testid="stTextInput"] input:-webkit-autofill:hover,
        [data-testid="stTextInput"] input:-webkit-autofill:focus {
            -webkit-box-shadow: 0 0 0 1000px #ffffff inset !important;
            -webkit-text-fill-color: #0f172a !important;
        }
        [data-testid="stTextInput"] input:focus {
            border-color: rgba(94, 234, 212, .9);
            box-shadow: 0 0 0 3px rgba(45, 212, 191, .18);
        }
        [data-testid="InputInstructions"] {
            display: none;
        }
        [data-testid="stFormSubmitButton"] button,
        [data-testid="stButton"] button {
            min-height: 3.05rem;
            border-radius: 8px;
            border: 0;
            background: #ffffff;
            color: #0f172a !important;
            -webkit-text-fill-color: #0f172a !important;
            font-weight: 760;
            box-shadow: 0 14px 30px rgba(0, 0, 0, .22);
        }
        [data-testid="stFormSubmitButton"] button:hover,
        [data-testid="stButton"] button:hover {
            background: #ccfbf1;
            color: #042f2e !important;
            -webkit-text-fill-color: #042f2e !important;
        }
        [data-testid="stAlert"] {
            border-radius: 8px;
        }
        @media (max-width: 860px) {
            .block-container {
                padding-top: 2rem;
                padding-left: 1rem;
                padding-right: 1rem;
            }
            .sc-login-copy h1 {
                font-size: 2.2rem;
            }
            .sc-login-copy {
                padding-top: 0;
            }
            .sc-login-signals {
                display: none;
            }
            .sc-login-card-intro,
            [data-testid="stForm"],
            [data-testid="stTextInput"],
            [data-testid="stButton"] {
                background: rgba(15, 23, 42, .86);
            }
        }
        @media (max-width: 560px) {
            .sc-login-copy h1 {
                font-size: 1.85rem;
            }
            .sc-login-copy p {
                font-size: .94rem;
            }
            .sc-login-card-intro,
            [data-testid="stForm"],
            [data-testid="stTextInput"],
            [data-testid="stButton"] {
                padding-left: 1rem;
                padding-right: 1rem;
            }
        }
        </style>
        """,
        unsafe_allow_html=True,
    )


def section(title: str, note: str | None = None) -> None:
    st.markdown(f'<div class="sc-section">{title}</div>', unsafe_allow_html=True)
    if note:
        st.markdown(f'<div class="sc-note">{note}</div>', unsafe_allow_html=True)


def empty_state(message: str) -> None:
    st.markdown(f'<div class="sc-empty">{message}</div>', unsafe_allow_html=True)


def status_pill(label: str, tone: str = "neutral") -> str:
    cls = "sc-pill"
    if tone == "good":
        cls += " sc-pill-good"
    elif tone == "warn":
        cls += " sc-pill-warn"
    return f'<span class="{cls}">{label}</span>'


def card_grid(cards: list[dict[str, Any]]) -> None:
    html = ['<div class="sc-card-grid">']
    for card in cards:
        tone = str(card.get("tone", "neutral"))
        cls = "sc-insight-card"
        if tone in {"good", "warn", "bad"}:
            cls += f" sc-insight-card-{tone}"
        html.append(
            f'<div class="{cls}">'
            f'<div class="sc-card-label">{escape(str(card.get("label", "")))}</div>'
            f'<div class="sc-card-value">{escape(str(card.get("value", "")))}</div>'
            f'<div class="sc-card-note">{escape(str(card.get("note", "")))}</div>'
            "</div>"
        )
    html.append("</div>")
    st.markdown("".join(html), unsafe_allow_html=True)


def mini_panels(panels: list[dict[str, Any]]) -> None:
    html = ['<div class="sc-mini-grid">']
    for panel in panels:
        html.append(
            '<div class="sc-mini-panel">'
            f'<div class="sc-mini-title">{escape(str(panel.get("title", "")))}</div>'
            f'<div class="sc-mini-note">{escape(str(panel.get("note", "")))}</div>'
            "</div>"
        )
    html.append("</div>")
    st.markdown("".join(html), unsafe_allow_html=True)


def report_panel(title: str, bullets: list[str]) -> None:
    items = "".join(f"<li>{escape(str(bullet))}</li>" for bullet in bullets if bullet)
    st.markdown(
        f'<div class="sc-report-panel"><h3>{escape(title)}</h3><ul>{items}</ul></div>',
        unsafe_allow_html=True,
    )


def responsive_table(frame: Any, max_rows: int = 18) -> None:
    if getattr(frame, "empty", True):
        return
    rows = frame.head(max_rows).to_dict(orient="records")
    headers = [str(column) for column in frame.columns]
    html = ['<div class="sc-table-wrap"><table><thead><tr>']
    html.extend(f"<th>{escape(header)}</th>" for header in headers)
    html.append("</tr></thead><tbody>")
    for row in rows:
        html.append("<tr>")
        html.extend(f"<td>{escape(str(row.get(header, '')))}</td>" for header in headers)
        html.append("</tr>")
    html.append("</tbody></table></div>")
    st.markdown("".join(html), unsafe_allow_html=True)
