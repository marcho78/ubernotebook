// Checks profiles (Profiles.js, and the settings that keep them): what's
// kept, finding one, names and folders that can't be, switching (each keeps
// its own settings), notes from before profiles, the demo.
// Usage (from the plugin directory): node tests/profiles.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const P = load("Profiles.js");
const S = load("Settings.js");
const D = load("Defaults.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }
let n = 0;
const random = () => ((n++ * 0.137) % 1);

check("what the settings keep of them", () => {
  const kept = plain(S.merge(D.DEFAULTS, { profiles: [
    { id: "p-a", name: "  Personal \n", folder: "~/Documents/Omanote", saved: { inbox: "0f8e", mirror: true, nonsense: 1, lastPage: "NOT AN ID" } },
    { id: "p-a", name: "Twice", folder: "~/x" },
    { id: "BAD ID", name: "x", folder: "~/y" },
    { id: "p-b", name: "", folder: "~/z" },
    { id: "p-c", name: "Work", folder: "relative/path" },
    { id: "p-d", name: "Demo", folder: "/home/me/.local/share/omanote/demo", demo: true }
  ], profile: "p-a" }, D.SCHEMA));
  assert.deepEqual(kept.profiles, [
    { id: "p-a", name: "Personal", folder: "~/Documents/Omanote", demo: false, saved: { inbox: "0f8e", mirror: true } },
    { id: "p-d", name: "Demo", folder: "/home/me/.local/share/omanote/demo", demo: true, saved: {} }
  ]);
  assert.equal(kept.profile, "p-a");
  assert.deepEqual(plain(S.merge(D.DEFAULTS, { profiles: "nope" }, D.SCHEMA)).profiles, [], "not a list: none");
  assert.deepEqual(plain(S.overrides(D.DEFAULTS, S.merge(D.DEFAULTS, {}, D.SCHEMA))), {}, "none kept when there are none");
});

const list = [
  { id: "p-a", name: "Personal", folder: "~/Documents/Omanote", demo: false, saved: {} },
  { id: "p-b", name: "Business", folder: "/srv/notes/business", demo: false, saved: { inbox: "b1", lastPage: "page-b", mirror: true, mirrorFolder: "~/Vault" } }
];

check("finding one, and what can't be", () => {
  assert.equal(P.find(list, "p-b").name, "Business");
  assert.equal(P.find(list, "business").id, "p-b", "by name, any case");
  assert.equal(P.find(list, "nope"), null);
  assert.equal(P.nameProblem(list, "  ", ""), "Give it a name");
  assert.equal(P.nameProblem(list, "personal", ""), "There's a profile called that already");
  assert.equal(P.nameProblem(list, "Personal", "p-a"), "", "its own name");
  assert.equal(P.nameProblem(list, "Side project", ""), "");
  assert.equal(P.folderProblem(list, "", "", "/home/me"), "Choose a folder: a full path, or one under ~/");
  assert.equal(P.folderProblem(list, "notes", "", "/home/me"), "Choose a folder: a full path, or one under ~/");
  assert.equal(P.folderProblem(list, "/home/me/Documents/Omanote", "", "/home/me"), "“Personal” keeps its notes there");
  assert.equal(P.folderProblem(list, "~/Documents/Omanote/Work", "", "/home/me"), "“Personal” keeps its notes there", "not inside another's");
  assert.equal(P.folderProblem(list, "/srv", "", "/home/me"), "“Business” keeps its notes there", "nor around one");
  assert.equal(P.folderProblem(list, "~/Documents/Omanote Work", "", "/home/me"), "");
  assert.equal(P.folderProblem(list, "~/Documents/Omanote", "p-a", "/home/me"), "", "its own folder");
});

check("switching: each keeps its own settings", () => {
  const settings = { profile: "p-a", folder: "~/Documents/Omanote", inbox: "a1", lastPage: "page-a", lastNotebook: "nb-a", mirror: false, mirrorFolder: "" };
  const c = plain(P.switchTo(list, settings, "p-b"));
  assert.equal(c.profile, "p-b");
  assert.equal(c.folder, "/srv/notes/business");
  assert.deepEqual([c.inbox, c.lastPage, c.mirror, c.mirrorFolder], ["b1", "page-b", true, "~/Vault"]);
  assert.equal(c.lastNotebook, "", "what it hasn't got: as a new one starts");
  assert.deepEqual(c.profiles[0].saved, { inbox: "a1", lastPage: "page-a", lastNotebook: "nb-a", mirror: false, mirrorFolder: "" }, "the one left keeps its");
  // And back.
  const back = plain(P.switchTo(c.profiles, Object.assign({}, settings, c, { inbox: "b2" }), "p-a"));
  assert.deepEqual([back.folder, back.inbox, back.lastPage, back.lastNotebook], ["~/Documents/Omanote", "a1", "page-a", "nb-a"]);
  assert.equal(back.profiles[1].saved.inbox, "b2", "Business's, as it was left");
  assert.equal(P.switchTo(list, settings, "nope"), null);
  // The open one's folder, as the settings have it now.
  assert.equal(plain(P.withCurrent(list, Object.assign({}, settings, { folder: "~/Elsewhere" })))[0].folder, "~/Elsewhere");
});

check("notes from before profiles, a new one, the demo", () => {
  const before = plain(P.fromBefore("~/Documents/Omanote", random));
  assert.equal(before.profiles.length, 1);
  assert.equal(before.profiles[0].name, "Personal");
  assert.equal(before.profiles[0].folder, "~/Documents/Omanote");
  assert.equal(before.profile, before.profiles[0].id);
  assert.equal(before.folder, "~/Documents/Omanote");
  const made = plain(P.make(list, "  Studio  ", "~/Studio/", random));
  assert.deepEqual([made.name, made.folder, made.demo], ["Studio", "~/Studio", false]);
  assert.ok(/^p-[a-z0-9]+$/.test(made.id) && !list.some((p) => p.id === made.id));
  const demo = plain(P.demo(list, "~/.local/share/omanote/demo", random));
  assert.deepEqual([demo.name, demo.demo], ["Demo", true]);
});

console.log(`profiles: ${passed} checks passed`);
