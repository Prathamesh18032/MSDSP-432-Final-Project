import { colors, depthPanel, flowArrow, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide09(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "09 / 18" });
  kicker(ctx, slide, "Cloud Runtime");
  title(ctx, slide, "The runtime path proves the platform can operate beyond a laptop.", 82, 980);
  subtitle(ctx, slide, "GKE Autopilot, Workload Identity, internal TimescaleDB, CronJobs, and private backend services form the cloud operating model.", 174, 960);
  const blocks = [
    ["Terraform", "plan/apply gates\ncore + runtime resources", colors.gold],
    ["Artifact Registry", "service images\nCI-published tags", colors.green],
    ["GKE Autopilot", "runtime workloads\ninternal database", colors.cyan],
    ["Public demo", "Streamlit-only ingress\npassword gate", colors.coral],
  ];
  blocks.forEach((b, i) => {
    const x = 86 + i * 262;
    depthPanel(ctx, slide, x, 320, 210, 178, { fill: "#111D31" });
    label(ctx, slide, x + 20, 350, b[0], { width: 168, size: 20, bold: true, color: b[2] });
    paragraph(ctx, slide, x + 20, 402, b[1], { width: 168, height: 58, size: 16, color: colors.white });
    if (i < blocks.length - 1) flowArrow(ctx, slide, x + 220, 400, 28, b[2]);
  });
  return slide;
}
