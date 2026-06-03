import { capabilityCard, colors, footerChrome, kicker, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const STREAMGAGE_IMAGE = "docs/final/presentation/assets/usgs-streamgage-public-domain.jpg";

export async function slide08(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "08 / 19" });
  kicker(ctx, slide, "Cold Path");
  title(ctx, slide, "Parquet, GCS, and BigQuery convert current readings into durable history.", 82, 980);
  subtitle(ctx, slide, "The cold path supports trend analysis and executive reporting while keeping the live dashboard focused on current operations.", 174, 930);
  await photoFrame(ctx, slide, 896, 212, 236, 76, STREAMGAGE_IMAGE, {
    label: "Water signal archive",
    accent: colors.cyan,
    overlay: "#07111F82",
    labelSize: 9.6,
    name: "motion-photo-coldpath-water",
  });
  await capabilityCard(ctx, slide, 90, 322, 290, "Parquet archive", "Partitioned exports create portable historical files from TimescaleDB readings.", "storage", colors.cyan);
  await capabilityCard(ctx, slide, 430, 322, 290, "GCS durability", "Cloud object storage keeps retained readings available beyond the hot database window.", "cloud", colors.green);
  await capabilityCard(ctx, slide, 770, 322, 290, "BigQuery analytics", "External-table validation makes the archive queryable for longer-range analysis.", "graph", colors.gold);
  await capabilityCard(ctx, slide, 260, 500, 290, "Executive reporting", "The command center can show archive status alongside current city operations.", "reports", colors.coral, { height: 118 });
  await capabilityCard(ctx, slide, 600, 500, 290, "Retention-safe", "Exports preserve hot rows during validation and keep operational dashboards stable.", "shield", colors.cyan, { height: 118 });
  footerChrome(ctx, slide);
  return slide;
}
