import { capabilityCard, colors, depthPanel, footerChrome, kicker, largeNumber, paragraph, photoFrame, pill, slideBase, subtitle, title } from "../common.mjs";

const SKYLINE_IMAGE = "docs/final/presentation/assets/chicago-skyline-public-domain.jpg";

export async function slide01(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "01 / 19" });
  kicker(ctx, slide, "Enterprise Platform");
  title(ctx, slide, "Smart City Zero-Disk IoT Infrastructure", 84, 780);
  subtitle(ctx, slide, "A production-ready smart city data platform unifying live telemetry, cloud-native operations, and executive reporting.", 176, 820);
  pill(ctx, slide, 58, 246, "Group 4", colors.gold, 124);
  pill(ctx, slide, 196, 246, "MSDS 432", colors.cyan, 124);
  await photoFrame(ctx, slide, 934, 96, 262, 390, SKYLINE_IMAGE, {
    label: "City-scale operating context",
    accent: colors.cyan,
    overlay: "#07111F80",
    name: "motion-photo-title-city",
  });
  depthPanel(ctx, slide, 72, 312, 456, 184, { fill: "#111D31" });
  largeNumber(ctx, slide, 104, 344, "5", "live city signal families", colors.gold);
  largeNumber(ctx, slide, 104, 422, "2", "protected dashboard surfaces", colors.cyan);
  paragraph(ctx, slide, 594, 318, "The platform combines Go ingestion, TimescaleDB, Pub/Sub, GCS, BigQuery, GKE, automated release promotion, Streamlit, Grafana, backups, restore checks, and cost governance into one operated product.", { width: 320, height: 154, size: 20, color: colors.white });
  await capabilityCard(ctx, slide, 72, 506, 260, "Live telemetry", "Air, weather, mobility, water, and simulator signals feed a common reading model.", "signal", colors.green, { height: 116 });
  await capabilityCard(ctx, slide, 362, 506, 260, "Decision surfaces", "Streamlit supports executive reporting while Grafana covers live operations.", "reports", colors.cyan, { height: 116 });
  await capabilityCard(ctx, slide, 652, 506, 260, "Operational control", "Release automation, recovery workflows, and cost guardrails support production posture.", "shield", colors.gold, { height: 116 });
  footerChrome(ctx, slide);
  return slide;
}
