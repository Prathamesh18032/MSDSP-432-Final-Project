import { bar, colors, depthPanel, footerChrome, kicker, paragraph, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const WEATHER_IMAGE = "docs/final/presentation/assets/weather-station-public-domain.jpg";

export async function slide05(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "05 / 19" });
  kicker(ctx, slide, "Live Data Ingestion");
  title(ctx, slide, "Multiple real city domains feed one normalized reading model.", 82, 980);
  subtitle(ctx, slide, "Live APIs and repeatable simulation share a single validation path, so operations stay consistent when sources vary.", 174, 920);
  depthPanel(ctx, slide, 72, 292, 700, 300, { fill: "#111D31" });
  bar(ctx, slide, 112, 334, 600, "Air quality - OpenAQ", "API-key gated", 0.82, colors.green);
  bar(ctx, slide, 112, 386, 600, "Weather - Open-Meteo", "network live", 0.75, colors.cyan);
  bar(ctx, slide, 112, 438, 600, "Mobility - Divvy GBFS", "station live", 0.90, colors.gold);
  bar(ctx, slide, 112, 490, 600, "Water - USGS", "river gage", 0.64, colors.coral);
  bar(ctx, slide, 112, 542, 600, "Simulator", "repeatable validation", 1.00, colors.white);
  await photoFrame(ctx, slide, 842, 300, 280, 142, WEATHER_IMAGE, {
    label: "Weather signal capture",
    accent: colors.green,
    overlay: "#07111F66",
    name: "motion-photo-ingestion-weather",
  });
  depthPanel(ctx, slide, 842, 474, 280, 108, { fill: "#101A2B" });
  paragraph(ctx, slide, 876, 498, "Validated readings,\nsource-aware freshness,\nand graceful degradation\nwhen an external API is unavailable.", { width: 220, height: 66, size: 15.8, color: colors.white });
  footerChrome(ctx, slide);
  return slide;
}
