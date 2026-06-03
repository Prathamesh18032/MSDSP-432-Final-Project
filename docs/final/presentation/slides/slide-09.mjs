import { colors, depthPanel, flowArrow, footerChrome, kicker, label, paragraph, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const DATA_CENTER_IMAGE = "docs/final/presentation/assets/data-center-public-domain.jpg";

export async function slide09(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "09 / 19" });
  kicker(ctx, slide, "Cloud Runtime");
  title(ctx, slide, "Cloud-native runtime supports secure, continuously operated city intelligence.", 82, 980);
  subtitle(ctx, slide, "GKE Autopilot, Workload Identity, internal TimescaleDB, CronJobs, and protected public dashboards form the operating model.", 174, 960);
  await photoFrame(ctx, slide, 908, 238, 230, 74, DATA_CENTER_IMAGE, {
    label: "Cloud runtime backbone",
    accent: colors.green,
    overlay: "#07111F70",
    labelSize: 9.8,
    name: "motion-photo-runtime-backbone",
  });
  const blocks = [
    ["Terraform", "plan/apply gates\ncore + runtime resources", colors.gold],
    ["Artifact Registry", "service images\nCI-published tags", colors.green],
    ["GKE Autopilot", "runtime workloads\ninternal database", colors.cyan],
    ["Protected apps", "Streamlit ingress\nGrafana ingress\nlogin gates", colors.coral],
  ];
  blocks.forEach((b, i) => {
    const x = 86 + i * 262;
    depthPanel(ctx, slide, x, 320, 210, 178, { fill: "#111D31" });
    label(ctx, slide, x + 20, 350, b[0], { width: 168, size: 20, bold: true, color: b[2] });
    paragraph(ctx, slide, x + 20, 402, b[1], { width: 168, height: 58, size: 16, color: colors.white });
    if (i < blocks.length - 1) flowArrow(ctx, slide, x + 220, 400, 28, b[2]);
  });
  footerChrome(ctx, slide);
  return slide;
}
