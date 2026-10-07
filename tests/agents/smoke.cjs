#!/usr/bin/env node
// The real-agent smoke test: each installed agent (Grok, Claude Code) run for
// real, as the panel runs it (tests/agents/smoke.qml: the real Store,
// Workspace, Api and Agent.js, the same command, sandbox, folder and
// protocol), on notes in a folder made for the run, never yours, each
// question it asks answered "Allow once". The same tasks for each: read the
// skill, write a page, edit a block, put a picture on the page, search the
// web, a command that asks, a file from outside its folder. What's on the
// page is checked through Uber Notebook's commands; a pass/fail table, and
// a report (JSON) in /tmp.
//
// Each with the model and effort you chose for it (Settings → AI). It makes
// real requests on your accounts (a few cents a run). Not part of
// ./tests/run: run it before a release.
//
// Usage (from the plugin directory):
//   node tests/agents/smoke.cjs [grok] [claude] [codex] [--only <task>[,<task>...]] [--keep]

const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const crypto = require("node:crypto");
const { execFileSync, spawn } = require("node:child_process");

const root = path.resolve(__dirname, "..", "..");
const argv = process.argv.slice(2);
const keep = argv.includes("--keep");
const only = argv.includes("--only") ? String(argv[argv.indexOf("--only") + 1] || "").split(",") : [];
const ALL = ["grok", "claude", "codex"];
const agents = ALL.filter((a) => !argv.some((x) => ALL.includes(x)) || argv.includes(a));
const runtime = process.env.XDG_RUNTIME_DIR || `/run/user/${process.getuid()}`;
const rand = () => crypto.randomBytes(6).toString("hex");

// ---- the tasks ----------------------------------------------------------------------------------

const year = String(new Date().getFullYear());
const picture = ["/usr/share/pixmaps", "/usr/share/icons/hicolor/48x48/apps", "/usr/share/icons/hicolor/64x64/apps"]
  .flatMap((d) => { try { return fs.readdirSync(d).filter((f) => /\.png$/.test(f)).map((f) => path.join(d, f)); } catch { return []; } })
  .find((f) => /^[A-Za-z0-9._\/-]+$/.test(f) && fs.statSync(f).isFile());
const text = (blocks) => blocks.map((b) => String(b.text || "")).join("\n");
const has = (blocks, type, re) => blocks.some((b) => b.type === type && (!re || re.test(String(b.text || ""))));

const tasks = [
  { id: "skill", title: "Skill",
    ask: () => "Read the uber-notebook skill first. Then write one sentence on this page that names the command that adds a new page.",
    check: (b, r) => [r.steps.some((s) => /uber-notebook skill/i.test(s)) || "never read the skill", b.some((x) => String(x.text || "").trim()) || "nothing written"] },
  { id: "write", title: "Notes",
    ask: () => "Write on this page: a heading that says Bees, three bullet points about bees, and a to-do that says Buy honey.",
    check: (b) => [b.some((x) => /^h[123]$/.test(x.type) && /bees/i.test(x.text || "")) || "no heading", b.filter((x) => x.type === "bullet").length >= 3 || "fewer than three bullets", has(b, "check", /honey/i) || "no to-do"] },
  { id: "edit", title: "Draft", seed: "## Draft\n\nTeh quick brown fox jumps over the lazy dog.\n",
    ask: () => "Fix the spelling mistake in the paragraph on this page, changing only that block.",
    check: (b) => [has(b, "p", /The quick brown fox/) || "not fixed", !/Teh quick/.test(text(b)) || "the mistake's still there"] },
  { id: "picture", title: "A picture",
    ask: (agent) => agent === "grok" ? "Make a picture of a honeybee with your image tool and put it on this page."
      : "Draw a small SVG picture of a honeybee as a file in your working folder and put it on this page as a picture.",
    check: (b) => [b.some((x) => x.type === "image" || x.type === "gallery") || "no picture on the page"] },
  { id: "web", title: "Genome",
    ask: () => "Search the web for the year the honeybee genome was first published, and write that year on this page.",
    check: (b, r) => [r.steps.some((s) => /Searching the web|Reading [a-z0-9.-]+\.[a-z]{2,}/i.test(s)) || "never searched", /\b2006\b/.test(text(b)) || "no 2006 on the page"] },
  { id: "command", title: "Year",
    ask: () => "Run the shell command `date +%Y` and write the year it prints on this page.",
    check: (b) => [new RegExp(`\\b${year}\\b`).test(text(b)) || `no ${year} on the page`] },
  { id: "outside", title: "Outside",
    ask: () => `Put the picture ${picture} on this page.`,
    check: (b) => [b.some((x) => x.type === "image" || x.type === "gallery") || "no picture on the page: refused, and no way found round it"] },
].filter((t) => !only.length || only.includes(t.id));

