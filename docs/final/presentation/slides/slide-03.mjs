import { colors, depthPanel, divider, flowArrow, kicker, label, paragraph, slideBase, title } from "../common.mjs";

export async function slide03(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "03 / 18" });
  kicker(ctx, slide, "Phase 2 To Phase 3");
  title(ctx, slide, "The design blueprint became a runnable, observable implementation.", 82, 1000);
  divider(ctx, slide, 236);
  const nodes = [
    ["Blueprint", "Phase 2 design report and architecture diagram", colors.gold],
    ["Local Proof", "Compose, simulator, live pollers, TimescaleDB, Grafana", colors.cyan],
    ["Cloud Proof", "GCP core resources, Pub/Sub, GCS, BigQuery, GKE", colors.green],
    ["Final Proof", "Streamlit, dashboard, deck, runbooks, package checks", colors.coral],
  ];
  nodes.forEach((n, i) => {
    const x = 70 + i * 282;
    depthPanel(ctx, slide, x, 316, 218, 164, { fill: "#111D31" });
    label(ctx, slide, x + 22, 344, n[0], { width: 170, size: 22, bold: true, color: n[2] });
    paragraph(ctx, slide, x + 22, 392, n[1], { width: 170, height: 58, size: 15, color: colors.white });
    if (i < nodes.length - 1) flowArrow(ctx, slide, x + 232, 388, 38, n[2]);
  });
  paragraph(ctx, slide, 164, 550, "Phase 3 should not repeat Phase 2. It should show implementation depth, reviewer evidence, and operational maturity.", { width: 850, height: 42, size: 21, color: colors.white });
  return slide;
}
