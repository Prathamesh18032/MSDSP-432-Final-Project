import { colors, depthPanel, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide12(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "12 / 18" });
  kicker(ctx, slide, "Cost Governance");
  title(ctx, slide, "Demo operations are explicit, reversible, and cost-aware.", 82, 980);
  subtitle(ctx, slide, "The runtime can be placed in demo, idle, and resume modes without deleting persistent storage.", 174, 900);
  const items = [
    ["Demo mode", "resume workloads and CronJobs for a review window", colors.green],
    ["Idle mode", "disable public ingress and scale optional workloads down", colors.cyan],
    ["Resume mode", "bring the runtime back and validate health", colors.gold],
    ["Cost report", "summarize active resources and public demo posture", colors.coral],
  ];
  items.forEach((item, i) => {
    const y = 294 + i * 78;
    depthPanel(ctx, slide, 120, y, 780, 48, { fill: "#111D31" });
    label(ctx, slide, 150, y + 12, item[0], { width: 180, size: 18, bold: true, color: item[2] });
    paragraph(ctx, slide, 346, y + 11, item[1], { width: 480, height: 22, size: 16, color: colors.white });
  });
  return slide;
}
