import { capabilityCard, colors, footerChrome, kicker, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const SOFTWARE_TEAM_IMAGE = "docs/final/presentation/assets/software-development-team-public-domain.jpg";

export async function slide10(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "10 / 19" });
  kicker(ctx, slide, "Release Engineering");
  title(ctx, slide, "Automated CI/CD promotes verified releases into the cloud runtime.", 82, 980);
  subtitle(ctx, slide, "GitHub Actions publishes images, promotes latest-main into GKE, refreshes Grafana provisioning, and verifies runtime health.", 174, 950);
  await photoFrame(ctx, slide, 906, 212, 226, 74, SOFTWARE_TEAM_IMAGE, {
    label: "Software delivery discipline",
    accent: colors.green,
    overlay: "#07111F8A",
    labelSize: 9.6,
    name: "motion-photo-release-team",
  });
  await capabilityCard(ctx, slide, 88, 318, 310, "Verified images", "Local builds and smoke checks validate deployable service containers before publish.", "package", colors.cyan);
  await capabilityCard(ctx, slide, 446, 318, 310, "GitHub Actions", "OIDC-backed workflows publish latest-main and short-SHA tags to Artifact Registry.", "code", colors.green);
  await capabilityCard(ctx, slide, 804, 318, 310, "Runtime promotion", "The promotion workflow deploys selected tags and checks the live release.", "rocket", colors.gold);
  await capabilityCard(ctx, slide, 270, 500, 310, "Workflow gates", "Static checks protect publish and promotion workflow integrity.", "check", colors.coral, { height: 118 });
  await capabilityCard(ctx, slide, 628, 500, 310, "Release health", "Image and runtime checks confirm selected tags exist before and after rollout.", "eye", colors.cyan, { height: 118 });
  footerChrome(ctx, slide);
  return slide;
}
