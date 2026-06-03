import { calloutCard, colors, depthPanel, footerChrome, kicker, label, paragraph, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const HOT_STORE_IMAGE = "docs/final/presentation/assets/nersc-server-racks-cc0.jpg";

export async function slide07(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "07 / 19" });
  kicker(ctx, slide, "Hot Store");
  title(ctx, slide, "TimescaleDB turns raw telemetry into operational city state.", 82, 960);
  subtitle(ctx, slide, "The hot store supports fast current-state reads while preserving enough detail for freshness, quality, and source coverage decisions.", 198, 720);
  await photoFrame(ctx, slide, 832, 218, 256, 68, HOT_STORE_IMAGE, {
    label: "Private hot-store infrastructure",
    accent: colors.green,
    overlay: false,
    labelSize: 9.4,
    name: "motion-photo-hot-store-racks",
  });
  depthPanel(ctx, slide, 90, 292, 470, 278, { fill: "#101A2B" });
  label(ctx, slide, 126, 328, "Hot data responsibilities", { width: 360, size: 24, bold: true, color: colors.cyan });
  paragraph(ctx, slide, 126, 388, "- sensor_readings for city telemetry\n- ingestion_metrics for platform operations\n- source and metric coverage checks\n- dashboard-ready current state", { width: 360, height: 124, size: 19, color: colors.white });
  await calloutCard(ctx, slide, 638, 294, 390, "Fast operations", "Operators can read current city state without scanning cold history.", "pulse", colors.green);
  await calloutCard(ctx, slide, 638, 414, 390, "Unit-aware analytics", "Metric names, sources, and units stay explicit before panels render.", "quality", colors.gold);
  await calloutCard(ctx, slide, 638, 512, 390, "Private backend", "The database remains inside the runtime network while dashboards expose only curated views.", "lock", colors.coral);
  footerChrome(ctx, slide);
  return slide;
}
