// Checks what the Omarchy plugin marketplace checks before it lists a plugin
// (omacom/omarchy-plugin-marketplace, scripts/build-catalog.mjs): the
// manifest's fields within their limits, a lowercase id outside omarchy.*,
// kinds it knows, entry points that are there, no links in the repository,
// and a README, a license and a preview at its root. And no text its
// security baseline reads as installing software or managing a service
// (scripts/security-baseline-analysis.mjs): Uber Notebook does neither.
// Usage (from the plugin directory): node tests/manifest.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { execFileSync } = require("node:child_process");
const { root } = require("./load.cjs");

let passed = 0;
function check(name, fn) { fn(); passed++; }

const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
const tracked = execFileSync("/usr/bin/git", ["-C", root, "ls-files", "-s", "-z"], { encoding: "utf8" })
  .split("\0").filter(Boolean).map((line) => { const [meta, file] = line.split("\t"); return { mode: meta.split(" ")[0], file }; });

check("the manifest's fields within the marketplace's limits", () => {
  assert.equal(manifest.schemaVersion, 1);
  const limits = { id: 128, name: 120, version: 64, author: 120, description: 500, license: 120 };
  for (const [field, max] of Object.entries(limits)) {
    assert.equal(typeof manifest[field], "string", field);
    assert.ok(manifest[field].length > 0 && manifest[field].length <= max, `${field}: ${manifest[field].length} of at most ${max}`);
    assert.equal(manifest[field], manifest[field].trim(), field);
    assert.ok(!/[\u0000-\u001f\u007f]/.test(manifest[field]), field + " has control characters");
  }
});

check("an id of its own: lowercase, not in omarchy.*", () => {
  assert.match(manifest.id, /^[a-z0-9][a-z0-9._-]*$/);
  assert.ok(!manifest.id.startsWith("omarchy."));
});

check("kinds it knows, entry points that are there", () => {
  const kinds = new Set(["bar", "bar-widget", "menu", "overlay", "panel", "service"]);
  assert.ok(Array.isArray(manifest.kinds) && manifest.kinds.length);
  for (const k of manifest.kinds) assert.ok(kinds.has(k), k);
  for (const entry of Object.values(manifest.entryPoints)) {
    assert.ok(!entry.startsWith("/") && !entry.includes(".."), entry);
    assert.ok(fs.statSync(path.join(root, entry)).isFile(), entry);
  }
  assert.ok(["left", "center", "right"].includes(manifest.barWidget.defaultSection));
});

check("no links in the repository; a README, a license and a preview at its root", () => {
  assert.deepEqual(tracked.filter((t) => t.mode === "120000").map((t) => t.file), []);
  const files = new Set(tracked.map((t) => t.file));
  for (const f of ["README.md", "LICENSE", "preview.png"]) assert.ok(files.has(f), f);
});

check("nothing that reads as installing software or managing a service", () => {
  // (The files the baseline reads: code, scripts and the root README, in
  // any folder but the ones it leaves out; it names a package, never a
  // command, and never manages a service.)
  const scanned = /\.(bash|cjs|desktop|fish|js|lua|mjs|pl|py|qml|rb|service|sh|sudoers|toml|ya?ml|zsh)$/i;
  const left = new Set([".github", "coverage", "docs", "fixtures", "node_modules", "spec", "specs", "test", "tests"]);
  const flagged = [
    /\bomarchy\s+pkg\s+(?:add|drop|remove|update)\b/i,
    /\b(?:pacman|paru|yay|apt|apt-get|dnf|zypper|apk)\s+(?:-[A-Za-z]*[SRU]|install|remove|upgrade|add|del)\b/i,
    /(?:^|[\s/'"])(?:pip|pip3|pipx)["']?\s+install\b/i,
    /\bpython[23]?(?:\.[0-9]+)?\s+-m\s+pip\s+install\b/i,
    /\b(?:npm|pnpm|yarn|bun)\s+(?:install|add)\b/i,
    /\b(?:cargo|go|gem)\s+install\b/i,
    /\bbrew\s+(?:install|uninstall|upgrade)\b/i,
    /\bsystemctl\b|\bsystemd-run\b/i,
  ];
  const found = [];
  for (const { file } of tracked) {
    const parts = file.toLowerCase().split("/");
    if (parts.slice(0, -1).some((d) => left.has(d))) continue;
    if (file !== "README.md" && !scanned.test(file) && parts[0] !== "bin") continue;
    fs.readFileSync(path.join(root, file), "utf8").split("\n").forEach((line, i) => {
      // (A comment in code isn't a command; the README's words are read.)
      if (file !== "README.md" && /^\s*(\/\/|#|\*|\/\*)/.test(line)) return;
      if (flagged.some((re) => re.test(line))) found.push(`${file}:${i + 1}`);
    });
  }
  assert.deepEqual(found, []);
});

console.log(`manifest: ${passed} checks passed`);
