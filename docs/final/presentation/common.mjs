export const colors = {
  ink: "#0B1220",
  ink2: "#111827",
  panel: "#162033",
  panel2: "#1F2A44",
  panel3: "#223554",
  paper: "#F7F4EC",
  muted: "#AAB4C5",
  muted2: "#D8DEE9",
  cyan: "#3DD6D0",
  green: "#84D65A",
  gold: "#F7C948",
  coral: "#F97373",
  blue: "#5BA7FF",
  violet: "#B566F2",
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
  platform: "network",
  globe: "globe-2",
  monitor: "monitor",
  quality: "list-checks",
  clock: "clock-3",
  cost: "wallet-cards",
};

function motionName(ctx, kind) {
  ctx.__motionCounters = ctx.__motionCounters || {};
  const slideNumber = String(ctx.slideNumber || "00").padStart(2, "0");
  const next = (ctx.__motionCounters[kind] || 0) + 1;
  ctx.__motionCounters[kind] = next;
  return `motion-${kind}-${slideNumber}-${String(next).padStart(2, "0")}`;
}

export function slideBase(presentation, ctx, meta = {}) {
  const slide = presentation.slides.add();
  slide.__page = meta.page || "";
  ctx.addShape(slide, { x: 0, y: 0, width: 1280, height: 720, fill: colors.ink });
  ctx.addShape(slide, { x: 0, y: 0, width: 1280, height: 720, fill: "#0A1020" });
  ctx.addShape(slide, { x: 992, y: 0, width: 288, height: 720, fill: "#0E1728" });
  ctx.addShape(slide, { x: 1042, y: -40, width: 10, height: 820, fill: "#15223A" });
  ctx.addShape(slide, { x: 1112, y: -40, width: 2, height: 820, fill: "#203554" });
  ctx.addShape(slide, { x: 0, y: 0, width: 1280, height: 8, fill: colors.cyan });
  return slide;
}

export function footerChrome(ctx, slide, page = slide.__page || "") {
  ctx.addShape(slide, { x: 0, y: 642, width: 992, height: 78, fill: "#0A1020", name: "footer-safe-band" });
  ctx.addShape(slide, { x: 992, y: 642, width: 288, height: 78, fill: "#0E1728", name: "footer-rail-band" });
  ctx.addShape(slide, { x: 56, y: 654, width: 870, height: 1, fill: "#2A3C58", name: "footer-rule" });
  ctx.addShape(slide, { x: 56, y: 654, width: 116, height: 1, fill: colors.cyan, name: "footer-rule-accent" });
  ctx.addText(slide, {
    x: 56,
    y: 674,
    width: 720,
    height: 24,
    text: "MSDS 432 Group 4 | Smart City Zero-Disk IoT Infrastructure",
    fontSize: 12,
    color: colors.muted,
    name: "footer-label",
  });
  ctx.addText(slide, {
    x: 1110,
    y: 674,
    width: 114,
    height: 24,
    text: String(page),
    fontSize: 12,
    color: colors.muted,
    align: "right",
    name: "footer-page",
  });
}

export function depthPanel(ctx, slide, x, y, width, height, opts = {}) {
  const shadow = opts.shadow || "#050A14";
  const name = opts.name || "";
  ctx.addShape(slide, { x: x + 12, y: y + 14, width, height, fill: shadow, line: { style: "solid", fill: shadow, width: 0 }, name: name ? `${name}-shadow` : undefined });
  ctx.addShape(slide, { x: x + 5, y: y + 7, width, height, fill: opts.mid || "#101A2B", line: { style: "solid", fill: "#233149", width: 1 }, name: name ? `${name}-mid` : undefined });
  return ctx.addShape(slide, {
    x,
    y,
    width,
    height,
    fill: opts.fill || colors.panel,
    line: { style: "solid", fill: opts.line || "#34445E", width: opts.lineWidth || 1 },
    name: name ? `${name}-face` : undefined,
  });
}

