import { bar, colors, depthPanel, kicker, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide05(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "05 / 18" });
  kicker(ctx, slide, "Live Data Ingestion");
  title(ctx, slide, "Multiple real city domains feed one normalized reading model.", 82, 980);
  subtitle(ctx, slide, "The platform supports deterministic local review and live-source proof when network/API access is available.", 174, 920);
  depthPanel(ctx, slide, 72, 292, 700, 300, { fill: "#111D31" });
  bar(ctx, slide, 112, 334, 600, "Air quality - OpenAQ", "API-key gated", 0.82, colors.green);
  bar(ctx, slide, 112, 386, 600, "Weather - Open-Meteo", "network live", 0.75, colors.cyan);
  bar(ctx, slide, 112, 438, 600, "Mobility - Divvy GBFS", "station live", 0.90, colors.gold);
  bar(ctx, slide, 112, 490, 600, "Water - USGS", "river gage", 0.64, colors.coral);
  bar(ctx, slide, 112, 542, 600, "Simulator", "deterministic local", 1.00, colors.white);
  depthPanel(ctx, slide, 842, 322, 280, 220, { fill: "#101A2B" });
  paragraph(ctx, slide, 876, 356, "Reviewer promise:\nNo fake Grafana rows.\nNo synthetic cloud metrics.\nLive sources degrade gracefully.", { width: 220, height: 128, size: 20, color: colors.white });
  return slide;
}
