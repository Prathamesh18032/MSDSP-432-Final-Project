import { colors, depthPanel, kicker, label, paragraph, slideBase, subtitle, title } from "../common.mjs";

export async function slide18(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "18 / 18" });
  kicker(ctx, slide, "Submission Ready");
  title(ctx, slide, "The final package is reproducible, reviewable, and ready to refresh.", 82, 980);
  subtitle(ctx, slide, "If AI Agent work lands later, pull latest main, update final materials, rerun checks, and rebuild the zip.", 174, 930);
  depthPanel(ctx, slide, 90, 306, 430, 230, { fill: "#101A2B" });
  label(ctx, slide, 126, 342, "Final commands", { width: 320, size: 25, bold: true, color: colors.cyan });
  paragraph(ctx, slide, 126, 400, "make phase3-check\nmake phase3-package\nmake phase3-package-list", { width: 320, height: 92, size: 22, color: colors.white });
  depthPanel(ctx, slide, 620, 306, 430, 230, { fill: "#14263C" });
  label(ctx, slide, 656, 342, "Submit", { width: 320, size: 25, bold: true, color: colors.green });
  paragraph(ctx, slide, 656, 400, "dist/Project_Phase_3_Group4.zip\n\nDeck backup:\ndocs/final/Project_Phase_3_Group4_Presentation.pdf", { width: 320, height: 104, size: 18, color: colors.white });
  return slide;
}
