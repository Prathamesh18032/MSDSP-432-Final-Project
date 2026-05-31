import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide02(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "02 / 18" });
  kicker(ctx, slide, "Executive Story");
  title(ctx, slide, "Phase 3 proves the platform works across the full data lifecycle.", 82, 950);
  subtitle(ctx, slide, "The project is positioned as an enterprise data platform: ingest, validate, store, operate, report, and recover.", 174, 900);
  await proofCard(ctx, slide, 72, 290, 245, "Ingest", "Go services poll simulator, air, weather, mobility, and water sources.", "signal", colors.cyan);
  await proofCard(ctx, slide, 350, 290, 245, "Store", "TimescaleDB handles hot data; Parquet/GCS/BigQuery handle cold analytics.", "database", colors.green);
  await proofCard(ctx, slide, 628, 290, 245, "Operate", "GKE, CI/CD, promotion checks, backups, restore tests, and cost modes.", "cloud", colors.gold);
  await proofCard(ctx, slide, 906, 290, 245, "Report", "Streamlit and Grafana create complementary reviewer surfaces.", "reports", colors.coral);
  await proofCard(ctx, slide, 210, 492, 360, "Safety-first delivery", "No secrets in package, guarded cloud mutation, protected public demo access.", "lock", colors.cyan);
  await proofCard(ctx, slide, 650, 492, 360, "Future-ready foundation", "AI Agents can sit above the implemented telemetry and analytics layer.", "bot", colors.green);
  return slide;
}
