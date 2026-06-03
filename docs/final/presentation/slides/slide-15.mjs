import { colors, depthPanel, flowArrow, footerChrome, kicker, label, paragraph, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const OPERATIONS_IMAGE = "docs/final/presentation/assets/traffic-control-center-public-domain.jpg";

export async function slide15(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "15 / 19" });
  kicker(ctx, slide, "Operator Journey");
  title(ctx, slide, "The product journey moves from city signal to operational response.", 82, 980);
  subtitle(ctx, slide, "Each layer adds trust: live source capture, validation, current-state storage, decision dashboards, and controlled action.", 174, 930);
  const steps = [
    ["1", "Live signal", "City APIs and simulator readings enter the same ingestion path.", colors.cyan],
    ["2", "Trusted reading", "Normalization, quality flags, and source freshness protect interpretation.", colors.green],
    ["3", "Decision view", "Streamlit and Grafana expose executive and operations surfaces.", colors.gold],
    ["4", "Action posture", "Runbooks, alerts, release health, and cost controls guide response.", colors.coral],
  ];
  steps.forEach((s, i) => {
    const x = 80 + i * 268;
    depthPanel(ctx, slide, x, 324, 210, 156, { fill: "#111D31" });
    label(ctx, slide, x + 22, 344, s[0], { width: 52, size: 34, bold: true, color: s[3] });
    label(ctx, slide, x + 76, 354, s[1], { width: 120, size: 18, bold: true, color: colors.white });
    paragraph(ctx, slide, x + 22, 408, s[2], { width: 166, height: 42, size: 15, color: colors.white });
    if (i < steps.length - 1) flowArrow(ctx, slide, x + 218, 392, 34, s[3]);
  });
  await photoFrame(ctx, slide, 124, 516, 850, 102, OPERATIONS_IMAGE, {
    label: "From signal monitoring to operational response",
    accent: colors.coral,
    overlay: "#07111FA6",
    name: "motion-photo-operator-center",
  });
  footerChrome(ctx, slide);
  return slide;
}
