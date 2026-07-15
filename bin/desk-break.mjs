#!/usr/bin/env node
// desk-break — installer CLI for the macOS movement-break reminder.
//
// A thin, zero-dependency wrapper around the same install flow the Claude Code
// skill performs (see skills/health/desk-break/SKILL.md): it copies the
// runner + localized data into your home dir, writes a default config, and
// registers a per-user launchd agent. Runtime lives entirely in the installed
// shell script; this CLI only sets it up and forwards a few operations to it.
//
//   npx desk-break setup [--interval 30] [--locale auto|en|zh]
//                        [--style dialog|notification|say|dialog+say] [--no-music] [--dry-run]
//   npx desk-break test | stats | report "<what went wrong>"
//   npx desk-break enable | disable | uninstall [--purge]

import { spawnSync } from "node:child_process";
import {
  chmodSync,
  cpSync,
  existsSync,
  mkdirSync,
  readFileSync,
  readdirSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { homedir, userInfo } from "node:os";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const HERE = dirname(fileURLToPath(import.meta.url));
const PKG = JSON.parse(readFileSync(join(HERE, "..", "package.json"), "utf8"));
const SKILL_DIR = join(HERE, "..", "skills", "health", "desk-break");

const HOME = homedir();
const USER = userInfo().username;
const UID = process.getuid ? process.getuid() : null;
const LABEL = `com.${USER}.desk-break`;
const LEGACY_LABEL = `com.${USER}.exercise-reminder`;

const RUNNER = join(HOME, ".local", "bin", "desk-break.sh");
const CONFIG_DIR = join(HOME, ".config", "desk-break");
const CONFIG = join(CONFIG_DIR, "config.env");
const I18N_DST = join(CONFIG_DIR, "i18n");
const STATE_DIR = join(HOME, ".local", "share", "desk-break");
const PLIST = join(HOME, "Library", "LaunchAgents", `${LABEL}.plist`);

// ---- tiny arg parsing -------------------------------------------------------
const argv = process.argv.slice(2);
let cmd = argv[0] && !argv[0].startsWith("-") ? argv.shift() : "";
const flags = new Map();
const rest = [];
for (let i = 0; i < argv.length; i++) {
  const a = argv[i];
  if (a === "--no-music") flags.set("music", "0");
  else if (a === "--dry-run") flags.set("dry-run", true);
  else if (a === "--purge") flags.set("purge", true);
  else if (a.startsWith("--")) {
    const key = a.slice(2);
    const val = argv[i + 1] && !argv[i + 1].startsWith("--") ? argv[++i] : true;
    flags.set(key, val);
  } else rest.push(a);
}
const DRY = flags.get("dry-run");

// ---- helpers ----------------------------------------------------------------
const c = { dim: (s) => `\x1b[2m${s}\x1b[0m`, b: (s) => `\x1b[1m${s}\x1b[0m` };
function say(msg) {
  console.log(msg);
}
function act(msg) {
  console.log(`${DRY ? c.dim("[dry-run] ") : ""}${msg}`);
}
function die(msg, code = 1) {
  console.error(msg);
  process.exit(code);
}
function requireDarwin() {
  if (process.platform !== "darwin") {
    die(
      "desk-break is macOS-only (it uses launchd, ioreg, osascript, say).\n" +
        `Detected platform: ${process.platform}. Nothing was installed.`,
    );
  }
}
// launchctl: capture, tolerate failure (bootout of a not-loaded agent errors)
function launchctl(args) {
  act(`launchctl ${args.join(" ")}`);
  if (DRY) return { status: 0 };
  return spawnSync("launchctl", args, { encoding: "utf8" });
}
// forward to the installed runner, inheriting stdio
function runner(args) {
  if (!existsSync(RUNNER)) {
    die(
      `desk-break isn't installed yet — run:\n  npx desk-break setup`,
    );
  }
  const r = spawnSync("/bin/bash", [RUNNER, ...args], { stdio: "inherit" });
  process.exit(r.status ?? 0);
}

// ---- plist ------------------------------------------------------------------
function plistXml(intervalSeconds) {
  const path = `${HOME}/.local/bin/desk-break.sh`;
  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>${LABEL}</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>${path}</string>
    </array>
    <key>StartInterval</key>
    <integer>${intervalSeconds}</integer>
    <key>RunAtLoad</key>
    <false/>
    <key>EnvironmentVariables</key>
    <dict>
        <key>PATH</key>
        <string>${HOME}/.local/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
    </dict>
    <key>StandardOutPath</key>
    <string>${STATE_DIR}/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${STATE_DIR}/stderr.log</string>
</dict>
</plist>
`;
}

function defaultConfig({ locale, style, music }) {
  return `# desk-break config — edit freely; applies on the next fire.
# (Interval changes need re-running \`desk-break setup\`.) Full reference: SKILL.md.
LOCALE=${locale}
REMINDER_STYLE=${style}
ENABLE_MUSIC=${music}
MOOD=energetic
PERSONA=random
TIME_ADAPTIVE=1
NIGHT_MODE=1
TRACK_STATS=1
`;
}

// recursive copy that never overwrites an existing destination file (like cp -Rn)
function copyNoClobber(src, dst) {
  for (const entry of readdirSync(src, { withFileTypes: true })) {
    const s = join(src, entry.name);
    const d = join(dst, entry.name);
    if (entry.isDirectory()) {
      if (!DRY) mkdirSync(d, { recursive: true });
      copyNoClobber(s, d);
    } else if (!existsSync(d)) {
      act(`copy ${entry.name} -> ${d.replace(HOME, "~")}`);
      if (!DRY) cpSync(s, d);
    }
  }
}

function ensureDir(p) {
  act(`mkdir -p ${p.replace(HOME, "~")}`);
  if (!DRY) mkdirSync(p, { recursive: true });
}

// ---- commands ---------------------------------------------------------------
function setup() {
  requireDarwin();
  if (!existsSync(SKILL_DIR)) {
    die(`Bundled skill not found at ${SKILL_DIR} — is the package intact?`);
  }
  const interval = Math.max(1, parseInt(flags.get("interval") || "30", 10) || 30);
  const locale = String(flags.get("locale") || "auto");
  const style = String(flags.get("style") || "dialog");
  const music = flags.get("music") === "0" ? "0" : "1";

  say(c.b("desk-break setup") + (DRY ? c.dim("  (dry run — nothing will change)") : ""));

  // 1. runner
  ensureDir(dirname(RUNNER));
  act(`install runner -> ${RUNNER.replace(HOME, "~")}`);
  if (!DRY) {
    cpSync(join(SKILL_DIR, "reminder.sh"), RUNNER);
    chmodSync(RUNNER, 0o755);
  }

  // 2. localized data (never clobber user edits)
  ensureDir(I18N_DST);
  copyNoClobber(join(SKILL_DIR, "i18n"), I18N_DST);

  // 3. config (only if missing)
  ensureDir(STATE_DIR);
  if (existsSync(CONFIG)) {
    act(`config exists, keeping ${CONFIG.replace(HOME, "~")}`);
  } else {
    act(`write ${CONFIG.replace(HOME, "~")} (locale=${locale}, style=${style}, music=${music})`);
    if (!DRY) writeFileSync(CONFIG, defaultConfig({ locale, style, music }));
  }

  // 4. launchd plist
  ensureDir(dirname(PLIST));
  act(`write ${PLIST.replace(HOME, "~")} (every ${interval} min)`);
  if (!DRY) writeFileSync(PLIST, plistXml(interval * 60));

  // 5. (re)load, deduping any stale/legacy agent
  if (UID != null) {
    launchctl(["bootout", `gui/${UID}/${LABEL}`]);
    launchctl(["bootout", `gui/${UID}/${LEGACY_LABEL}`]);
    launchctl(["bootstrap", `gui/${UID}`, PLIST]);
  }

  // 6. verify
  if (!DRY) {
    say(c.dim("\nRunning a quick test fire…"));
    spawnSync("/bin/bash", [RUNNER, "--test"], { stdio: "inherit" });
  }

  say("");
  say(c.b("✅ desk-break is set up.") + ` Reminders fire every ${interval} min.`);
  say("Next:");
  say(`  ${c.b("npx desk-break test")}     fire once now (no stats change)`);
  say(`  ${c.b("npx desk-break stats")}    streak + last 7 days`);
  say(`  ${c.b("npx desk-break disable")}  pause   ·  ${c.b("enable")} to resume`);
  say(c.dim(`Config: ${CONFIG.replace(HOME, "~")}   ·   Data: ${I18N_DST.replace(HOME, "~")}/<lang>/`));
}

function enable() {
  requireDarwin();
  if (!existsSync(PLIST)) die(`No agent found at ${PLIST.replace(HOME, "~")} — run \`npx desk-break setup\` first.`);
  if (UID != null) launchctl(["bootstrap", `gui/${UID}`, PLIST]);
  say("desk-break enabled.");
}

