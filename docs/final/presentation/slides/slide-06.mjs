import { capabilityCard, colors, footerChrome, kicker, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const PM25_IMAGE = "docs/final/presentation/assets/pm25-nasa-public-domain.jpg";

export async function slide06(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "06 / 19" });
  kicker(ctx, slide, "Data Quality");
  title(ctx, slide, "Validation and quality flags protect operational decisions.", 82, 980);
  subtitle(ctx, slide, "The platform does not treat every incoming payload as trustworthy by default; it classifies quality before analytics consume it.", 174, 930);
  await photoFrame(ctx, slide, 896, 210, 236, 72, PM25_IMAGE, {
    label: "Air-quality evidence layer",
    accent: colors.gold,
    overlay: "#07111F94",
    labelSize: 9.6,
    name: "motion-photo-quality-air",
  });
  await capabilityCard(ctx, slide, 82, 316, 300, "Normalization", "Source-specific payloads become a common reading shape with metric, value, timestamp, and location.", "workflow", colors.cyan);
  await capabilityCard(ctx, slide, 430, 316, 300, "Validation", "Invalid, suspect, and valid quality flags protect analytics and dashboard interpretation.", "check", colors.green);
  await capabilityCard(ctx, slide, 778, 316, 300, "Observability", "Ingestion metrics surface throughput, freshness, channel fill, and dropped readings.", "pulse", colors.gold);
  await capabilityCard(ctx, slide, 248, 500, 300, "Coverage", "Source and metric coverage tables show what data is actually present.", "graph", colors.coral, { height: 118 });
  await capabilityCard(ctx, slide, 596, 500, 300, "Traceability", "Tables retain sensor IDs, sources, metric names, and reading freshness.", "eye", colors.cyan, { height: 118 });
  footerChrome(ctx, slide);
  return slide;
}
