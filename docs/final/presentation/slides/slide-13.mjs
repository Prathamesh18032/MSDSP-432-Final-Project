import { colors, depthPanel, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide13(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "13 / 18" });
  kicker(ctx, slide, "Streamlit Reporting");
  title(ctx, slide, "Streamlit is the polished public command center.", 82, 960);
  subtitle(ctx, slide, "It turns backend data into a product-like review experience for city operations and historical evidence.", 174, 910);
  depthPanel(ctx, slide, 92, 294, 448, 270, { fill: "#101A2B" });
  label(ctx, slide, 126, 328, "Reviewer-facing views", { width: 350, size: 24, bold: true, color: colors.cyan });
  paragraph(ctx, slide, 126, 382, "- Executive KPIs\n- Air, weather, water, mobility reporting\n- Source health and coverage\n- Sensor map and latest readings\n- Historical archive evidence", { width: 350, height: 140, size: 19, color: colors.white });
  depthPanel(ctx, slide, 632, 294, 390, 270, { fill: "#14263C" });
  label(ctx, slide, 668, 328, "Demo commands", { width: 300, size: 24, bold: true, color: colors.green });
  paragraph(ctx, slide, 668, 382, "make run-streamlit\n\nor guarded public demo:\nALLOW_PUBLIC_INGRESS=yes make public-demo-apply\nmake public-demo-url", { width: 300, height: 140, size: 18, color: colors.white });
  return slide;
}
