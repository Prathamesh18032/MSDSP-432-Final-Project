import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide16(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "16 / 18" });
  kicker(ctx, slide, "Safety, Privacy, Security");
  title(ctx, slide, "Reviewer access is useful without exposing the platform unsafely.", 82, 980);
  subtitle(ctx, slide, "The implementation includes practical guardrails around secrets, public access, cloud mutation, and recovery.", 174, 920);
  await proofCard(ctx, slide, 86, 314, 300, "No secret package", ".env, Terraform state, local data, caches, and artifacts are excluded.", "lock", colors.cyan);
  await proofCard(ctx, slide, 434, 314, 300, "Protected demo", "Public ingress exposes only Streamlit and requires a demo password.", "shield", colors.green);
  await proofCard(ctx, slide, 782, 314, 300, "Guarded changes", "Terraform apply and public ingress require explicit allow flags.", "check", colors.gold);
  await proofCard(ctx, slide, 260, 514, 300, "Private backend", "Backend services remain inside the runtime network.", "cloud", colors.coral);
  await proofCard(ctx, slide, 608, 514, 300, "Recoverability", "Backup and restore checks prove data recovery posture.", "refresh-cw", colors.cyan);
  return slide;
}
