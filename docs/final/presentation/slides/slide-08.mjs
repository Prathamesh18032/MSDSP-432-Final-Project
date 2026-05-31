import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide08(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "08 / 18" });
  kicker(ctx, slide, "Cold Path");
  title(ctx, slide, "Parquet, GCS, and BigQuery turn hot readings into historical evidence.", 82, 980);
  subtitle(ctx, slide, "The cold path supports longer-term reporting while keeping the live dashboard focused on current operations.", 174, 910);
  await proofCard(ctx, slide, 90, 314, 290, "Local Parquet", "make export-cold-demo writes partitioned files from TimescaleDB rows.", "storage", colors.cyan);
  await proofCard(ctx, slide, 430, 314, 290, "GCS upload", "make export-cold-gcs promotes cold files into cloud object storage.", "cloud", colors.green);
  await proofCard(ctx, slide, 770, 314, 290, "BigQuery view", "make bigquery-cold-check validates external-table visibility.", "graph", colors.gold);
  await proofCard(ctx, slide, 260, 514, 290, "Streamlit evidence", "The command center can show local/cloud cold-path proof.", "reports", colors.coral);
  await proofCard(ctx, slide, 600, 514, 290, "Retention-safe", "Exports do not delete hot TimescaleDB rows during demo validation.", "shield", colors.cyan);
  return slide;
}
