import { capabilityCard, colors, footerChrome, kicker, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const OPERATIONS_CENTER_IMAGE = "docs/final/presentation/assets/bart-operations-control-public-domain.jpg";

export async function slide17(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "17 / 19" });
  kicker(ctx, slide, "Delivered Product Output");
  title(ctx, slide, "The output is an operated smart-city data product.", 82, 960);
  subtitle(ctx, slide, "The product turns public civic signals into governed operations: capture, validate, store, observe, recover, and control cost without exposing raw systems.", 202, 940);
  await photoFrame(ctx, slide, 58, 276, 500, 266, OPERATIONS_CENTER_IMAGE, {
    label: "Operator-grade city operations context",
    accent: colors.cyan,
    overlay: "#07111F8A",
    labelSize: 11,
    name: "motion-output-operations-center",
  });
  await capabilityCard(ctx, slide, 612, 276, 234, "Live signal capture", "Air quality, weather, mobility, water, and simulator feeds normalize into one model.", "signal", colors.cyan, { height: 126, titleSize: 15, bodySize: 11.2 });
  await capabilityCard(ctx, slide, 878, 276, 234, "Decision surfaces", "Streamlit and Grafana separate executive command from live operational observability.", "monitor", colors.green, { height: 126, titleSize: 15, bodySize: 11.2 });
  await capabilityCard(ctx, slide, 612, 432, 234, "Zero-disk history", "Historical analytics move to Parquet, GCS, and BigQuery instead of laptop or local disk dependence.", "storage", colors.gold, { height: 126, titleSize: 15, bodySize: 11.2 });
  await capabilityCard(ctx, slide, 878, 432, 234, "Cloud operations", "GKE runtime, CI/CD promotion, backup/restore, and cost modes make the system operable.", "cloud", colors.coral, { height: 126, titleSize: 15, bodySize: 11.2 });
  footerChrome(ctx, slide);
  return slide;
}
