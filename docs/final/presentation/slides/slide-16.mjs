import { capabilityCard, colors, footerChrome, kicker, photoFrame, slideBase, subtitle, title } from "../common.mjs";

const CLOUD_SECURITY_IMAGE = "docs/final/presentation/assets/cloud-security-lab-public-domain.jpg";

export async function slide16(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "16 / 19" });
  kicker(ctx, slide, "Safety, Privacy, Security");
  title(ctx, slide, "City telemetry stays useful without becoming unsafe.", 82, 980);
  subtitle(ctx, slide, "The product is designed to expose decision-ready civic signals, not raw infrastructure access or person-level tracking that could be misused.", 174, 920);
  await photoFrame(ctx, slide, 904, 210, 226, 72, CLOUD_SECURITY_IMAGE, {
    label: "Guarded civic-data access",
    accent: colors.coral,
    overlay: "#07111F86",
    labelSize: 9.6,
    name: "motion-photo-security-cloud",
  });
  await capabilityCard(ctx, slide, 86, 316, 300, "Curated public views", "Dashboards show aggregate readings, quality, freshness, and trends instead of raw backend access.", "eye", colors.cyan);
  await capabilityCard(ctx, slide, 434, 316, 300, "Login-protected access", "Streamlit and Grafana stay behind explicit access gates, with no anonymous database exposure.", "shield", colors.green);
  await capabilityCard(ctx, slide, 782, 316, 300, "Private raw state", "TimescaleDB, services, source configuration, and credentials remain inside the runtime network.", "lock", colors.gold);
  await capabilityCard(ctx, slide, 260, 500, 300, "No person-level tracking", "The platform works with environmental, mobility, and water signals; it does not publish identity-level movement traces.", "scan-eye", colors.coral, { height: 118 });
  await capabilityCard(ctx, slide, 608, 500, 300, "Audit-ready recovery", "Backups, restore checks, and runbooks support controlled recovery after incidents or accidental exposure.", "refresh-cw", colors.cyan, { height: 118 });
  footerChrome(ctx, slide);
  return slide;
}
