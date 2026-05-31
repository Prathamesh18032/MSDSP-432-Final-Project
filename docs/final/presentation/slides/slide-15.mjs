import { colors, depthPanel, flowArrow, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide15(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "15 / 18" });
  kicker(ctx, slide, "Demo Script");
  title(ctx, slide, "The live review path moves from backend proof to reporting proof.", 82, 980);
  subtitle(ctx, slide, "This sequence keeps the presentation practical and avoids re-litigating Phase 2 design details.", 174, 910);
  const steps = [
    ["1", "Seed + poll", "make grafana-demo-ready", colors.cyan],
    ["2", "Show Grafana", "ingestion, geomap, quality", colors.green],
    ["3", "Show Streamlit", "executive and city views", colors.gold],
    ["4", "Show runtime", "health, release, cost, evidence", colors.coral],
  ];
  steps.forEach((s, i) => {
    const x = 80 + i * 268;
    depthPanel(ctx, slide, x, 324, 210, 156, { fill: "#111D31" });
    label(ctx, slide, x + 22, 344, s[0], { width: 52, size: 34, bold: true, color: s[3] });
    label(ctx, slide, x + 76, 354, s[1], { width: 120, size: 18, bold: true, color: colors.white });
    paragraph(ctx, slide, x + 22, 408, s[2], { width: 166, height: 42, size: 15, color: colors.white });
    if (i < steps.length - 1) flowArrow(ctx, slide, x + 218, 392, 34, s[3]);
  });
  return slide;
}