// ---- the smoke test's Uber Notebook ------------------------------------------------------------

// Its commands: Service.qml's uber-notebook-agent ones, as they are there.
function handlers() {
  const lines = fs.readFileSync(path.join(root, "Service.qml"), "utf8").split("\n")
    .filter((l) => /^\s*function \w+\(.*\): string \{ return root\.scoped\(commands\.agent, "\w+", \[.*\], function\(\) \{ return (apiItem|root)\.\w+\(.*\}\) \}\s*$/.test(l));
  if (lines.length < 50 || !lines.some((l) => /function skill\(/.test(l))) throw new Error("Service.qml's commands weren't found");
  return lines.map((l) => "    " + l.trim().replace("root.scoped(commands.agent, ", "smoke.scoped(").replace(/apiItem\./g, "api.").replace(/root\./g, "smoke.")).join("\n");
}

// The models and efforts you chose for each (Settings → AI: shell.json),
// so each runs as it does for you.
function choices() {
  try {
    const find = (o) => !o || typeof o !== "object" ? null : o.id === "marcho78.uber-notebook" ? o : Object.values(o).map(find).find(Boolean) || null;
    const e = find(JSON.parse(fs.readFileSync(path.join(os.homedir(), ".config", "omarchy", "shell.json"), "utf8"))) || {};
    return Object.fromEntries(ALL.map((a) => [a, { model: String(e[a + "Model"] || ""), effort: String(e[a + "Effort"] || "") }]));
  } catch { return {}; }
}

// Your shell's PATH: agents found where Uber Notebook finds them.
function shellPath() {
  try {
    const pid = execFileSync("/usr/bin/pgrep", ["-f", "quickshell -n -p /usr/share/omarchy/shell"], { encoding: "utf8" }).trim().split("\n")[0];
    const env = fs.readFileSync(`/proc/${pid}/environ`, "utf8").split("\0");
    return (env.find((e) => e.startsWith("PATH=")) || "").slice(5) || process.env.PATH;
  } catch { return process.env.PATH; }
}

const work = fs.mkdtempSync(path.join(os.tmpdir(), "uber-notebook-smoke-"));
const base = path.join(runtime, "uber-notebook-smoke-" + rand());
fs.mkdirSync(path.join(work, "notes"), { recursive: true });
fs.mkdirSync(path.join(work, "shell"), { recursive: true });
fs.mkdirSync(base, { recursive: true, mode: 0o700 });
fs.writeFileSync(path.join(work, "shell", "shell.qml"), fs.readFileSync(path.join(__dirname, "smoke.qml"), "utf8")
  .replaceAll("@PLUGIN@", "file://" + root).replace("@HANDLERS@", handlers()));
const log = fs.openSync(path.join(work, "shell.log"), "w");
const shell = spawn("/usr/bin/quickshell", ["-p", path.join(work, "shell", "shell.qml")], {
  env: { ...process.env, PATH: shellPath(), QT_QPA_PLATFORM: "offscreen", SMOKE_NOTES: path.join(work, "notes"), SMOKE_RUNTIME: base,
    SMOKE_SKILL: path.join(root, "skills", "uber-notebook"), SMOKE_CHOICES: JSON.stringify(choices()) },
  stdio: ["ignore", log, log], detached: true,
});

function call(...args) {
  return execFileSync("/usr/bin/qs", ["ipc", "--pid", String(shell.pid), "call", "--", ...args], { encoding: "utf8", timeout: 20000 }).trim();
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(test, ms, every = 500) {
  const end = Date.now() + ms;
  while (Date.now() < end) {
    try { const v = test(); if (v) return v; } catch {}
    await sleep(every);
  }
  return null;
}

// ---- a run --------------------------------------------------------------------------------------

const dirs = [];
const t0run = Date.now();
async function run(agent, task) {
  const page = call("smoke", "newPage", task.title);
  if (!/^[0-9a-f-]{36}$/.test(page)) return { ok: false, why: ["no page made: " + page] };
  if (task.seed) {
    call("smoke", "seed", page, task.seed);
    if (!(await until(() => call("smoke", "seeded") === "true", 15000))) return { ok: false, why: ["the page couldn't be seeded"] };
  }
  const dirName = "c-" + rand();
  dirs.push(path.join(base, dirName));
  const started = call("smoke", "run", agent, page, task.ask(agent), dirName);
  if (started !== "started") return { ok: false, why: ["didn't start: " + started] };
  const t0 = Date.now();
  const st = await until(() => { const s = JSON.parse(call("smoke", "status")); return s.done ? s : null; }, 10 * 60 * 1000, 3000);
  if (!st) { try { call("smoke", "stop"); } catch {} return { ok: false, why: ["still going after 10 minutes"], seconds: 600 }; }
  let blocks = [];
  try { const b = JSON.parse(call("smoke", "blocks", page)); blocks = Array.isArray(b) ? b : b.blocks || []; } catch {}
  const why = task.check(blocks, st).filter((x) => x !== true);
  if (st.code !== 0 || st.failure) why.unshift(`ended ${st.code}${st.failure ? ": " + st.failure : ""}`);
  return { ok: why.length === 0, why, seconds: Math.round((Date.now() - t0) / 1000), steps: st.steps, asks: st.asks, answer: st.answer.slice(-600), blocks };
}

function cleanUp() {
  try { process.kill(-shell.pid, "SIGTERM"); } catch {}
  if (keep) { console.log(`kept: ${work} and ${base}`); return; }
  // (What the agents kept of these runs, and only that: their sessions for
  // these folders.)
  // (Codex keeps its sessions by date, not by folder: a run's is the one
  // whose first record, its session_meta, says it worked in one of the run's
  // folders (made for it, with a random name); nothing that only mentions
  // one.)
  const codexRoot = path.join(os.homedir(), ".codex", "sessions");
  const started = new Date(t0run);
  for (const day of [started, new Date()].map((d) => path.join(codexRoot, String(d.getFullYear()), String(d.getMonth() + 1).padStart(2, "0"), String(d.getDate()).padStart(2, "0")))) {
    let names = [];
    try { names = fs.readdirSync(day); } catch {}
    for (const n of names) {
      const f = path.join(day, n);
      try {
        if (!n.endsWith(".jsonl") || fs.statSync(f).mtimeMs < t0run) continue;
        const first = JSON.parse(fs.readFileSync(f, "utf8").split("\n", 1)[0]);
        if (first && first.type === "session_meta" && first.payload && dirs.includes(first.payload.cwd)) fs.rmSync(f, { force: true });
      } catch {}
    }
  }
  for (const d of dirs) {
    fs.rmSync(path.join(os.homedir(), ".grok", "sessions", encodeURIComponent(d)), { recursive: true, force: true });
    fs.rmSync(path.join(os.homedir(), ".claude", "projects", d.replace(/[^A-Za-z0-9]/g, "-")), { recursive: true, force: true });
  }
  fs.rmSync(work, { recursive: true, force: true });
  fs.rmSync(base, { recursive: true, force: true });
}

(async () => {
  const results = {};
  try {
    if (!(await until(() => call("smoke", "ready") === "true", 30000))) throw new Error("the smoke test's Uber Notebook didn't start: " + path.join(work, "shell.log"));
    for (const agent of agents) {
      results[agent] = {};
      for (const task of tasks) {
        process.stdout.write(`${agent} ${task.id} ... `);
        const r = await run(agent, task);
        results[agent][task.id] = r;
        console.log(r.ok ? `pass (${r.seconds}s)` : `FAIL (${r.seconds || 0}s): ${r.why.join("; ")}`);
      }
    }
  } catch (e) {
    console.error(e.message);
    process.exitCode = 2;
  } finally {
    const report = path.join(os.tmpdir(), "uber-notebook-smoke-report.json");
    fs.writeFileSync(report, JSON.stringify(results, null, 2));
    console.log("\n" + ["task".padEnd(10), ...agents.map((a) => a.padEnd(8))].join(" "));
    for (const task of tasks) console.log([task.id.padEnd(10), ...agents.map((a) => (results[a] && results[a][task.id] ? (results[a][task.id].ok ? "pass" : "FAIL") : "-").padEnd(8))].join(" "));
    console.log(`\nreport: ${report}`);
    if (Object.values(results).some((r) => Object.values(r).some((x) => !x.ok))) process.exitCode = 1;
    cleanUp();
  }
})();
