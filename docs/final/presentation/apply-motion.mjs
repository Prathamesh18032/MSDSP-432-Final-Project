#!/usr/bin/env node

import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { spawnSync } from "node:child_process";

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const key = argv[index];
    if (!key.startsWith("--")) {
      throw new Error(`Unexpected positional argument: ${key}`);
    }
    const next = argv[index + 1];
    if (!next || next.startsWith("--")) {
      args[key.slice(2)] = true;
      continue;
    }
    args[key.slice(2)] = next;
    index += 1;
  }
  return args;
}

function requireArg(args, key) {
  if (!args[key]) {
    throw new Error(`Missing --${key}`);
  }
  return args[key];
}

function run(command, args, opts = {}) {
  const result = spawnSync(command, args, { encoding: "utf8", ...opts });
  if (result.status !== 0) {
    throw new Error(
      [
        `${command} ${args.join(" ")} failed`,
        result.stdout?.trim(),
        result.stderr?.trim(),
      ]
        .filter(Boolean)
        .join("\n"),
    );
  }
}

const SPEAKER_NOTES = {
  1: [
    "Target 0:40.",
    "Open with the product name and positioning: this is a production-ready smart-city data platform, not just a classroom prototype.",
    "Call out the core value: live city signals, protected dashboards, cloud operations, and a zero-disk history path.",
    "Transition: the next slide explains the executive story in one sentence.",
  ],
  2: [
    "Target 0:45.",
    "Explain the simple story: city APIs and simulator feeds become trusted signals, operational storage, retained history, and client-ready dashboards.",
    "Mention the business outcome: leaders can see what is happening now while the platform keeps history cost-controlled.",
    "Do not go deep into implementation yet; this slide is the narrative frame.",
  ],
  3: [
    "Target 0:40.",
    "Show maturity: the project moved from blueprint to implemented runtime, cloud operations, and product surfaces.",
    "Emphasize that each stage reduced risk: source boundaries, repeatable deployment, and observable dashboards.",
    "Transition: now show the architecture that makes that maturity possible.",
  ],
  4: [
    "Target 0:45.",
    "Walk left to right: sources, ingestion, hot and cold storage, runtime operations, and reporting.",
    "Connect the field sensor image to the architecture: real city infrastructure produces signals, but the product normalizes and governs them before use.",
    "Stress that separation of concerns keeps the platform scalable, recoverable, and easier to operate.",
  ],
  5: [
    "Target 0:45.",
    "Explain that multiple city domains feed one normalized reading model: air, weather, mobility, water, and simulator.",
    "Call out why this matters: dashboards can compare freshness, quality, and coverage without bespoke logic for every API.",
    "Keep this brief; the next slide covers quality guardrails.",
  ],
  6: [
    "Target 0:40.",
    "Explain that the platform does not blindly trust incoming payloads.",
    "Mention normalization, validation, observability, coverage, and traceability as the controls that protect decisions.",
    "Tie it to enterprise value: bad or missing readings become visible instead of silently entering reports.",
  ],
  7: [
    "Target 0:40.",
    "Position TimescaleDB as the current-state operating store, not the archive.",
    "Use the infrastructure image to reinforce that hot storage is private runtime infrastructure.",
    "Mention fast operations, unit-aware analytics, and private backend exposure.",
  ],
  8: [
    "Target 0:45.",
    "Explain the zero-disk idea: keep active operational reads hot, then move retained history to object storage and analytics-friendly formats.",
    "Call out Parquet, GCS, and BigQuery as the durability and analytics path.",
    "Make the business connection: this supports lower-cost historical analytics without growing local disk dependence.",
  ],
  9: [
    "Target 0:45.",
    "Explain the cloud runtime: Terraform resources, Artifact Registry images, GKE runtime, and protected apps.",
    "Mention that TimescaleDB remains private while Streamlit and Grafana are exposed through guarded surfaces.",
    "Transition to release automation: the system needs repeatable promotion, not manual deployment.",
  ],
  10: [
    "Target 0:45.",
    "Describe the CI/CD path: local checks validate containers, GitHub Actions publishes images, and promotion deploys selected tags.",
    "Stress traceability: latest-main and short-SHA tags make releases easy to identify and roll forward.",
    "Avoid spending time on commands; keep it client-facing.",
  ],
  11: [
    "Target 0:45.",
    "Explain reliability controls: runtime health, backups, restore tests, health evidence, and recovery runbooks.",
    "The key message is measurability: operations are not just deployed, they can be checked and recovered.",
    "Transition: operating cost is also controlled explicitly.",
  ],
  12: [
    "Target 0:40.",
    "Explain the active, idle, and resume modes.",
    "Mention cost report, budget guard, and guarded public ingress as practical controls for demo-week and production-style operations.",
    "Keep the emphasis on reversibility and visibility.",
  ],
  13: [
    "Target 0:45.",
    "Show Streamlit as the executive command center.",
    "Mention KPIs, city-domain lens, archive visibility, and protected access.",
    "Point out that this is the business-facing product surface, not backend tooling.",
  ],
  14: [
    "Target 0:45.",
    "Show Grafana as the operations dashboard.",
    "Mention live ingestion, unit-specific charts, freshness, dropped readings, and alert visibility.",
    "Position Grafana as the operator view that complements the executive Streamlit view.",
  ],
  15: [
    "Target 0:45.",
    "Tell the operator journey: signal capture, trusted reading, decision view, then action posture.",
    "Explain that the product compresses messy ingestion into a clear response path.",
    "This is the story slide before safety and final output.",
  ],
  16: [
    "Target 0:50.",
    "Address misuse directly: city telemetry can be sensitive if raw systems or detailed traces are exposed.",
    "Explain the safeguards: curated dashboard views, login-protected access, private raw state, no person-level tracking, and audit-ready recovery.",
    "The key line: the product exposes decision-ready civic signals, not raw infrastructure access.",
  ],
  17: [
    "Target 0:45.",
    "Summarize what actually shipped: live signal capture, decision surfaces, zero-disk history, and cloud operations.",
    "Use the operations-center image to anchor the product as an operating environment.",
    "Avoid repeating screenshot detail; those were already proven on slides 13 and 14.",
  ],
  18: [
    "Target 1:00.",
    "Close the business case: the platform exists to make live city telemetry useful while keeping long-term history lower-cost and governed.",
    "Be evidence-safe: say the architecture aligns with the Phase 2 90 percent storage-saving target; do not claim measured billing savings.",
    "Call out three outcomes: object-storage history, zero public databases, and explicit cost controls.",
  ],
  19: [
    "Target 0:35.",
    "Thank the audience and invite questions.",
    "If time remains, prompt questions around architecture, operations, safety, cost controls, or business impact.",
    "Stop here by 14 minutes to protect Q&A time.",
  ],
};

