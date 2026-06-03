import { capabilityCard, colors, footerChrome, kicker, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const STORAGE_SERVICE_IMAGE = "docs/final/presentation/assets/storage-tape-service-cc0.jpg";

export async function slide11(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "11 / 19" });
  kicker(ctx, slide, "Reliability");
  title(ctx, slide, "The runtime includes health, backup, restore, and recovery controls.", 82, 980);
  subtitle(ctx, slide, "Operational checks make the platform measurable after launch, not just deployable.", 174, 880);
  await photoFrame(ctx, slide, 906, 212, 226, 74, STORAGE_SERVICE_IMAGE, {
    label: "Recoverable storage posture",
    accent: colors.cyan,
    overlay: "#07111F82",
    labelSize: 9.6,
    name: "motion-photo-reliability-storage",
  });
  await capabilityCard(ctx, slide, 82, 318, 300, "Runtime health", "Pods, jobs, PVCs, logs, images, and latest object checks.", "pulse", colors.green);
  await capabilityCard(ctx, slide, 430, 318, 300, "Backups", "GKE jobs export TimescaleDB state to GCS for recoverable storage.", "storage", colors.cyan);
  await capabilityCard(ctx, slide, 778, 318, 300, "Restore test", "A disposable namespace validates backup integrity without disturbing production.", "refresh-cw", colors.gold);
  await capabilityCard(ctx, slide, 248, 500, 300, "Health evidence", "Sanitized runtime snapshots support operations handoff and incident follow-up.", "eye", colors.coral, { height: 118 });
  await capabilityCard(ctx, slide, 596, 500, 300, "Recovery playbooks", "Runbooks show how to start, stop, idle, resume, and clean up safely.", "shield", colors.cyan, { height: 118 });
  footerChrome(ctx, slide);
  return slide;
}
