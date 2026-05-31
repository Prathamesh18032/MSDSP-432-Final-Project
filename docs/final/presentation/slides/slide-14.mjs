import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide14(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "14 / 18" });
  kicker(ctx, slide, "Grafana Operations");
  title(ctx, slide, "Grafana is the enterprise operations room for the data platform.", 82, 980);
  subtitle(ctx, slide, "It complements Streamlit by emphasizing ingestion health, sensor estate, geomap, coverage, and data quality.", 174, 930);
  await proofCard(ctx, slide, 84, 306, 300, "Executive overview", "readings, sensors, source coverage, valid rate, freshness, drops.", "graph", colors.cyan);
  await proofCard(ctx, slide, 432, 306, 300, "Ingestion operations", "queue throughput, backpressure channel fill, metric freshness.", "pulse", colors.green);
  await proofCard(ctx, slide, 780, 306, 300, "Sensor estate", "metric coverage, latest readings, freshness table, native geomap.", "map", colors.gold);
  await proofCard(ctx, slide, 258, 506, 300, "City domains", "air quality, weather, water, and mobility trend panels.", "city", colors.coral);
  await proofCard(ctx, slide, 606, 506, 300, "Quality lens", "quality distribution, valid rate by source, suspect/invalid review.", "shield", colors.cyan);
  return slide;
}
