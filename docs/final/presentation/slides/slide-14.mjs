import { calloutCard, colors, footerChrome, kicker, screenshotFrame, slideBase, subtitle, title } from "../common.mjs";

const GRAFANA_SCREENSHOT = "docs/final/presentation/assets/grafana-operations-wide.png";

export async function slide14(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "14 / 19" });
  kicker(ctx, slide, "Grafana Operations");
  title(ctx, slide, "Grafana provides live operational observability for the platform.", 82, 980);
  subtitle(ctx, slide, "The cloud Grafana surface complements Streamlit with ingestion health, unit-specific charts, quality trends, and alert visibility.", 174, 960);
  await screenshotFrame(ctx, slide, 56, 248, 805, 374, GRAFANA_SCREENSHOT, {
    label: "Live Grafana operations dashboard",
    accent: colors.cyan,
    fit: "cover",
  });
  await calloutCard(ctx, slide, 898, 266, 282, "Live ingestion", "Throughput, channel fill, and dropped-readings panels make pipeline health visible.", "pulse", colors.green);
  await calloutCard(ctx, slide, 898, 386, 282, "One unit per panel", "Air, weather, water, and mobility readings are split into readable unit-specific charts.", "graph", colors.gold);
  await calloutCard(ctx, slide, 898, 506, 282, "Login protected", "Grafana has its own public ingress and remains credential-gated for the event window.", "shield", colors.coral);
  footerChrome(ctx, slide);
  return slide;
}
