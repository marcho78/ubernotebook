// Checks settings validation, the shortcuts and their conflicts, the folder,
// and the path to hypr/omanote.lua and back.
// Usage (from the plugin directory): node tests/settings.test.cjs

const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const path = require("node:path");
const { load, plain, root } = require("./load.cjs");

const Settings = load("Settings.js");
const Defaults = load("Defaults.js");
const defaults = plain(Defaults.DEFAULTS);
const schema = plain(Defaults.SCHEMA);
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("defaults are valid and complete", () => {
  assert.deepEqual(plain(Settings.merge(defaults, defaults, schema)), defaults);
  assert.deepEqual(Object.keys(schema.types).sort(), Object.keys(defaults).sort());
  for (const key of Object.keys(schema.choices)) {
    assert.ok(schema.choices[key].includes(defaults[key]), key + " default is one of its choices");
  }
});

check("merging validates", () => {
  const merged = plain(Settings.merge(defaults, {
    paper: "grid", pen: "comic-sans", sounds: "yes", width: 800.5, height: 100, zoom: 999,
    shortcut: "super + j", folder: "~/Notes/", lastNotebook: "work-3f9a", unknown: 1, quickTo: "desk"
  }, schema));
  assert.equal(merged.quickTo, "notebook", "quick notes go to a notebook or Pages, nowhere else");
  assert.equal(plain(Settings.merge(defaults, { quickTo: "pages" }, schema)).quickTo, "pages");
  assert.equal(merged.paper, "grid");
  assert.equal(merged.pen, "sans", "not a choice");
  assert.equal(merged.sounds, true, "not a boolean");
  assert.equal(merged.width, defaults.width, "not an integer");
  assert.equal(merged.height, 480, "clamped to the smallest");
  assert.equal(merged.zoom, 200, "clamped to the largest");
  assert.equal(merged.shortcut, "SUPER + J");
  assert.equal(merged.folder, "~/Notes");
  assert.equal(merged.lastNotebook, "work-3f9a");
  assert.equal(merged.unknown, undefined);
  assert.deepEqual(plain(Settings.overrides(defaults, merged)), {
    paper: "grid", height: 480, zoom: 200, shortcut: "SUPER + J", folder: "~/Notes", lastNotebook: "work-3f9a"
  });
});

check("folders", () => {
  assert.equal(Settings.cleanFolder(""), "");
  assert.equal(Settings.cleanFolder("/home/u/Notes//x/"), "/home/u/Notes/x");
  assert.equal(Settings.cleanFolder("~/Notes"), "~/Notes");
  for (const bad of ["Notes", "../etc", "/home/u/../etc", "/a\nb", "~user/x", 42, null]) {
    assert.equal(Settings.cleanFolder(bad), null, JSON.stringify(bad));
  }
  assert.equal(Settings.resolveFolder("", "/home/u", true), "/home/u/Documents/Omanote");
  assert.equal(Settings.resolveFolder("", "/home/u", false), "/home/u/Omanote");
  assert.equal(Settings.resolveFolder("~/Notes", "/home/u", true), "/home/u/Notes");
  assert.equal(Settings.resolveFolder("/srv/notes", "/home/u", true), "/srv/notes");
  assert.equal(Settings.resolveFolder("relative", "/home/u", true), "/home/u/Documents/Omanote", "bad folders fall back");
  assert.equal(plain(Settings.merge(defaults, { lastNotebook: "../x" }, schema)).lastNotebook, "", "ids are plain");
});

check("shortcuts", () => {
  assert.equal(Settings.parseShortcut("super + n").text, "SUPER + N");
  assert.equal(Settings.parseShortcut("super + n").modmask, 64);
  assert.equal(Settings.parseShortcut("Alt + Super + n").text, "SUPER + ALT + N", "modifiers in canonical order");
  assert.equal(Settings.parseShortcut("").empty, true);
  for (const bad of ["SUPER +", "+ N", "SUPER + SUPER + N", "HYPER + N", "SUPER + N; rm", 42, null]) {
    assert.equal(Settings.parseShortcut(bad), null, JSON.stringify(bad));
  }
  assert.equal(Settings.shortcutLabel("SUPER + ALT + N"), "Super + Alt + N");
  assert.equal(Settings.shortcutLabel("CTRL + SPACE"), "Ctrl + Space");
  assert.match(Settings.shortcutProblem("N"), /modifier/);
  assert.equal(Settings.shortcutProblem("F7"), "", "function keys work alone");
  assert.equal(plain(Settings.merge(defaults, { shortcut: "N" }, schema)).shortcut, defaults.shortcut, "a bare key is refused");
  assert.equal(plain(Settings.merge(defaults, { shortcut: "" }, schema)).shortcut, "", "no shortcut at all is fine");
});

