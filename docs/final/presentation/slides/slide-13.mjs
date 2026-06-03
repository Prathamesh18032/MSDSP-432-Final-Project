import { calloutCard, colors, footerChrome, kicker, screenshotFrame, slideBase, subtitle, title } from "../common.mjs";

const STREAMLIT_SCREENSHOT = "docs/final/presentation/assets/streamlit-command-center-wide.png";

export async function slide13(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "13 / 19" });
  kicker(ctx, slide, "Streamlit Command Center");
  title(ctx, slide, "Streamlit gives executives a secure city command center.", 82, 960);
  subtitle(ctx, slide, "The live cloud app translates backend telemetry into a clear operating view for city leaders and stakeholders.", 174, 900);
  await screenshotFrame(ctx, slide, 56, 252, 760, 360, STREAMLIT_SCREENSHOT, {
    label: "Live Streamlit command center",
    accent: colors.green,
    fit: "cover",
  });
  await calloutCard(ctx, slide, 858, 268, 300, "Executive KPIs", "Readings, active sensors, freshness, source coverage, and archive state are visible immediately.", "graph", colors.cyan);
  await calloutCard(ctx, slide, 858, 388, 300, "City-domain lens", "Air quality, weather, bike-share, river, and service signals are filtered in one experience.", "city", colors.green);
  await calloutCard(ctx, slide, 858, 508, 300, "Protected access", "The public endpoint is password-gated while backend services stay private.", "lock", colors.gold);
  footerChrome(ctx, slide);
  return slide;
}
