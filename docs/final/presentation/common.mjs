export const colors = {
  ink: "#0B1220",
  ink2: "#111827",
  panel: "#162033",
  panel2: "#1F2A44",
  paper: "#F7F4EC",
  muted: "#AAB4C5",
  cyan: "#3DD6D0",
  green: "#84D65A",
  gold: "#F7C948",
  coral: "#F97373",
  white: "#FFFFFF",
};

export const iconMap = {
  package: "package-check",
  backend: "workflow",
  reports: "layout-dashboard",
  cloud: "cloud",
  database: "database",
  shield: "shield-check",
  pulse: "activity",
  map: "map",
  bot: "bot",
  graph: "chart-no-axes-combined",
  lock: "lock-keyhole",
  storage: "archive",
  rocket: "rocket",
  code: "git-branch",
  check: "badge-check",
  city: "building-2",
  signal: "radio-tower",
  eye: "scan-eye",
};

export function slideBase(presentation, ctx, meta = {}) {
  const slide = presentation.slides.add();
  ctx.addShape(slide, { x: 0, y: 0, width: 1280, height: 720, fill: colors.ink });
  ctx.addShape(slide, { x: 990, y: 0, width: 290, height: 720, fill: "#0E1728" });
  ctx.addShape(slide, { x: 1042, y: -40, width: 10, height: 820, fill: "#15223A" });
  ctx.addShape(slide, { x: 0, y: 0, width: 1280, height: 8, fill: colors.cyan });
  ctx.addText(slide, {
    x: 56,
    y: 674,
    width: 720,
    height: 24,
    text: "MSDS 432 Group 4 | Smart City Zero-Disk IoT Infrastructure",
    fontSize: 12,
    color: colors.muted,
  });
  ctx.addText(slide, {
    x: 1110,
    y: 674,
    width: 114,
    height: 24,
    text: String(meta.page || ""),
    fontSize: 12,
    color: colors.muted,
    align: "right",
  });
  return slide;
}

export function depthPanel(ctx, slide, x, y, width, height, opts = {}) {
  const shadow = opts.shadow || "#050A14";
  ctx.addShape(slide, { x: x + 10, y: y + 12, width, height, fill: shadow, line: { style: "solid", fill: shadow, width: 0 } });
  ctx.addShape(slide, { x: x + 4, y: y + 6, width, height, fill: opts.mid || "#101A2B", line: { style: "solid", fill: "#233149", width: 1 } });
  return ctx.addShape(slide, {
    x,
    y,
    width,
    height,
    fill: opts.fill || colors.panel,
    line: { style: "solid", fill: opts.line || "#34445E", width: opts.lineWidth || 1 },
  });
}

export function kicker(ctx, slide, text, y = 42) {
  ctx.addShape(slide, { x: 56, y: y + 7, width: 9, height: 9, fill: colors.cyan });
  ctx.addText(slide, {
    x: 76,
    y,
    width: 420,
    height: 26,
    text: text.toUpperCase(),
    fontSize: 13,
    bold: true,
    color: colors.cyan,
  });
}

export function title(ctx, slide, text, y = 82, width = 880) {
  ctx.addText(slide, {
    x: 56,
    y,
    width,
    height: 100,
    text,
    fontSize: 40,
    bold: true,
    color: colors.white,
    face: "Aptos Display",
  });
}

export function subtitle(ctx, slide, text, y = 178, width = 760) {
  ctx.addText(slide, {
    x: 58,
    y,
    width,
    height: 58,
    text,
    fontSize: 19,
    color: colors.muted,
  });
}

export function panel(ctx, slide, x, y, width, height, opts = {}) {
  return ctx.addShape(slide, {
    x,
    y,
    width,
    height,
    fill: opts.fill || colors.panel,
    line: { style: "solid", fill: opts.line || "#27364F", width: opts.lineWidth || 1 },
  });
}

export async function iconBadge(ctx, slide, x, y, icon, opts = {}) {
  const size = opts.size || 42;
  const fill = opts.fill || "#0E1728";
  const accent = opts.accent || colors.cyan;
  ctx.addShape(slide, { x: x + 5, y: y + 6, width: size, height: size, fill: "#050A14", line: { style: "solid", fill: "#050A14", width: 0 } });
  ctx.addShape(slide, { x, y, width: size, height: size, fill, line: { style: "solid", fill: accent, width: 1.2 } });
  await ctx.addLucideIcon(slide, {
    icon: iconMap[icon] || icon,
    x: x + 9,
    y: y + 9,
    width: size - 18,
    height: size - 18,
    color: accent,
    strokeWidth: 2.2,
    fit: "contain",
  });
}

