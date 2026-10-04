// Checks notebook and page files, ids, covers and finding text.
// Usage (from the plugin directory): node tests/library.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Library = load("Library.js");
const Covers = load("Covers.js");
const Defaults = load("Defaults.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("ids and folder names", () => {
  assert.equal(Library.slugify("Work Journal!"), "work-journal");
  assert.equal(Library.slugify("Café Déjà vu"), "cafe-deja-vu");
  assert.equal(Library.slugify("../../etc"), "etc");
  assert.equal(Library.slugify("日本語"), "notebook");
  assert.match(Library.notebookId("Work Journal"), /^work-journal-[a-z2-9]{4}$/);
  const id = Library.pageId(new Date(2026, 8, 30, 14, 32, 1));
  assert.match(id, /^20260930-143201-[a-z2-9]{4}$/);
  assert.ok(Library.isId(id));
  for (const bad of ["", "-x", "A", "a/b", "a b", "..", "x".repeat(81), 3]) assert.equal(Library.isId(bad), false, String(bad));
  const taken = {};
  for (let i = 0; i < 500; i++) taken[Library.pageId(new Date(0), taken)] = true;
  assert.equal(Object.keys(taken).length, 500, "no two pages share an id");
});

check("a new notebook", () => {
  const nb = plain(Library.newNotebook({ title: "  Ideas\n2026 ", cover: { color: "coral", material: "linen", band: true }, paper: { pattern: "dots", color: "night" }, pen: "hand" }, new Date("2026-09-30T12:00:00Z")));
  assert.equal(nb.title, "Ideas 2026");
  assert.match(nb.id, /^ideas-2026-/);
  assert.deepEqual(nb.cover, { color: "coral", material: "linen", band: true });
  assert.deepEqual(nb.paper, { pattern: "dots", color: "night", spacing: "regular" });
  assert.equal(nb.pen, "hand");
  assert.equal(nb.created, "2026-09-30T12:00:00.000Z");
  assert.deepEqual(nb.pages, []);
  assert.equal(plain(Library.newNotebook({})).title, "Untitled notebook");
});

check("notebook.json is checked", () => {
  const nb = plain(Library.cleanNotebook({
    id: "someone-elses-id", title: "<b>x</b>".repeat(40), created: "not a date", modified: "2026-01-02T03:04:05Z",
    cover: { color: "plaid", material: "leather", band: "yes" }, binding: "glue", paper: { pattern: "grid", color: "rainbow" },
    pages: ["a", "a", "../x", 7, "b"], lastPage: "zzz", pen: "crayon"
  }, "folder-id"));
  assert.equal(nb.id, "folder-id", "the folder decides");
  assert.equal(nb.title.length, 120);
  assert.equal(nb.created, "1970-01-01T00:00:00.000Z");
  assert.equal(nb.modified, "2026-01-02T03:04:05.000Z");
  assert.deepEqual(nb.cover, { color: "navy", material: "leather" });
  assert.equal(nb.binding, "spiral");
  assert.deepEqual(nb.paper, { pattern: "grid", color: "ivory", spacing: "regular" });
  assert.deepEqual(nb.pages, ["a", "b"]);
  assert.equal(nb.lastPage, "", "only a page it has");
  assert.equal(nb.pen, "sans");
  assert.equal(Library.cleanNotebook([], "x"), null);
  assert.equal(Library.cleanNotebook({}, "../x"), null);
});

check("pages on disk and in the notebook agree", () => {
  assert.deepEqual(plain(Library.reconcilePages(["c", "a", "gone"], ["a", "b", "c", "20260101-000000-zzzz"])), ["c", "a", "20260101-000000-zzzz", "b"]);
  assert.deepEqual(plain(Library.reconcilePages([], [])), []);
  const shelf = plain(Library.shelfOrder(["b", "x", "a"], [
    { id: "a", created: "2026-01-01" }, { id: "b", created: "2026-03-01" }, { id: "c", created: "2025-01-01" }, { id: "d", created: "2026-02-01" }
  ])).map((n) => n.id);
  assert.deepEqual(shelf, ["b", "a", "c", "d"]);
});

check("page files are checked", () => {
  const page = plain(Library.cleanPage({
    title: "Plan", paper: { pattern: "legal", color: "yellow", spacing: "roomy" }, tab: { color: "#E0A030", label: "Ideas and more ideas than fit on a tab" },
    blocks: [{ type: "h1", html: "Plan" }, { type: "check", html: "Call &amp; mail", checked: true }],
    ink: [{ tool: "marker", color: "#fff27a", width: 99, points: [1, 2, 3.14159, 4] }, { color: "#000000", points: [1, "x"] }, { color: "nope", points: [1, 2] }]
  }, "20260930-120000-abcd"));
  assert.equal(page.title, "Plan");
  assert.deepEqual(page.paper, { pattern: "legal", color: "yellow", spacing: "roomy" });
  assert.deepEqual(page.tab, { color: "#e0a030", label: "Ideas and more ideas tha" });
  assert.equal(page.blocks.length, 2);
  assert.equal(page.text, "Plan\nCall & mail");
  assert.deepEqual(page.ink, [{ tool: "marker", color: "#fff27a", width: 40, points: [1, 2, 3.1, 4] }]);
  assert.equal(plain(Library.cleanPage({ paper: "ruled" }, "20260930-120000-abcd")).paper, null, "no paper of its own: the notebook's");

  const summary = plain(Library.summary(page));
  assert.deepEqual([summary.title, summary.words, summary.checks, summary.done], ["Plan", 4, 1, 1]);
  const untitled = plain(Library.summary(plain(Library.newPage({ blocks: [{ type: "p", html: "First thought" }] }))));
  assert.equal(untitled.title, "First thought");
  assert.equal(untitled.named, false);
  assert.equal(plain(Library.summary(plain(Library.newPage({})))).blank, true);
});

