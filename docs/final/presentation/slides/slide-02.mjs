import { capabilityCard, colors, footerChrome, kicker, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const BIKE_SHARE_IMAGE = "docs/final/presentation/assets/bike-share-cc0.jpg";

export async function slide02(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "02 / 19" });
  kicker(ctx, slide, "Executive Story");
  title(ctx, slide, "A production platform connects city telemetry to operational decisions.", 82, 760);
  subtitle(ctx, slide, "The product story is simple: ingest trusted signals, keep current state fast, retain history, operate reliably, and surface decisions securely.", 192, 750);
  await photoFrame(ctx, slide, 874, 104, 260, 126, BIKE_SHARE_IMAGE, {
    label: "Mobility signal layer",
    accent: colors.gold,
    overlay: "#07111FA0",
    name: "motion-photo-story-mobility",
  });
  await capabilityCard(ctx, slide, 72, 290, 245, "Ingest", "Go services poll simulator, air, weather, mobility, and water sources.", "signal", colors.cyan);
  await capabilityCard(ctx, slide, 350, 290, 245, "Store", "TimescaleDB handles hot data; Parquet, GCS, and BigQuery support historical analytics.", "database", colors.green);
  await capabilityCard(ctx, slide, 628, 290, 245, "Operate", "GKE, automated promotion, backups, restore checks, and cost modes support runtime control.", "cloud", colors.gold);
  await capabilityCard(ctx, slide, 906, 290, 245, "Report", "Streamlit and Grafana create complementary executive and operations surfaces.", "reports", colors.coral);
  await capabilityCard(ctx, slide, 210, 480, 360, "Protected delivery", "Secrets stay out of the package, public access is gated, and backend services remain private.", "lock", colors.cyan, { height: 122 });
  await capabilityCard(ctx, slide, 650, 480, 360, "Expansion-ready", "AI Agents can sit above the implemented telemetry, alerting, and analytics layer.", "bot", colors.green, { height: 122 });
  footerChrome(ctx, slide);
  return slide;
}
