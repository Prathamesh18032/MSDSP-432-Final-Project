import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide10(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "10 / 18" });
  kicker(ctx, slide, "Release Engineering");
  title(ctx, slide, "CI/CD and promotion checks create a controlled release story.", 82, 980);
  subtitle(ctx, slide, "The implementation has local builds, cloud image publishing, and manual runtime promotion rather than ad hoc deployment.", 174, 930);
  await proofCard(ctx, slide, 88, 308, 310, "Local image proof", "make docker-build and make docker-smoke validate deployable service images.", "package", colors.cyan);
  await proofCard(ctx, slide, 446, 308, 310, "GitHub Actions", "OIDC-backed workflows publish latest-main and short-SHA tags.", "code", colors.green);
  await proofCard(ctx, slide, 804, 308, 310, "Runtime promotion", "Manual promotion deploys selected tags and verifies release health.", "rocket", colors.gold);
  await proofCard(ctx, slide, 270, 508, 310, "Workflow checks", "make ci-cd-check guards publish and promotion workflow integrity.", "check", colors.coral);
  await proofCard(ctx, slide, 628, 508, 310, "Image checks", "make runtime-image-check verifies selected tags exist before rollout.", "eye", colors.cyan);
  return slide;
}