function slideNumber(fileName) {
  const match = fileName.match(/^slide(\d+)\.xml$/);
  return match ? Number.parseInt(match[1], 10) : undefined;
}

function escapeRegExp(value) {
  return String(value).replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function extractMotionTargets(xml, slideIndex) {
  const records = [...xml.matchAll(/<p:cNvPr id="(\d+)" name="([^"]*)"/g)].map((match) => ({
    id: Number.parseInt(match[1], 10),
    name: match[2],
    kind: "named",
    slideIndex,
  }));
  const largePictures = [...xml.matchAll(/<p:pic>[\s\S]*?<p:cNvPr id="(\d+)" name="([^"]*)"[\s\S]*?<a:ext cx="(\d+)" cy="(\d+)" \/>[\s\S]*?<\/p:pic>/g)]
    .map((match, index) => ({
      id: Number.parseInt(match[1], 10),
      name: `motion-large-image-${String(slideIndex).padStart(2, "0")}-${String(index + 1).padStart(2, "0")}`,
      kind: "image",
      slideIndex,
      cx: Number.parseInt(match[3], 10),
      cy: Number.parseInt(match[4], 10),
    }))
    .filter((record) => record.cx >= 600000 && record.cy >= 500000);

  const imageBuildSlides = new Set([1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18]);

  const keep = (record) => {
    const name = record.name || "";
    if (record.kind === "image") return imageBuildSlides.has(slideIndex);
    if (!name.startsWith("motion-")) return false;
    if (/-(shadow|mid|frame|bar|mark|base|node|link|drop|tower|lane)-/.test(name)) return false;
    if (/motion-(mesh|citygrid)-/.test(name)) return false;

    if (slideIndex === 18) {
      return /motion-(title|subtitle)-/.test(name) || /motion-impact-value-\d+$/.test(name);
    }
    if ([1, 3, 4, 9, 15, 17, 19].includes(slideIndex)) {
      return /motion-(title|subtitle)-/.test(name);
    }
    return false;
  };

  const rank = (record) => {
    const name = record.name;
    if (/motion-title-/.test(name)) return 10;
    if (record.kind === "image") return 20;
    if (/motion-subtitle-/.test(name)) return 30;
    if (/motion-impact-value-/.test(name)) return 40;
    return 90;
  };

  const seen = new Set();
  return [...records, ...largePictures]
    .filter(keep)
    .filter((record) => {
      if (seen.has(record.id)) return false;
      seen.add(record.id);
      return true;
    })
    .sort((a, b) => rank(a) - rank(b) || a.id - b.id)
    .slice(0, slideIndex === 18 ? 6 : 5);
}

