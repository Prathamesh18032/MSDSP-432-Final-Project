import { colors, depthPanel, footerChrome, kicker, label, paragraph, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const POWER_MANAGEMENT_IMAGE = "docs/final/presentation/assets/power-management-cc0.jpg";

export async function slide12(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "12 / 19" });
  kicker(ctx, slide, "Cost Governance");
  title(ctx, slide, "Runtime modes are explicit, reversible, and cost-aware.", 82, 980);
  subtitle(ctx, slide, "The cloud environment can reduce optional workload cost while preserving persistent storage and recovery posture.", 174, 920);
  await photoFrame(ctx, slide, 906, 212, 226, 74, POWER_MANAGEMENT_IMAGE, {
    label: "Resource control discipline",
    accent: colors.gold,
    overlay: "#07111F80",
    labelSize: 9.6,
    name: "motion-photo-cost-power",
  });
  const items = [
    ["Active mode", "run workloads, dashboards, and CronJobs for live operations", colors.green],
    ["Idle mode", "disable public ingress and scale optional workloads down", colors.cyan],
    ["Resume mode", "bring the runtime back and validate health", colors.gold],
    ["Cost posture", "summarize active resources and public access state", colors.coral],
  ];
  items.forEach((item, i) => {
    const y = 324 + i * 68;
    depthPanel(ctx, slide, 120, y, 780, 48, { fill: "#111D31" });
    label(ctx, slide, 150, y + 12, item[0], { width: 180, size: 18, bold: true, color: item[2] });
    paragraph(ctx, slide, 346, y + 11, item[1], { width: 480, height: 22, size: 16, color: colors.white });
  });
  footerChrome(ctx, slide);
  return slide;
}