export async function proofCard(ctx, slide, x, y, width, titleText, bodyText, icon, accent = colors.cyan) {
  depthPanel(ctx, slide, x, y, width, 138, { fill: "#121D31" });
  await iconBadge(ctx, slide, x + 18, y + 18, icon, { accent, size: 40 });
  ctx.addText(slide, { x: x + 72, y: y + 18, width: width - 92, height: 28, text: titleText, fontSize: 18, bold: true, color: accent });
  ctx.addText(slide, { x: x + 22, y: y + 68, width: width - 44, height: 48, text: bodyText, fontSize: 13.5, color: colors.white });
}

export function largeNumber(ctx, slide, x, y, value, labelText, accent = colors.cyan) {
  ctx.addText(slide, { x, y, width: 110, height: 58, text: value, fontSize: 48, bold: true, color: accent, face: "Aptos Display" });
  ctx.addText(slide, { x: x + 116, y: y + 10, width: 280, height: 40, text: labelText, fontSize: 17, color: colors.white });
}

export function flowArrow(ctx, slide, x, y, width = 58, accent = colors.cyan) {
  ctx.addShape(slide, { x, y: y + 8, width, height: 4, fill: accent });
  ctx.addShape(slide, { x: x + width - 10, y, width: 14, height: 20, fill: accent });
}

export function divider(ctx, slide, y = 250) {
  ctx.addShape(slide, { x: 58, y, width: 1080, height: 1, fill: "#26364F" });
}

export function label(ctx, slide, x, y, text, opts = {}) {
  ctx.addText(slide, {
    x,
    y,
    width: opts.width || 220,
    height: opts.height || 24,
    text,
    fontSize: opts.size || 14,
    bold: opts.bold || false,
    color: opts.color || colors.white,
    align: opts.align || "left",
  });
}

export function paragraph(ctx, slide, x, y, text, opts = {}) {
  ctx.addText(slide, {
    x,
    y,
    width: opts.width || 360,
    height: opts.height || 88,
    text,
    fontSize: opts.size || 17,
    color: opts.color || colors.muted,
    insets: { left: 0, right: 0, top: 0, bottom: 0 },
  });
}

export function metric(ctx, slide, x, y, value, labelText, note, accent = colors.cyan) {
  panel(ctx, slide, x, y, 178, 112, { fill: "#101A2B" });
  ctx.addShape(slide, { x, y, width: 178, height: 4, fill: accent });
  ctx.addText(slide, { x: x + 16, y: y + 20, width: 146, height: 36, text: value, fontSize: 31, bold: true, color: colors.white });
  ctx.addText(slide, { x: x + 16, y: y + 58, width: 146, height: 24, text: labelText, fontSize: 14, bold: true, color: accent });
  ctx.addText(slide, { x: x + 16, y: y + 82, width: 146, height: 24, text: note, fontSize: 11, color: colors.muted });
}

export function step(ctx, slide, x, y, w, titleText, bodyText, accent = colors.cyan) {
  panel(ctx, slide, x, y, w, 112, { fill: colors.panel });
  ctx.addShape(slide, { x: x + 16, y: y + 18, width: 10, height: 10, fill: accent });
  ctx.addText(slide, { x: x + 34, y: y + 12, width: w - 52, height: 28, text: titleText, fontSize: 17, bold: true, color: colors.white });
  ctx.addText(slide, { x: x + 18, y: y + 48, width: w - 36, height: 48, text: bodyText, fontSize: 13, color: colors.muted });
}

export function bar(ctx, slide, x, y, width, labelText, valueText, pct, accent = colors.cyan) {
  ctx.addText(slide, { x, y, width: 220, height: 22, text: labelText, fontSize: 13, color: colors.white });
  ctx.addShape(slide, { x: x + 250, y: y + 5, width: 300, height: 10, fill: "#263248" });
  ctx.addShape(slide, { x: x + 250, y: y + 5, width: Math.max(8, 300 * pct), height: 10, fill: accent });
  ctx.addText(slide, { x: x + 570, y, width: 110, height: 22, text: valueText, fontSize: 13, color: colors.muted });
}