function transitionSpec(slideIndex) {
  const specs = {
    1: { name: "fade", xml: "<p:fade/>" },
    2: { name: "push-left", xml: '<p:push dir="l"/>' },
    3: { name: "push-left", xml: '<p:push dir="l"/>' },
    4: { name: "wipe-left", xml: '<p:wipe dir="l"/>' },
    5: { name: "push-left", xml: '<p:push dir="l"/>' },
    6: { name: "fade", xml: "<p:fade/>" },
    7: { name: "push-left", xml: '<p:push dir="l"/>' },
    8: { name: "wipe-up", xml: '<p:wipe dir="u"/>' },
    9: { name: "push-left", xml: '<p:push dir="l"/>' },
    10: { name: "push-left", xml: '<p:push dir="l"/>' },
    11: { name: "fade", xml: "<p:fade/>" },
    12: { name: "wipe-left", xml: '<p:wipe dir="l"/>' },
    13: { name: "fade", xml: "<p:fade/>" },
    14: { name: "fade", xml: "<p:fade/>" },
    15: { name: "push-left", xml: '<p:push dir="l"/>' },
    16: { name: "wipe-left", xml: '<p:wipe dir="l"/>' },
    17: { name: "fade", xml: "<p:fade/>" },
    18: { name: "fade", xml: "<p:fade/>" },
    19: { name: "fade", xml: "<p:fade/>" },
  };
  return specs[slideIndex] || specs[1];
}

function transitionXml(slideIndex) {
  const spec = transitionSpec(slideIndex);
  return `<p:transition spd="med" advClick="1">${spec.xml}</p:transition>`;
}

function imageFilter(slideIndex) {
  const filters = {
    1: "fade",
    2: "wipe(right)",
    4: "wipe(left)",
    5: "wipe(up)",
    6: "fade",
    8: "wipe(right)",
    9: "wipe(left)",
    10: "wipe(up)",
    11: "fade",
    12: "wipe(right)",
    13: "wipe(up)",
    14: "wipe(left)",
    15: "wipe(right)",
    16: "fade",
    17: "wipe(up)",
    18: "wipe(left)",
    19: "fade",
  };
  return filters[slideIndex] || "fade";
}

function effectXml(target, ids, slideIndex) {
  const outer = ids.next++;
  const behavior = ids.next++;
  const isImage = target.kind === "image";
  const duration = isImage ? 960 : 880;
  const filter = isImage ? imageFilter(slideIndex) : "fade";
  return [
    "<p:par>",
    `<p:cTn id="${outer}" presetID="10" presetClass="entr" presetSubtype="0" fill="hold" grpId="0" nodeType="clickEffect">`,
    '<p:stCondLst><p:cond delay="0"/></p:stCondLst>',
    "<p:childTnLst>",
    `<p:animEffect transition="in" filter="${filter}">`,
    "<p:cBhvr>",
    `<p:cTn id="${behavior}" dur="${duration}" fill="hold"/>`,
    `<p:tgtEl><p:spTgt spid="${target.id}"/></p:tgtEl>`,
    "</p:cBhvr>",
    "</p:animEffect>",
    "</p:childTnLst>",
    "</p:cTn>",
    "</p:par>",
  ].join("");
}

function timingXml(targets) {
  if (!targets.length) return "";
  const ids = { next: 3 };
  const slideIndex = targets[0]?.slideIndex || 0;
  const effects = targets.map((target) => effectXml(target, ids, slideIndex)).join("");
  const builds = targets.map((target) => `<p:bldP spid="${target.id}" grpId="0"/>`).join("");
  return [
    "<p:timing>",
    "<p:tnLst>",
    "<p:par>",
    '<p:cTn id="1" dur="indefinite" restart="never" nodeType="tmRoot">',
    "<p:childTnLst>",
    '<p:seq concurrent="1" nextAc="seek">',
    '<p:cTn id="2" dur="indefinite" nodeType="mainSeq">',
    "<p:childTnLst>",
    effects,
    "</p:childTnLst>",
    '<p:prevCondLst><p:cond evt="onPrev" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:prevCondLst>',
    '<p:nextCondLst><p:cond evt="onNext" delay="0"><p:tgtEl><p:sldTgt/></p:tgtEl></p:cond></p:nextCondLst>',
    "</p:cTn>",
    "</p:seq>",
    "</p:childTnLst>",
    "</p:cTn>",
    "</p:par>",
    "</p:tnLst>",
    `<p:bldLst>${builds}</p:bldLst>`,
    "</p:timing>",
  ].join("");
}

