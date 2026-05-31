import { colors, depthPanel, flowArrow, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide04(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "04 / 18" });
  kicker(ctx, slide, "Platform Architecture");
  title(ctx, slide, "The system separates ingestion, storage, operations, and reporting concerns.", 82, 1000);
  subtitle(ctx, slide, "This keeps the demo understandable while preserving real backend/data-engineering depth.", 174, 880);
  const stages = [
    ["Smart-city sources", "OpenAQ\nOpen-Meteo\nDivvy GBFS\nUSGS\nSimulator", colors.cyan],
    ["Ingestion services", "Go adapters\nnormalizers\nvalidators\nqueue sink", colors.green],
    ["Hot + cold storage", "TimescaleDB\nParquet\nGCS\nBigQuery", colors.gold],
    ["Runtime operations", "GKE\nCI/CD\nbackups\ncost modes", colors.coral],
    ["Reports", "Streamlit\nGrafana\nrunbooks\nfinal deck", colors.cyan],
  ];
  stages.forEach((s, i) => {
    const x = 54 + i * 224;
    depthPanel(ctx, slide, x, 306, 170, 190, { fill: i === 2 ? "#14263C" : "#111D31" });
    label(ctx, slide, x + 16, 334, s[0], { width: 136, size: 17, bold: true, color: s[2] });
    paragraph(ctx, slide, x + 16, 382, s[1], { width: 136, height: 84, size: 14, color: colors.white });
    if (i < stages.length - 1) flowArrow(ctx, slide, x + 178, 390, 36, s[2]);
  });
  return slide;
}
