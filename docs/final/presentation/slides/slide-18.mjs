import { colors, depthPanel, footerChrome, kicker, label, paragraph, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const CITY_LIGHTS_IMAGE = "docs/final/presentation/assets/us-city-lights-nasa-public-domain.jpg";

export async function slide18(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "18 / 19" });
  kicker(ctx, slide, "Business Impact");
  title(ctx, slide, "Zero-disk city intelligence turns live telemetry into lower-cost operations.", 82, 980);
  subtitle(ctx, slide, "The platform delivers the practical outcome promised by the project theme: object-storage history, protected dashboards, recoverable runtime, and explicit cost controls.", 178, 940);

  const tiles = [
    ["90%", "storage-saving target", "Architecture aligns with the Phase 2 object-storage target by moving historical data to GCS/Parquet instead of local SSD history.", colors.gold],
    ["0", "public databases", "Streamlit and Grafana expose curated dashboards while TimescaleDB and backend services stay private inside the runtime.", colors.cyan],
    ["4", "cost controls", "Budget guard, cost report, idle mode, and guarded ingress make demo-week cloud spend visible and reversible.", colors.green],
  ];
  tiles.forEach((item, index) => {
    const x = 72 + index * 342;
    depthPanel(ctx, slide, x, 286, 300, 168, { fill: index === 0 ? "#14263C" : "#111D31", name: `motion-impact-tile-${index + 1}` });
    ctx.addText(slide, {
      x: x + 26,
      y: 314,
      width: 96,
      height: 54,
      text: item[0],
      fontSize: 42,
      bold: true,
      color: item[3],
      face: "Aptos Display",
      name: `motion-impact-value-${index + 1}`,
    });
    label(ctx, slide, x + 128, 326, item[1], { width: 132, height: 36, size: 17, bold: true, color: colors.white });
    paragraph(ctx, slide, x + 26, 382, item[2], { width: 246, height: 54, size: 13.5, color: colors.muted2 });
  });

  await photoFrame(ctx, slide, 72, 496, 984, 112, CITY_LIGHTS_IMAGE, {
    label: "Delivered outcome: lower-cost historical intelligence with live operational visibility",
    accent: colors.cyan,
    overlay: "#07111FAA",
    labelSize: 11,
    name: "motion-photo-impact-city-lights",
  });
  footerChrome(ctx, slide);
  return slide;
}
