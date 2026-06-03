import { colors, depthPanel, footerChrome, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide19(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "19 / 19" });
  kicker(ctx, slide, "Thank You");
  title(ctx, slide, "Thank you.", 92, 720);
  subtitle(ctx, slide, "Q&A: Smart City Zero-Disk IoT Infrastructure", 190, 780);

  depthPanel(ctx, slide, 654, 106, 390, 142, { fill: "#111D31", line: colors.cyan, name: "motion-qa-panel" });
  label(ctx, slide, 692, 136, "Group 4", { width: 200, size: 24, bold: true, color: colors.cyan });
  paragraph(ctx, slide, 692, 178, "Production-ready civic telemetry platform with live dashboards, cloud runtime, and governed data lifecycle.", {
    width: 300,
    height: 62,
    size: 14.5,
    color: colors.muted2,
  });

  const prompts = [
    ["Architecture", "How the zero-disk path separates hot operations from long-term history.", colors.gold],
    ["Operations", "How CI/CD, GKE, backups, dashboards, and alerts make the system maintainable.", colors.green],
    ["Safety", "How curated views and protected access reduce misuse of city telemetry.", colors.coral],
  ];

  prompts.forEach((item, index) => {
    const x = 88 + index * 330;
    depthPanel(ctx, slide, x, 332, 280, 132, { fill: index === 1 ? "#14263C" : "#111D31", line: item[2], name: `motion-qa-topic-${index + 1}` });
    label(ctx, slide, x + 24, 362, item[0], { width: 220, size: 22, bold: true, color: item[2] });
    paragraph(ctx, slide, x + 24, 406, item[1], { width: 226, height: 42, size: 14.5, color: colors.white });
  });

  ctx.addText(slide, {
    x: 90,
    y: 524,
    width: 880,
    height: 42,
    text: "We are ready for questions on the product, architecture, runtime, dashboards, cost controls, and business impact.",
    fontSize: 23,
    bold: true,
    color: colors.white,
    name: "motion-qa-close",
  });

  footerChrome(ctx, slide);
  return slide;
}
