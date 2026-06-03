import { colors, depthPanel, divider, flowArrow, footerChrome, kicker, label, paragraph, photoFrame, slideBase, title } from "../common.mjs";

const SMART_CITY_EXPO_IMAGE = "docs/final/presentation/assets/smart-city-expo-cc-by-sa.jpg";

export async function slide03(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "03 / 19" });
  kicker(ctx, slide, "Platform Maturity");
  title(ctx, slide, "The blueprint matured into a cloud-operated product.", 82, 760);
  await photoFrame(ctx, slide, 884, 104, 252, 126, SMART_CITY_EXPO_IMAGE, {
    label: "Smart-city operating model",
    accent: colors.green,
    overlay: "#07111F7A",
    name: "motion-photo-platform-maturity",
  });
  divider(ctx, slide, 236);
  const nodes = [
    ["Blueprint", "Target architecture, city domains, and data lifecycle boundaries", colors.gold],
    ["Implemented Runtime", "Compose, simulator, live pollers, TimescaleDB, and Grafana", colors.cyan],
    ["Cloud Operations", "GCP resources, Pub/Sub, GCS, BigQuery, GKE, and backups", colors.green],
    ["Product Surfaces", "Streamlit command center, Grafana operations, and runbooks", colors.coral],
  ];
  nodes.forEach((n, i) => {
    const x = 70 + i * 282;
    depthPanel(ctx, slide, x, 316, 218, 164, { fill: "#111D31" });
    label(ctx, slide, x + 22, 344, n[0], { width: 170, size: 22, bold: true, color: n[2] });
    paragraph(ctx, slide, x + 22, 392, n[1], { width: 170, height: 58, size: 15, color: colors.white });
    if (i < nodes.length - 1) flowArrow(ctx, slide, x + 232, 388, 38, n[2]);
  });
  paragraph(ctx, slide, 164, 550, "The result is a coherent enterprise platform: live pipelines, protected dashboards, reliable promotion, recoverable storage, and a credible path to expansion.", { width: 850, height: 54, size: 20, color: colors.white });
  footerChrome(ctx, slide);
  return slide;
}
