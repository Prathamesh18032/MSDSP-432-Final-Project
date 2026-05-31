import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide11(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "11 / 18" });
  kicker(ctx, slide, "Reliability");
  title(ctx, slide, "The runtime has health, backup, and restore proof.", 82, 980);
  subtitle(ctx, slide, "These checks make the project feel operated, not merely launched.", 174, 860);
  await proofCard(ctx, slide, 82, 306, 300, "Runtime health", "Pods, jobs, PVCs, logs, images, and latest object checks.", "pulse", colors.green);
  await proofCard(ctx, slide, 430, 306, 300, "Backups", "GKE job exports TimescaleDB state to GCS for recovery evidence.", "storage", colors.cyan);
  await proofCard(ctx, slide, 778, 306, 300, "Restore test", "Disposable namespace validates backup integrity without disturbing production.", "refresh-cw", colors.gold);
  await proofCard(ctx, slide, 248, 506, 300, "Evidence capture", "make runtime-evidence writes sanitized reviewer output.", "eye", colors.coral);
  await proofCard(ctx, slide, 596, 506, 300, "Demo recovery", "runbooks show how to start, stop, idle, resume, and clean up safely.", "shield", colors.cyan);
  return slide;
}
