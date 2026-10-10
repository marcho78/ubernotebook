// Checks Help.js against the code, so Help can't go out of date: every "/"
// command, every command from a terminal, every Ctrl key the views handle
// is in it; nothing in it is an internal note (a file, a line number); and
// its search finds what it should.
// Usage (from the plugin directory): node tests/help.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { load, root } = require("./load.cjs");

const Help = load("Help.js");
const Docs = load("Docs.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const rows = [];
Help.SECTIONS.forEach((s) => s.groups.forEach((g) => g.rows.forEach((r) => rows.push({ s: s.id, g: g.title, r }))));
const all = rows.map((x) => x.r.join(" ")).join("\n");
const read = (f) => fs.readFileSync(path.join(root, f), "utf8");

check("its shape: sections, each with groups of rows of three words", () => {
  assert.ok(Help.SECTIONS.length >= 10);
  const ids = Help.SECTIONS.map((s) => s.id);
  assert.equal(new Set(ids).size, ids.length, "each section once");
  assert.equal(ids[0], "start");
  for (const x of rows) {
    assert.equal(x.r.length, 3, x.s + ": " + JSON.stringify(x.r));
    for (const t of x.r) assert.equal(typeof t, "string");
    assert.ok(x.r[0].trim() && x.r[1].trim(), x.s + ": something to do and what it does");
  }
  assert.equal(Help.count(), rows.length);
});

check("only words for you: no files, line numbers or notes for whoever wrote it", () => {
  for (const x of rows) {
    const t = x.r.join(" ");
    assert.ok(!/\w+\.(qml|js|py)\b|(^|\s):\d{2,}|README|PROBABLE|\bverify\b|\bin the code too\b|\bwhich the code\b|\bdraft\b|\bthe editor never\b/i.test(t), x.s + ": " + t.slice(0, 160));
  }
});

check("every / command is in it", () => {
  const ids = Docs.findCommands("").map((c) => c.id);
  assert.ok(ids.length > 40);
  const blocks = rows.filter((x) => x.s === "blocks").map((x) => x.r.join(" ")).join("\n");
  for (const id of ids) assert.ok(new RegExp("/" + id + "\\b").test(blocks), "/" + id);
});

check("every command from a terminal is in it", () => {
  const terminal = rows.filter((x) => x.s === "terminal").map((x) => x.r[0]).join("\n");
  // Api.qml's help(): { use: "name ..." }.
  const api = [...read("Api.qml").matchAll(/\{ use: "([A-Za-z]+)/g)].map((m) => m[1]);
  // Service.qml's own: function name(...) in the IpcHandler.
  const svc = read("Service.qml");
  // (Its handler's own functions, 8 deep: not Service's own below it.)
  const ipc = svc.slice(svc.indexOf("readonly property IpcHandler handler"));
  const own = [...ipc.matchAll(/\n {8}function ([a-z][A-Za-z]*)\(/g)].map((m) => m[1]);
  assert.ok(api.length > 30 && own.length > 10, api.length + " " + own.length);
  const missing = [...new Set(api.concat(own))].filter((c) => !new RegExp("uber-notebook " + c + "\\b").test(terminal));
  assert.deepEqual(missing, [], "commands not in Help");
});

// The Ctrl keys the views handle (App.qml's, Pages' handleKey, the
// editor's), each said in Help as it's pressed.
check("every Ctrl key the views handle is in it", () => {
  const names = { Comma: ",", Period: ".", Slash: "/", Backslash: "\\", Left: "←", Right: "→", Up: "↑", Down: "↓", Return: "Enter", Enter: "Enter",
    Plus: "+", Equal: "=", Minus: "-", Greater: ">", Less: "<", Question: "?", Space: "Space", Tab: "Tab", Home: "Home", End: "End",
    0: "0", 1: "1", 2: "2", 3: "3", 4: "4", 5: "5", 6: "6", 7: "7", 8: "8", 9: "9" };
  const files = ["app/App.qml", "app/DocView.qml", "app/Editor.qml"];
  const missing = [];
  for (const f of files) {
    for (const line of read(f).split("\n")) {
      // (A line about Ctrl held, not one that wants it not held.)
      if (!/\bctrl\b/.test(line) || /!ctrl/.test(line)) continue;
      const alt = /\balt\b/.test(line) && !/!alt/.test(line);
      const shift = /\bshift\b/.test(line) && !/!shift/.test(line);
      // (A range of keys, key >= Qt.Key_0 && key <= Qt.Key_3: said by its first.)
      const keys = /Qt\.Key_\w+\s*&&\s*key\s*<=/.test(line) ? [line.match(/>=\s*Qt\.Key_(\w+)/)[1]] : [...line.matchAll(/Qt\.Key_([A-Za-z0-9]+)/g)].map((m) => m[1]);
      for (const name of keys) {
        const k = names[name] || (name.length === 1 ? name : null);
        if (!k) continue;
        const want = "Ctrl+" + (alt ? "Alt+" : "") + (shift ? "Shift+" : "") + k;
        const plain = "Ctrl+" + (alt ? "Alt+" : "") + k;
        if (all.indexOf(want) < 0 && all.indexOf(plain) < 0) missing.push(f + ": " + want);
      }
    }
  }
  assert.deepEqual([...new Set(missing)], [], "keys not in Help");
});

check("what it says is so: Ctrl+Shift+X never cuts; not only the update check goes online", () => {
  for (const x of rows) {
    const t = x.r.join(" ");
    if (/Ctrl\+Shift\+X/.test(t)) assert.ok(!/Ctrl\+Shift\+X (cuts|does the same)|cuts the blocks instead/i.test(t), t);
    assert.ok(!/Nothing leaves your computer/i.test(t), t);
  }
});

check("Help's own keys are in it, and New page", () => {
  assert.ok(/Ctrl\+\//.test(all), "Ctrl+/");
  assert.ok(/F1/.test(all), "F1");
  assert.ok(rows.some((x) => x.s === "start" && /New page/.test(x.r[0])));
});

check("the skill and reminder details, where Settings and the panel name them", () => {
  const where = { "Enable Uber Notebook skill": "Settings → AI → ", "Show reminder details in notifications": "Settings → Notifications → " };
  for (const label of Object.keys(where)) {
    assert.ok(rows.some((x) => x.s === "settings" && x.r[0].indexOf(where[label] + label) === 0), label);
    assert.ok(read("app/SettingsPanel.qml").indexOf('label: "' + label + '"') >= 0, "Settings: " + label);
    assert.ok(read("app/SetupPanel.qml").indexOf('label: "' + label + '"') >= 0, "the panel: " + label);
  }
  assert.ok(/set agentSkill true\|false/.test(all) && /set reminderWords true\|false/.test(all));
  assert.ok(!/Show what reminders say|Settings → Writing → Times → Show|Settings → Privacy/.test(all), "not where it was");
});

check("found: every word, any case; nothing for no words", () => {
  assert.equal(Help.find("").length, 0);
  assert.equal(Help.find("   ").length, 0);
  const r = Help.find("REMIND me");
  assert.ok(r.length > 3);
  // (Each with both words, in its row, its group or its section's name.)
  const label = (id) => Help.SECTIONS.filter((s) => s.id === id)[0].label;
  for (const f of r) {
    const text = (f.row.join(" ") + " " + f.group + " " + label(f.section)).toLowerCase();
    assert.ok(text.includes("remind") && text.includes("me"), text.slice(0, 120));
  }
  assert.ok(Help.find("ctrl+shift+x").some((f) => /Strikethrough/i.test(f.row[1])));
  assert.equal(Help.find("zzzz-nothing-like-it").length, 0);
});

console.log(`help: ${passed} checks passed`);
