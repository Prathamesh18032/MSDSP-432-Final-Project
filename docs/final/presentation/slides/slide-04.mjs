import { colors, depthPanel, flowArrow, footerChrome, kicker, label, paragraph, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const TRAFFIC_CAMERA_IMAGE = "docs/final/presentation/assets/traffic-pattern-camera-cc-by-sa.jpg";

export async function slide04(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "04 / 19" });
  kicker(ctx, slide, "Platform Architecture");
  title(ctx, slide, "A clean architecture separates ingestion, storage, operations, and reporting.", 82, 800);
  subtitle(ctx, slide, "Clear boundaries keep the platform scalable, observable, recoverable, and easy for operators to reason about.", 214, 760);
  await photoFrame(ctx, slide, 884, 104, 252, 126, TRAFFIC_CAMERA_IMAGE, {
    label: "Field sensor infrastructure",
    accent: colors.coral,
    overlay: "#07111F8A",
    name: "motion-photo-architecture-sensor",
  });
  const stages = [
    ["Smart-city sources", "OpenAQ\nOpen-Meteo\nDivvy GBFS\nUSGS\nSimulator", colors.cyan],
    ["Ingestion services", "Go adapters\nnormalizers\nvalidators\nqueue sink", colors.green],
    ["Hot + cold storage", "TimescaleDB\nParquet\nGCS\nBigQuery", colors.gold],
    ["Runtime operations", "GKE\nCI/CD\nbackups\ncost modes", colors.coral],
    ["Reports", "Streamlit\nGrafana\nrunbooks\nclient views", colors.cyan],
  ];
  stages.forEach((s, i) => {
    const x = 54 + i * 224;
    depthPanel(ctx, slide, x, 306, 170, 190, { fill: i === 2 ? "#14263C" : "#111D31" });
    label(ctx, slide, x + 16, 334, s[0], { width: 136, size: 17, bold: true, color: s[2] });
    paragraph(ctx, slide, x + 16, 382, s[1], { width: 136, height: 84, size: 14, color: colors.white });
    if (i < stages.length - 1) flowArrow(ctx, slide, x + 178, 390, 36, s[2]);
  });
  footerChrome(ctx, slide);
  return slide;
}
