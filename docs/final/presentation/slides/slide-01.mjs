import { colors, depthPanel, iconBadge, kicker, largeNumber, paragraph, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide01(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "01 / 18" });
  kicker(ctx, slide, "Phase 3 Implementation");
  title(ctx, slide, "Smart City Zero-Disk IoT Infrastructure", 84, 780);
  subtitle(ctx, slide, "A complete backend data engineering platform with live ingestion, hot/cold storage, cloud runtime, and reviewer-ready reporting.", 176, 790);
  await iconBadge(ctx, slide, 1098, 80, "city", { size: 76, accent: colors.cyan, fill: "#111D31" });
  depthPanel(ctx, slide, 72, 292, 420, 210, { fill: "#111D31" });
  largeNumber(ctx, slide, 104, 330, "60", "point final implementation package", colors.gold);
  largeNumber(ctx, slide, 104, 408, "18", "slide enterprise demo story", colors.cyan);
  paragraph(ctx, slide, 572, 312, "The design blueprint is now an operational system: Go ingestion, TimescaleDB, Pub/Sub, GCS, BigQuery, GKE, CI/CD, Streamlit, Grafana, backups, restore tests, and cost controls.", { width: 430, height: 160, size: 22, color: colors.white });
  await proofCard(ctx, slide, 72, 538, 260, "Backend proof", "live multi-source ingestion and durable storage paths", "backend", colors.green);
  await proofCard(ctx, slide, 362, 538, 260, "Reporting proof", "Streamlit for city story, Grafana for operations", "reports", colors.cyan);
  await proofCard(ctx, slide, 652, 538, 260, "Ops proof", "runtime health, release promotion, recovery, cost guardrails", "shield", colors.gold);
  return slide;
}