check("finding text", () => {
  assert.equal(Library.score("Groceries", "milk eggs", "milk"), 1);
  assert.ok(Library.score("Groceries", "milk", "groc") > Library.score("My groceries", "milk", "groc"), "the start of a title counts most");
  assert.equal(Library.score("Groceries", "milk", "milk bread"), 0, "every word must be found");
  assert.equal(Library.score("x", "y", ""), 0);
  const s = plain(Library.snippet("The quick brown fox jumps over the lazy dog", "FOX", 6));
  assert.deepEqual(s, { before: "…brown ", match: "fox", after: " jumps…" });
});

check("templates and dates on pages, and the kind of page a notebook makes", () => {
  const nb = plain(Library.cleanNotebook({ title: "Planner", template: "daily" }, "planner-a1b2"));
  assert.equal(nb.template, "daily");
  assert.equal(plain(Library.cleanNotebook({ template: "recipe" }, "x-a1b2")).template, "", "one-off templates aren't a notebook's kind");
  assert.equal(plain(Library.cleanNotebook({ template: "blank" }, "x-a1b2")).template, "");
  assert.equal(plain(Library.newNotebook({ template: "weekly" })).template, "weekly");
  const page = plain(Library.cleanPage({ template: "daily", day: "2026-09-30", blocks: [] }, "20260930-100000-abcd"));
  assert.deepEqual([page.template, page.day], ["daily", "2026-09-30"]);
  const odd = plain(Library.cleanPage({ template: "../x", day: "2026-02-30" }, "20260930-100000-abcd"));
  assert.deepEqual([odd.template, odd.day], ["", ""]);
  const fresh = plain(Library.newPage({ template: "meeting", day: "2026-09-30" }));
  assert.deepEqual([fresh.template, fresh.day], ["meeting", "2026-09-30"]);
});

check("files and pictures", () => {
  assert.equal(Library.pageFile("/r", "nb-a1b2", "20260930-120000-abcd"), "/r/nb-a1b2/pages/20260930-120000-abcd.json");
  assert.match(Library.assetName("/home/u/Pictures/Cat.JPG"), /^\d{8}-\d{6}-[a-z2-9]{4}\.jpg$/);
  assert.match(Library.assetName("/x/file.exe"), /\.png$/);
  assert.equal(Library.isImagePath("/home/u/a b.png"), true);
  assert.equal(Library.isImagePath("relative.png"), false);
  assert.equal(Library.isImagePath("/x/y.pdf"), false);
});

check("a picture out: its kind on the clipboard, a name for its copy", () => {
  assert.equal(Library.pictureType("/n/Pages/assets/20261004-101010-abcd.png"), "image/png");
  assert.equal(Library.pictureType("/n/a.JPG"), "image/jpeg");
  assert.equal(Library.pictureType("/n/a.jpeg"), "image/jpeg");
  assert.equal(Library.pictureType("/n/a.webp"), "image/webp");
  assert.equal(Library.pictureType("/n/a.svg"), "image/svg+xml");
  assert.equal(Library.pictureType("/n/a.pdf"), "");
  assert.equal(Library.pictureType("/n/constructor"), "", "not a picture's ending");
  assert.equal(Library.saveName("Trip to Lisbon", "assets/20261004-101010-abcd.png"), "Trip to Lisbon.png");
  assert.equal(Library.saveName("Q3: plan / budget?", "assets/x.JPG"), "Q3 plan budget.jpg", "what a file's name can't have, out");
  assert.equal(Library.saveName("  ", "assets/x.webp"), "Picture.webp");
  assert.equal(Library.saveName("...hidden", "assets/x.png"), "hidden.png", "not a hidden file");
  assert.ok(Library.saveName("x".repeat(300), "assets/x.png").length <= 84);
});

check("covers", () => {
  const choices = plain(Defaults.SCHEMA).choices;
  assert.deepEqual(choices.cover, plain(Covers.COLORS.map((c) => c.id)));
  assert.deepEqual(choices.material, plain(Covers.MATERIALS.map((m) => m.id)));
  assert.deepEqual(choices.binding, plain(Covers.BINDINGS.map((b) => b.id)));
  const leather = plain(Covers.resolve({ color: "navy", material: "leather" }, "#ff0000"));
  assert.equal(leather.band, true, "leather has an elastic band");
  assert.equal(leather.dark, true);
  assert.equal(leather.titleStyle, "foil");
  const accent = plain(Covers.resolve({ color: "accent", material: "linen", band: true }, "#7aa2f7"));
  assert.equal(accent.color, "#7aa2f7");
  assert.equal(accent.band, true);
  assert.equal(plain(Covers.resolve({ color: "sand", material: "plain" })).dark, false);
});

console.log(`library: ${passed} checks passed`);