export function kicker(ctx, slide, text, y = 42) {
  const name = motionName(ctx, "kicker");
  ctx.addShape(slide, { x: 56, y: y + 7, width: 9, height: 9, fill: colors.cyan, name: `${name}-mark` });
  ctx.addText(slide, {
    x: 76,
    y,
    width: 420,
    height: 26,
    text: text.toUpperCase(),
    fontSize: 13,
    bold: true,
    color: colors.cyan,
    name,
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
    name: motionName(ctx, "title"),
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
    name: motionName(ctx, "subtitle"),
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

export async function capabilityCard(ctx, slide, x, y, width, titleText, bodyText, icon, accent = colors.cyan, opts = {}) {
  const height = opts.height || 138;
  const compact = opts.compact || height <= 122;
  const name = opts.name || motionName(ctx, "card");
  const iconSize = opts.iconSize || (compact ? 34 : 40);
  const titleSize = opts.titleSize || (compact ? 15.5 : 18);
  const bodySize = opts.bodySize || (compact ? 11.8 : 13.5);
  depthPanel(ctx, slide, x, y, width, height, { fill: opts.fill || "#121D31", line: opts.line || "#34445E", name });
  await iconBadge(ctx, slide, x + 18, y + 18, icon, { accent, size: iconSize, name: `${name}-icon` });
  ctx.addText(slide, { x: x + 72, y: y + 18, width: width - 92, height: compact ? 24 : 28, text: titleText, fontSize: titleSize, bold: true, color: accent, name: `${name}-title` });
  ctx.addText(slide, { x: x + 22, y: y + (compact ? 58 : 68), width: width - 44, height: height - (compact ? 70 : 84), text: bodyText, fontSize: bodySize, color: opts.bodyColor || colors.white, name: `${name}-body` });
}

export async function calloutCard(ctx, slide, x, y, width, titleText, bodyText, icon, accent = colors.cyan, opts = {}) {
  const name = opts.name || motionName(ctx, "callout");
  depthPanel(ctx, slide, x, y, width, 94, { fill: "#101A2B", line: "#314564", name });
  await iconBadge(ctx, slide, x + 16, y + 18, icon, { accent, size: 38, fill: "#0C1525", name: `${name}-icon` });
  ctx.addText(slide, { x: x + 68, y: y + 16, width: width - 86, height: 24, text: titleText, fontSize: 16, bold: true, color: accent, name: `${name}-title` });
  ctx.addText(slide, { x: x + 68, y: y + 44, width: width - 86, height: 36, text: bodyText, fontSize: 12.5, color: colors.muted2, name: `${name}-body` });
}

export async function screenshotFrame(ctx, slide, x, y, width, height, imagePath, opts = {}) {
  const name = opts.name || motionName(ctx, "screenshot");
  ctx.addShape(slide, { x: x + 16, y: y + 18, width, height, fill: "#030711", line: { style: "solid", fill: "#030711", width: 0 }, name: `${name}-shadow` });
  ctx.addShape(slide, { x: x + 7, y: y + 9, width, height, fill: "#0F1A2B", line: { style: "solid", fill: "#263A58", width: 1 }, name: `${name}-mid` });
  ctx.addShape(slide, { x, y, width, height, fill: "#111A2A", line: { style: "solid", fill: opts.accent || colors.cyan, width: 1.2 }, name: `${name}-frame` });
  ctx.addShape(slide, { x, y, width, height: 34, fill: "#18253A", line: { style: "solid", fill: "#263A58", width: 0 }, name: `${name}-bar` });
  ctx.addShape(slide, { x: x + 18, y: y + 13, width: 8, height: 8, fill: colors.coral });
  ctx.addShape(slide, { x: x + 34, y: y + 13, width: 8, height: 8, fill: colors.gold });
  ctx.addShape(slide, { x: x + 50, y: y + 13, width: 8, height: 8, fill: colors.green });
  if (opts.label) {
    ctx.addText(slide, { x: x + 74, y: y + 9, width: width - 100, height: 18, text: opts.label, fontSize: 11, bold: true, color: colors.muted2, name: `${name}-label` });
  }
  await ctx.addImage(slide, {
    path: imagePath,
    x: x + 10,
    y: y + 42,
    width: width - 20,
    height: height - 52,
    fit: opts.fit || "cover",
    alt: opts.alt || opts.label || "Dashboard screenshot",
    name: `${name}-image`,
  });
}

export async function photoFrame(ctx, slide, x, y, width, height, imagePath, opts = {}) {
  const name = opts.name || motionName(ctx, "photo");
  const accent = opts.accent || colors.cyan;
  ctx.addShape(slide, {
    x: x + 14,
    y: y + 16,
    width,
    height,
    fill: "#030711",
    line: { style: "solid", fill: "#030711", width: 0 },
    name: `${name}-shadow`,
  });
  ctx.addShape(slide, {
    x,
    y,
    width,
    height,
    fill: "#0D1728",
    line: { style: "solid", fill: accent, width: opts.lineWidth || 1.1 },
    name: `${name}-frame`,
  });
  await ctx.addImage(slide, {
    path: imagePath,
    x: x + 6,
    y: y + 6,
    width: width - 12,
    height: height - 12,
    fit: opts.fit || "cover",
    alt: opts.alt || opts.label || "Presentation visual",
    name: `${name}-image`,
  });
  if (opts.overlay !== false) {
    ctx.addShape(slide, {
      x: x + 6,
      y: y + 6,
      width: width - 12,
      height: height - 12,
      fill: opts.overlay || "#07111FCC",
      line: { style: "solid", fill: "#00000000", width: 0 },
      name: `${name}-overlay`,
    });
  }
  if (opts.label) {
    ctx.addShape(slide, {
      x: x + 6,
      y: y + height - 44,
      width: width - 12,
      height: 38,
      fill: "#07111FDD",
      line: { style: "solid", fill: "#00000000", width: 0 },
      name: `${name}-caption-band`,
    });
    ctx.addText(slide, {
      x: x + 20,
      y: y + height - 34,
      width: width - 40,
      height: 18,
      text: opts.label,
      fontSize: opts.labelSize || 10.8,
      bold: true,
      color: opts.labelColor || colors.white,
      name: `${name}-label`,
    });
  }
}

export function pill(ctx, slide, x, y, text, accent = colors.cyan, width = 154) {
  ctx.addShape(slide, { x, y, width, height: 32, fill: "#0F1A2B", line: { style: "solid", fill: accent, width: 1 } });
  ctx.addText(slide, { x: x + 12, y: y + 8, width: width - 24, height: 16, text, fontSize: 11, bold: true, color: accent, align: "center" });
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

export function telemetryRibbon(ctx, slide, x, y, width, opts = {}) {
  const accent = opts.accent || colors.cyan;
  const name = opts.name || motionName(ctx, "telemetry");
  ctx.addShape(slide, { x, y, width, height: 52, fill: opts.fill || "#0E1728", line: { style: "solid", fill: "#263A58", width: 1 }, name: `${name}-base` });
  const values = opts.values || [0.38, 0.58, 0.44, 0.72, 0.62, 0.86, 0.68, 0.78];
  const gap = width / values.length;
  values.forEach((value, index) => {
    const barHeight = 8 + value * 28;
    ctx.addShape(slide, {
      x: x + 18 + index * gap,
      y: y + 34 - barHeight / 2,
      width: Math.max(5, gap - 20),
      height: barHeight,
      fill: index % 3 === 0 ? accent : "#27445F",
      line: { style: "solid", fill: "#00000000", width: 0 },
      name: `${name}-bar-${index + 1}`,
    });
  });
  ctx.addText(slide, { x: x + 18, y: y + 10, width: width - 36, height: 16, text: opts.label || "live telemetry rhythm", fontSize: 10.5, bold: true, color: accent, name: `${name}-label` });
}

export function sensorMesh(ctx, slide, x, y, opts = {}) {
  const accent = opts.accent || colors.cyan;
  const name = opts.name || motionName(ctx, "mesh");
  const points = opts.points || [
    [0, 44],
    [74, 18],
    [146, 62],
    [226, 24],
    [294, 86],
    [166, 122],
    [48, 118],
  ];
  const links = opts.links || [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [2, 5],
    [5, 6],
    [6, 0],
  ];
  links.forEach(([a, b], index) => {
    const [x1, y1] = points[a];
    const [x2, y2] = points[b];
    ctx.addShape(slide, {
      x: x + Math.min(x1, x2),
      y: y + Math.min(y1, y2),
      width: Math.max(1, Math.abs(x2 - x1)),
      height: 2,
      fill: "#203554",
      line: { style: "solid", fill: "#00000000", width: 0 },
      name: `${name}-link-${index + 1}`,
    });
    ctx.addShape(slide, {
      x: x + x2 - 1,
      y: y + Math.min(y1, y2),
      width: 2,
      height: Math.max(1, Math.abs(y2 - y1)),
      fill: "#203554",
      line: { style: "solid", fill: "#00000000", width: 0 },
      name: `${name}-drop-${index + 1}`,
    });
  });
  points.forEach(([px, py], index) => {
    ctx.addShape(slide, {
      x: x + px - 5,
      y: y + py - 5,
      width: 10,
      height: 10,
      fill: index % 2 === 0 ? accent : "#1F3552",
      line: { style: "solid", fill: "#5B7EA9", width: 0.6 },
      name: `${name}-node-${index + 1}`,
    });
  });
}

export function cityGrid(ctx, slide, x, y, width, height, opts = {}) {
  const name = opts.name || motionName(ctx, "citygrid");
  const accent = opts.accent || "#1F3552";
  for (let i = 0; i < 7; i += 1) {
    const towerHeight = 34 + ((i * 17) % 62);
    const towerWidth = 28 + ((i * 11) % 30);
    ctx.addShape(slide, {
      x: x + i * (width / 7) + 8,
      y: y + height - towerHeight,
      width: towerWidth,
      height: towerHeight,
      fill: i % 2 === 0 ? "#121D31" : "#172844",
      line: { style: "solid", fill: "#263A58", width: 0.8 },
      name: `${name}-tower-${i + 1}`,
    });
  }
  for (let i = 0; i < 4; i += 1) {
    ctx.addShape(slide, {
      x: x + 18 + i * 78,
      y: y + 24 + i * 18,
      width: width - 64 - i * 28,
      height: 1,
      fill: accent,
      line: { style: "solid", fill: "#00000000", width: 0 },
      name: `${name}-lane-${i + 1}`,
    });
  }
}
