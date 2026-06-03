from __future__ import annotations

import os
import sys
from pathlib import Path
from unittest import TestCase, mock

from streamlit.testing.v1 import AppTest


ROOT = Path(__file__).resolve().parents[3]
STREAMLIT_ROOT = ROOT / "apps" / "streamlit"
APP_PATH = ROOT / "apps" / "streamlit" / "app.py"
STYLE_PATH = ROOT / "apps" / "streamlit" / "smartcity" / "styles.py"
CHARTS_PATH = ROOT / "apps" / "streamlit" / "smartcity" / "charts.py"
APP_SOURCE = APP_PATH.read_text(encoding="utf-8")
STYLE_SOURCE = STYLE_PATH.read_text(encoding="utf-8")
CHARTS_SOURCE = CHARTS_PATH.read_text(encoding="utf-8")

if str(STREAMLIT_ROOT) not in sys.path:
    sys.path.insert(0, str(STREAMLIT_ROOT))


class StreamlitLoginTests(TestCase):
    def setUp(self) -> None:
        self.env_patch = mock.patch.dict(
            os.environ,
            {
                "PUBLIC_DEMO_ENABLED": "true",
                "STREAMLIT_DEMO_PASSWORD": "qa-demo-password",
                "STREAMLIT_REFRESH_SECONDS": "0",
                "PYTHONPATH": str(STREAMLIT_ROOT),
            },
            clear=False,
        )
        self.env_patch.start()

    def tearDown(self) -> None:
        self.env_patch.stop()

    def run_demo_app(self, password: str = "qa-demo-password") -> AppTest:
        os.environ.update({
            "PUBLIC_DEMO_ENABLED": "true",
            "STREAMLIT_DEMO_PASSWORD": password,
            "STREAMLIT_REFRESH_SECONDS": "0",
            "PYTHONPATH": str(STREAMLIT_ROOT),
        })
        return AppTest.from_file(str(APP_PATH), default_timeout=10).run()

    def test_login_page_renders_in_demo_mode(self) -> None:
        app = self.run_demo_app()

        markdown = "\n".join(str(item.value) for item in app.markdown)
        self.assertIn("Access the command center", markdown)
        self.assertEqual(app.text_input[0].label, "Demo password")
        self.assertEqual(app.button[0].label, "Sign in")

    def test_wrong_password_shows_single_error(self) -> None:
        app = self.run_demo_app()
        app.text_input[0].input("wrong-password").run()
        app.button[0].click().run()

        errors = [str(item.value) for item in app.error]
        self.assertEqual(errors.count("That password did not match. Please check capitalization and try again."), 1)

    def test_correct_password_clears_stale_error(self) -> None:
        app = self.run_demo_app()
        app.text_input[0].input("wrong-password").run()
        app.button[0].click().run()
        self.assertTrue(app.error)

        app.text_input[0].input("qa-demo-password").run()
        app.button[0].click().run()

        errors = "\n".join(str(item.value) for item in app.error)
        self.assertNotIn("That password did not match", errors)


class StreamlitUiSourceTests(TestCase):
    def test_sidebar_title_is_control_center(self) -> None:
        self.assertIn('st.sidebar.title("Control Center")', APP_SOURCE)
        self.assertNotIn('st.sidebar.title("Command Center")', APP_SOURCE)

    def test_login_uses_callback_state_handlers(self) -> None:
        self.assertIn("def clear_demo_password_error()", APP_SOURCE)
        self.assertIn("def submit_demo_password(expected_password: str)", APP_SOURCE)
        self.assertIn("on_change=clear_demo_password_error", APP_SOURCE)
        self.assertIn("on_click=submit_demo_password", APP_SOURCE)
        self.assertNotIn("demo_password_invalid\"] = True\n        if st.session_state.get", APP_SOURCE)

    def test_core_widget_contrast_selectors_exist(self) -> None:
        required_selectors = [
            '[data-testid="stHeader"]',
            '[data-testid="stSidebar"]',
            '[data-testid="stSelectbox"] label',
            '[data-testid="stSlider"] label',
            '[data-testid="stTextInput"] label',
            '[data-testid="stButton"] button',
            '[data-testid="stDownloadButton"] button',
            '[data-testid="stTabs"] button',
            '[data-testid="stExpander"] details summary',
            '[data-baseweb="popover"]',
            ".sc-table-wrap td",
            "color-scheme: light",
            "-webkit-text-fill-color",
        ]
        missing = [selector for selector in required_selectors if selector not in STYLE_SOURCE]
        self.assertEqual(missing, [])

    def test_native_dataframes_are_not_used_for_report_tables(self) -> None:
        self.assertNotIn("st.dataframe(", APP_SOURCE)
        self.assertIn("styles.responsive_table(table", APP_SOURCE)
        self.assertIn("styles.responsive_table(details", APP_SOURCE)

    def test_plotly_text_colors_are_explicit(self) -> None:
        required_rules = [
            'PLOT_TEXT = "#182230"',
            "title=dict(font=dict(color=PLOT_TEXT",
            "tickfont=dict(color=PLOT_MUTED)",
            "legend=dict(font=dict(color=PLOT_TEXT))",
            "hoverlabel=dict",
        ]
        missing = [rule for rule in required_rules if rule not in CHARTS_SOURCE]
        self.assertEqual(missing, [])

    def test_dashboard_copy_handles_singular_and_empty_states(self) -> None:
        required_copy = [
            "plural_label(source_count, 'source group')",
            "No dropped readings reported at last check.",
            "No cloud report files are visible yet.",
            "Analytics row count is not available yet.",
            "No archived rows are visible yet.",
        ]
        missing = [copy for copy in required_copy if copy not in APP_SOURCE]
        self.assertEqual(missing, [])
        self.assertNotIn("source groups are contributing", APP_SOURCE)
        self.assertNotIn("new readings each second at last check", APP_SOURCE)
        self.assertNotIn("Cloud report files available for review.", APP_SOURCE)

    def test_login_input_alignment_styles_exist(self) -> None:
        required_rules = [
            "height: 3.05rem",
            "line-height: 1.25rem",
            "padding: .9rem .95rem",
            "input::placeholder",
            "input:-webkit-autofill",
        ]
        missing = [rule for rule in required_rules if rule not in STYLE_SOURCE]
        self.assertEqual(missing, [])
