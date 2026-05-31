import { colors, depthPanel, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide07(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "07 / 18" });
  kicker(ctx, slide, "Hot Store");
  title(ctx, slide, "TimescaleDB is the operational store for current city state.", 82, 960);
  subtitle(ctx, slide, "It holds readings and ingestion metrics that power both local dashboards and runtime validation.", 174, 900);
  depthPanel(ctx, slide, 90, 296, 460, 270, { fill: "#101A2B" });
  label(ctx, slide, 126, 332, "Hot data responsibilities", { width: 360, size: 24, bold: true, color: colors.cyan });
  paragraph(ctx, slide, 126, 390, "- sensor_readings for city telemetry\n- ingestion_metrics for platform operations\n- row checks for source coverage\n- tables powering Streamlit and Grafana", { width: 360, height: 116, size: 19, color: colors.white });
  depthPanel(ctx, slide, 652, 296, 360, 270, { fill: "#14263C" });
  label(ctx, slide, 690, 332, "Reviewer commands", { width: 280, size: 24, bold: true, color: colors.green });
  paragraph(ctx, slide, 690, 390, "make run-local\nmake seed-simulator\nmake poll-multisource-once\nmake grafana-demo-ready", { width: 270, height: 116, size: 21, color: colors.white });
  return slide;
}