function removeExistingMotion(xml) {
  return xml
    .replace(/<p:transition[\s\S]*?<\/p:transition>/g, "")
    .replace(/<p:timing>[\s\S]*?<\/p:timing>/g, "");
}

function injectMotion(xml, slideIndex, transitionsOnly) {
  const clean = removeExistingMotion(xml);
  const targets = transitionsOnly ? [] : extractMotionTargets(clean, slideIndex);
  const transition = transitionSpec(slideIndex);
  const motion = `${transitionXml(slideIndex)}${timingXml(targets)}`;
  return {
    xml: clean.replace("</p:sld>", `${motion}</p:sld>`),
    transition: transition.name,
    targetCount: targets.length,
    targets,
  };
}

function escapeXml(value) {
  return String(value)
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/"/g, "&quot;")
    .replace(/'/g, "&apos;");
}

function noteParagraphXml(text, index) {
  const isTarget = index === 0;
  const size = isTarget ? 1500 : 1250;
  const bold = isTarget ? ' b="1"' : "";
  return [
    "<a:p>",
    `<a:r><a:rPr lang="en-US" sz="${size}"${bold}/><a:t>${escapeXml(text)}</a:t></a:r>`,
    '<a:endParaRPr lang="en-US" dirty="0"/>',
    "</a:p>",
  ].join("");
}

function notesBodyXml(lines) {
  return [
    "<a:bodyPr/>",
    "<a:lstStyle/>",
    ...lines.map((line, index) => noteParagraphXml(line, index)),
  ].join("");
}

function injectSpeakerNoteXml(xml, lines) {
  const namespacedXml = /<p:notes[^>]*xmlns:a=/.test(xml)
    ? xml
    : xml.replace(
        /<p:notes([^>]*)>/,
        '<p:notes$1 xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main">',
      );
  const replacement = `$1${notesBodyXml(lines)}$2`;
  const updated = namespacedXml.replace(
    /(<p:sp><p:nvSpPr><p:cNvPr id="3" name="Notes Placeholder 2"[\s\S]*?<p:txBody>)[\s\S]*?(<\/p:txBody><\/p:sp>)/,
    replacement,
  );
  if (updated === namespacedXml) {
    throw new Error("Could not find notes placeholder body.");
  }
  return updated;
}

async function injectSpeakerNotes(workDir, slideCount) {
  const notesDir = path.join(workDir, "ppt", "notesSlides");
  let injected = 0;
  for (let index = 1; index <= slideCount; index += 1) {
    const lines = SPEAKER_NOTES[index];
    if (!lines) continue;
    const notesPath = path.join(notesDir, `notesSlide${index}.xml`);
    const xml = await fs.readFile(notesPath, "utf8");
    await fs.writeFile(notesPath, injectSpeakerNoteXml(xml, lines), "utf8");
    injected += 1;
  }
  return injected;
}

async function main() {
  const args = parseArgs(process.argv.slice(2));
  const input = path.resolve(requireArg(args, "input"));
  const output = path.resolve(args.output || input);
  const transitionsOnly = Boolean(args["transitions-only"]);
  const workDir = await fs.mkdtemp(path.join(os.tmpdir(), "smartcity-ppt-motion-"));
  const tempOutput = path.join(path.dirname(output), `.${path.basename(output)}.motion-tmp`);
  const summary = [];

  try {
    run("/usr/bin/unzip", ["-q", input, "-d", workDir]);
    const slidesDir = path.join(workDir, "ppt", "slides");
    const slideFiles = (await fs.readdir(slidesDir))
      .filter((file) => /^slide\d+\.xml$/.test(file))
      .sort((a, b) => slideNumber(a) - slideNumber(b));

    for (const file of slideFiles) {
      const index = slideNumber(file);
      const slidePath = path.join(slidesDir, file);
      const xml = await fs.readFile(slidePath, "utf8");
      const result = injectMotion(xml, index, transitionsOnly);
      await fs.writeFile(slidePath, result.xml, "utf8");
      summary.push({
        slide: index,
        transition: result.transition,
        targetCount: result.targetCount,
        targets: result.targets.map((target) => target.name),
      });
    }
    const notesInjected = await injectSpeakerNotes(workDir, slideFiles.length);

    await fs.rm(tempOutput, { force: true });
    run("/usr/bin/zip", ["-X", "-q", "-r", tempOutput, "."], { cwd: workDir });
    await fs.rename(tempOutput, output);
    console.log(JSON.stringify({ output, transitionsOnly, notesInjected, summary }, null, 2));
  } finally {
    await fs.rm(tempOutput, { force: true }).catch(() => {});
    await fs.rm(workDir, { recursive: true, force: true }).catch(() => {});
  }
}

main().catch((error) => {
  console.error(error.stack || error.message || String(error));
  process.exit(1);
});
