import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide06(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "06 / 18" });
  kicker(ctx, slide, "Data Quality");
  title(ctx, slide, "Validation and quality flags make the city telemetry reviewable.", 82, 980);
  subtitle(ctx, slide, "Phase 3 evidence is stronger because the platform does not treat every incoming payload as trustworthy by default.", 174, 920);
  await proofCard(ctx, slide, 82, 304, 300, "Normalization", "Source-specific payloads become a common reading shape with metric, value, timestamp, and location.", "workflow", colors.cyan);
  await proofCard(ctx, slide, 430, 304, 300, "Validation", "Invalid, suspect, and valid quality flags protect analytics and dashboard interpretation.", "check", colors.green);
  await proofCard(ctx, slide, 778, 304, 300, "Observability", "Ingestion metrics surface throughput, freshness, channel fill, and dropped readings.", "pulse", colors.gold);
  await proofCard(ctx, slide, 248, 504, 300, "Coverage", "Source and metric coverage tables show what data is actually present.", "graph", colors.coral);
  await proofCard(ctx, slide, 596, 504, 300, "Traceability", "Tables retain sensor IDs, sources, metric names, and reading freshness.", "eye", colors.cyan);
  return slide;
}
