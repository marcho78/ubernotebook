// Checks what you've let agents have done for them without asking
// (Permissions.js), and that settings keep only that.
// Usage (from the plugin directory): node tests/permissions.test.cjs

const assert = require("node:assert/strict");
const { load } = require("./load.cjs");

const P = load("Permissions.js");
const Settings = load("Settings.js");
const Defaults = load("Defaults.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }
const plain = (v) => JSON.parse(JSON.stringify(v));

check("a site: its exact name, from an https link only", () => {
  assert.equal(P.hostOf("https://Docs.Example.com/a?b#c"), "docs.example.com");
  assert.equal(P.hostOf("https://example.com"), "example.com");
  assert.equal(P.hostOf("https://example.com:443/x"), "example.com");
  for (const u of ["http://example.com/", "https://user@example.com/", "https://example.com:8443/", "https://localhost/", "ftp://example.com", "https://exa mple.com/", "javascript:x"]) {
    assert.equal(P.hostOf(u), "", u);
  }
});

check("Always: remembered for that agent, that site; taken back", () => {
  let list = P.withAllowed([], "claude", "contact", "example.com");
  assert.equal(P.allowed(list, "claude", "contact", "example.com"), true);
  assert.equal(P.allowed(list, "grok", "contact", "example.com"), false, "not another agent");
  assert.equal(P.allowed(list, "claude", "contact", "docs.example.com"), false, "not another site, even one under it");
  assert.equal(P.allowed(list, "claude", "contact", "evil-example.com"), false);
  list = P.withAllowed(list, "claude", "contact", "example.com");
  assert.equal(list.length, 1, "once");
  list = P.without(list, "claude", "contact", "example.com");
  assert.equal(P.allowed(list, "claude", "contact", "example.com"), false);
});

check("only what makes sense is kept", () => {
  const list = P.clean([{ agent: "claude", action: "contact", target: "Example.COM" }, { agent: "someone", action: "contact", target: "a.com" },
    { agent: "grok", action: "shell", target: "x" }, { agent: "codex", action: "contact", target: "not a site" }, null, "x",
    { agent: "claude", action: "contact", target: "example.com" }]);
  assert.deepEqual(plain(list), [{ agent: "claude", action: "contact", target: "example.com" }]);
  assert.equal(P.clean(Array.from({ length: 500 }, (_, i) => ({ agent: "claude", action: "contact", target: "s" + i + ".com" }))).length, P.MAX);
});

check("what else Always can be for: searching, a connector's tool, trashing pages, any command (Settings)", () => {
  let list = P.withAllowed([], "claude", "search", "web");
  list = P.withAllowed(list, "claude", "tool", "mcp__figma__get_screenshot");
  list = P.withAllowed(list, "grok", "trash", "pages");
  list = P.withAllowed(list, "claude", "shell", "any");
  assert.equal(list.length, 4);
  assert.equal(P.allowed(list, "grok", "trash", "pages"), true);
  assert.equal(P.allowed(list, "claude", "trash", "pages"), false, "not another agent");
  assert.equal(P.allowed(list, "grok", "shell", "any"), false);
  assert.deepEqual(plain(P.clean([{ agent: "claude", action: "search", target: "everything" }, { agent: "claude", action: "tool", target: "rm" },
    { agent: "claude", action: "trash", target: "everything" }, { agent: "claude", action: "shell", target: "git" }])), [], "nothing that isn't one of them");
  assert.deepEqual(plain(P.describe({ agent: "claude", action: "shell", target: "any" })), { label: "Any command", note: "Claude Code may run any command without asking: through one, it can read any file you can and reach any site" });
  assert.deepEqual(plain(P.describe({ agent: "grok", action: "trash", target: "pages" })).label, "Trashing pages");
});

check("a program allowed by its name, from before: dropped (git or make run what their folder says)", () => {
  assert.deepEqual(plain(P.clean([{ agent: "claude", action: "command", target: "git" }, { agent: "claude", action: "contact", target: "example.com" }])),
    [{ agent: "claude", action: "contact", target: "example.com" }]);
  assert.equal(P.allowed([{ agent: "claude", action: "command", target: "git" }], "claude", "command", "git"), false);
});

check("in settings: a list of them, anything else dropped", () => {
  const merged = Settings.merge(Defaults.DEFAULTS, { agentPermissions: [{ agent: "grok", action: "contact", target: "x.org" }, { agent: "grok", action: "rm", target: "/" }] }, Defaults.SCHEMA);
  assert.deepEqual(plain(merged.agentPermissions), [{ agent: "grok", action: "contact", target: "x.org" }]);
  assert.deepEqual(plain(Settings.merge(Defaults.DEFAULTS, { agentPermissions: "claude contact x.org" }, Defaults.SCHEMA).agentPermissions), [], "not from a string (`set`)");
  assert.deepEqual(plain(Settings.merge(Defaults.DEFAULTS, {}, Defaults.SCHEMA).agentPermissions), [], "none at first: everything asked");
});

check("files from a folder you've said Always to: that folder and the ones in it, never a hidden one", () => {
  assert.equal(P.cleanFolder("/home/me/Pictures"), "/home/me/Pictures");
  for (const f of ["/", "/home", "/home/me/.ssh", "/home/me/.config/x", "/home/me/Pictures/", "relative/x", "/home/me/a\u0000b", "/home//me"]) {
    assert.equal(P.cleanFolder(f), "", f);
  }
  assert.equal(P.folderOf("/home/me/Pictures/a.png"), "/home/me/Pictures");
  assert.equal(P.folderOf("/home/me/../.ssh/id"), "", "no ..");
  const list = P.withAllowed([], "grok", "files", "/home/me/Pictures");
  assert.equal(JSON.stringify(list.map((r) => [r.agent, r.action, r.target])), JSON.stringify([["grok", "files", "/home/me/Pictures"]]));
  assert.equal(P.withAllowed([], "grok", "files", "/home/me/.ssh").length, 0, "never a hidden folder");
  assert.ok(P.allowedFile(list, "grok", "/home/me/Pictures/a.png"));
  assert.ok(P.allowedFile(list, "grok", "/home/me/Pictures/trip/b.png"), "a folder in it");
  assert.ok(!P.allowedFile(list, "grok", "/home/me/Pictures/.private/c.png"), "not a hidden folder in it");
  assert.ok(!P.allowedFile(list, "grok", "/home/me/Pictures/.d.png"), "not a hidden file");
  assert.ok(!P.allowedFile(list, "grok", "/home/me/PicturesX/a.png"), "not a folder whose name starts the same");
  assert.ok(!P.allowedFile(list, "claude", "/home/me/Pictures/a.png"), "another agent: asked");
  assert.ok(!P.allowedFile(list, "grok", "/home/me/Pictures/../.ssh/id"));
  assert.match(P.describe(list[0]).note, /Grok may put files from this folder on a page without asking/);
  assert.equal(P.without(list, "grok", "files", "/home/me/Pictures").length, 0, "taken back");
});

console.log(`permissions: ${passed} checks passed`);