check("wanted binds and conflicts", () => {
  const wanted = plain(Settings.wantedBinds(defaults));
  assert.deepEqual(wanted.map((b) => [b.keys, b.event]), [["SUPER + N", "toggle"], ["SUPER + ALT + N", "quick"]]);
  assert.equal(Settings.wantedBinds(Object.assign({}, defaults, { quickShortcut: "SUPER + N" })).length, 1, "one key, one action");
  assert.equal(Settings.wantedBinds(Object.assign({}, defaults, { shortcut: "", quickShortcut: "" })).length, 0);

  const hypr = [
    { modmask: 72, key: "n", description: "Something of yours" },
    { modmask: 64, key: "N", description: "Open or close the notebook (Omanote)" },
    { modmask: 64, key: "N", description: "Ours, in a submap", submap: "resize" },
  ];
  const checked = plain(Settings.checkBinds(wanted, hypr));
  assert.deepEqual(checked.free.map((b) => b.event), ["toggle"], "our own earlier bind doesn't count, nor a submap's");
  assert.equal(checked.taken[0].event, "quick");
  assert.equal(checked.taken[0].usedBy, "Something of yours");

  const unknown = plain(Settings.checkBinds(wanted, null));
  assert.equal(unknown.free.length, 0, "when the binds can't be read, nothing is taken for free");
  assert.ok(unknown.taken.every((b) => b.unknown));
});

check("hyprland options", () => {
  const options = plain(Settings.hyprOptions(plain(Settings.wantedBinds(defaults)), defaults));
  assert.deepEqual(options.window, { floating: true, width: 1320, height: 900 });
  assert.equal(options.binds[0].description, "Open or close the notebook (Omanote)");
  const odd = plain(Settings.hyprOptions([{ keys: "SUPER + N; x", event: "toggle", description: "" }, { keys: "SUPER + N", event: "exec", description: "" }], { floating: false, width: 1e9, height: 12 }));
  assert.equal(odd.binds.length, 0, "only plain keys and known events");
  assert.deepEqual(odd.window, { floating: false, width: 5000, height: 480 });
});

check("lua literals", () => {
  assert.equal(Settings.luaLiteral({ a: 1, b: "x\"y", c: [true, null], "bad key": 2 }), '{a = 1, b = "x\\"y", c = {true, nil}}');
  assert.equal(Settings.luaString("é"), '"\\195\\169"');
  assert.equal(Settings.luaString("a\nb"), '"a\\010b"');
});

check("the registration runs in lua", () => {
  // The same text the service hands `hyprctl eval`, against the fake hl.
  const options = Settings.hyprOptions(Settings.wantedBinds(defaults), defaults);
  const code = Settings.hyprRegistration(path.join(root, "hypr/omanote.lua"), options);
  const script = 'package.path = "' + path.join(root, "tests") + '/?.lua;" .. package.path\n'
    + 'local fake = require("fake_hl")\n'
    + 'local result = (function() ' + code + ' end)()\n'
    + 'io.write(result, " ", #fake.active_binds(), " ", #fake.enabled_rules())';
  const out = execFileSync("lua", ["-e", script], { encoding: "utf8" });
  assert.equal(out, "ok 2 4");
});

check("events", () => {
  assert.deepEqual(plain(Settings.parseEvent("marcho78.omanote|toggle")), { type: "command", command: "toggle" });
  assert.deepEqual(plain(Settings.parseEvent("marcho78.omanote|quick")), { type: "command", command: "quick" });
  assert.equal(Settings.parseEvent("marcho78.omanote|exec"), null);
  assert.equal(Settings.parseEvent("someone-else|toggle"), null);
  assert.equal(Settings.parseEvent("marcho78.omanote|toggle" + "x".repeat(80)), null);
});

check("the entry in the bar", () => {
  const bar = { layout: { left: [], right: [{ id: "omarchy.clock" }, { id: "marcho78.omanote", paper: "grid" }] } };
  assert.deepEqual(plain(Settings.entryInBar(bar, "marcho78.omanote")), { paper: "grid" });
  assert.deepEqual(plain(Settings.entryInBar(null, "marcho78.omanote")), {});
});

check("the app launcher entry, with its icon", () => {
  const fs = require("node:fs");
  const os = require("node:os");
  const entry = Settings.desktopEntry("/home/u/.config/omarchy/plugins/marcho78.omanote");
  assert.match(entry, /^\[Desktop Entry\]\n/);
  assert.match(entry, /\nName=Omanote\n/);
  assert.match(entry, /\nExec=\/usr\/bin\/omarchy-shell omanote show\n/);
  assert.match(entry, /\nIcon=\/home\/u\/\.config\/omarchy\/plugins\/marcho78\.omanote\/icon\.svg\n/);
  assert.equal(Settings.desktopEntry("relative/dir"), "", "only an absolute folder");
  assert.equal(Settings.desktopEntry("/a\nExec=evil"), "", "no line breaks sneaking in keys");
  assert.match(Settings.desktopEntry("/odd\\dir"), /Icon=\/odd\\\\dir\/icon\.svg/, "backslashes escaped");
  // The icon it points at ships with the plugin.
  const svg = fs.readFileSync(path.join(root, "icon.svg"), "utf8");
  assert.match(svg, /^<svg [^>]*xmlns="http:\/\/www\.w3\.org\/2000\/svg"/);
  // And the desktop's own checker is happy with it, where it's installed.
  if (fs.existsSync("/usr/bin/desktop-file-validate")) {
    const file = path.join(fs.mkdtempSync(path.join(os.tmpdir(), "omanote-")), "marcho78-omanote.desktop");
    fs.writeFileSync(file, Settings.desktopEntry(root));
    const out = execFileSync("/usr/bin/desktop-file-validate", [file], { encoding: "utf8" });
    assert.equal(out.trim(), "", "desktop-file-validate: " + out);
  }
});

console.log(`settings: ${passed} checks passed`);