function disable() {
  requireDarwin();
  if (UID != null) launchctl(["bootout", `gui/${UID}/${LABEL}`]);
  say("desk-break disabled (files kept). Re-enable with `npx desk-break enable`.");
}

function uninstall() {
  requireDarwin();
  if (UID != null) launchctl(["bootout", `gui/${UID}/${LABEL}`]);
  for (const p of [PLIST, RUNNER]) {
    act(`rm ${p.replace(HOME, "~")}`);
    if (!DRY) rmSync(p, { force: true });
  }
  if (flags.get("purge")) {
    for (const d of [CONFIG_DIR, STATE_DIR]) {
      act(`rm -rf ${d.replace(HOME, "~")}`);
      if (!DRY) rmSync(d, { recursive: true, force: true });
    }
    say("desk-break fully removed (config + stats purged).");
  } else {
    say("desk-break removed. Config + stats kept — add --purge to delete them too.");
  }
}

function help() {
  say(`${c.b("desk-break")} ${PKG.version} — macOS movement-break reminder

${c.b("Usage")}
  npx desk-break setup [options]   install runner + i18n, write config, register launchd
  npx desk-break test              fire once now (~8s dry-run; no stats change)
  npx desk-break stats             streak, completion rate, last 7 days
  npx desk-break report "<msg>"    open a pre-filled problem-report email
  npx desk-break enable | disable  resume / pause the reminder
  npx desk-break uninstall [--purge]  remove the agent (+ config/stats with --purge)

${c.b("setup options")}
  --interval <min>   minutes between reminders (default 30)
  --locale <v>       auto | en | zh (default auto)
  --style <v>        dialog | notification | say | dialog+say (default dialog)
  --no-music         don't play workout music
  --dry-run          print what would happen, change nothing

macOS only. Music needs music-cli (https://github.com/luongnv89/music-cli); without
it reminders still fire, music is skipped. Docs: ${PKG.homepage}`);
}

// ---- dispatch ---------------------------------------------------------------
if (flags.get("version") || cmd === "version") { say(PKG.version); process.exit(0); }
if (flags.get("help") || cmd === "help") { help(); process.exit(0); }

switch (cmd) {
  case "":
  case "setup":
  case "install":
    setup();
    break;
  case "test":
    runner(["--test"]);
    break;
  case "stats":
    runner(["--stats"]);
    break;
  case "report":
    runner(["--report", ...(rest.length ? [rest.join(" ")] : [""])]);
    break;
  case "enable":
    enable();
    break;
  case "disable":
    disable();
    break;
  case "uninstall":
    uninstall();
    break;
  default:
    die(`Unknown command: ${cmd}\nRun \`npx desk-break --help\` for usage.`);
}
