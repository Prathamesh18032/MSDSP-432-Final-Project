import { colors, kicker, proofCard, slideBase, subtitle, title } from "../common.mjs";

export async function slide17(presentation, ctx) {
  const slide = slideBase(presentation, ctx, { page: "17 / 18" });
  kicker(ctx, slide, "Future Scope");
  title(ctx, slide, "AI Agents are the next layer above the implemented telemetry platform.", 82, 980);
  subtitle(ctx, slide, "Frame this as future scope unless teammate code lands before final packaging, then refresh the deck and zip.", 174, 920);
  await proofCard(ctx, slide, 84, 314, 300, "Incident triage", "Summarize abnormal readings and recommend operator actions.", "bot", colors.cyan);
  await proofCard(ctx, slide, 432, 314, 300, "Anomaly explanation", "Connect air, mobility, weather, and water signals into a cause hypothesis.", "eye", colors.green);
  await proofCard(ctx, slide, 780, 314, 300, "Operator copilot", "Answer questions over TimescaleDB and BigQuery history.", "reports", colors.gold);
  await proofCard(ctx, slide, 434, 514, 300, "Policy-aware routing", "Route alerts with safety, privacy, and access boundaries.", "shield", colors.coral);
  return slide;
}
