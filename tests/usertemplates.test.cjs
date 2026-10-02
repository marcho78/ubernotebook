// Checks your own templates in Pages: kept apart (not in the tree, search,
// tags, backlinks, reminders, projects), copied when used (every page and
// block a new id, page blocks pointing to the copies), {{date}} and the
// like filled in.
// Usage (from the plugin directory): node tests/usertemplates.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const W = load("Workspace.js");
const T = load("Templates.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const fmt = (d, p) => ({ "ddd d MMM": "Fri 2 Oct", dddd: "Friday", "MMMM yyyy": "October 2026" })[p] || d;
const now = new Date(2026, 9, 2, 9, 5);

check("filled in as it's used", () => {
  assert.equal(T.fill("Standup {{date}}", false, now, fmt), "Standup Fri 2 Oct");
  assert.equal(T.fill("{{weekday}}, {{ time }}, {{month}}, {{year}}, {{week}}", false, now, fmt), "Friday, 09:05, October 2026, 2026, Week 40");
  assert.equal(T.fill("<b>{{date}}</b>", true, now, fmt), '<b><a href="omanote://date/2026-10-02">@Fri 2 Oct</a></b>', "in a line, a date in Pages");
  assert.equal(T.fill("{{nope}} and {{", false, now, fmt), "{{nope}} and {{", "only what it knows");
  assert.equal(T.fill("no braces", true, now, fmt), "no braces");
});

const ids = {};
["tpl", "sub", "subsub", "page", "other"].forEach((k) => (ids[k] = W.uuid4()));
function index() {
  const ix = W.cleanIndex({ top: [ids.tpl, ids.page], pages: {
    [ids.tpl]: { title: "Standup", parent: "", children: [ids.sub], template: true, tags: [{ name: "work", label: "#work", n: 1 }], links: [ids.page],
      reminders: [{ block: W.uuid4(), at: "2026-10-03T09:00", text: "x" }], project: { status: "active", due: "" } },
    [ids.sub]: { title: "Notes", parent: ids.tpl, children: [ids.subsub] },
    [ids.subsub]: { title: "Deep", parent: ids.sub, children: [] },
    [ids.page]: { title: "Standup log", parent: "", children: [], childTemplate: ids.tpl },
  } });
  return ix;
}

check("kept apart", () => {
  const ix = index();
  assert.equal(ix.pages[ids.tpl].template, true, "kept in the index");
  assert.equal(ix.pages[ids.page].childTemplate, ids.tpl);
  assert.match(W.indexJson(ix), /"template": true/);
  assert.equal(W.inTemplates(ix, ids.subsub), true, "a page in a template is part of it");
  assert.equal(W.inTemplates(ix, ids.page), false);
  assert.deepEqual(plain(W.templates(ix)).map((t) => t.title), ["Standup"], "the templates, not the pages in them");
  assert.equal(W.templateNamed(ix, "standup"), ids.tpl);
  assert.equal(W.templateNamed(ix, ids.tpl), ids.tpl);
  assert.equal(W.templateNamed(ix, "nope"), "");
  const open = { [ids.tpl]: true, [ids.sub]: true };
  assert.deepEqual(plain(W.rows(ix, open)).map((r) => r.title), ["Standup log"], "not in the tree");
  assert.deepEqual(plain(W.sidebarRows(ix, open, now)).pages.map((r) => r.title), ["Standup log"]);
  assert.deepEqual(plain(W.findTitles(ix, "standup", 9)).map((id) => ix.pages[id].title), ["Standup log"], "not found");
  assert.deepEqual(plain(W.tagList(ix)), [], "its tags aren't tags");
  assert.deepEqual(plain(W.backlinks(ix, ids.page)), [], "its links aren't backlinks");
  assert.deepEqual(plain(W.pendingReminders(ix)), [], "its dates aren't reminders");
  assert.deepEqual(plain(W.projectList(ix, now)), [], "it isn't a project");
});

check("copied when it's used", () => {
  const page = (id, title, blocks) => W.newPage({ id, title, blocks }, now);
  const tpl = page(ids.tpl, "Standup {{date}}", [
    { type: "h2", html: "{{weekday}}", indent: 0 },
    { type: "check", html: "Ship it", checked: true, indent: 0 },
    { type: "page", uid: ids.sub, indent: 0 },
    { type: "table", indent: 0, table: { rows: [["When", "{{time}}"]], header: true } },
    { type: "meeting", indent: 0, meeting: { id: "3f2a9c1e-7b4d-4e2a-9f1c-2b3c4d5e6f70", title: "Old", color: "blue" } },
  ]);
  tpl.icon = "\u{1f5d3}";
  tpl.format = { font: "serif", width: "full", size: "normal", locked: true };
  const sub = page(ids.sub, "Notes", [{ type: "page", uid: ids.subsub, indent: 0 }]);
  sub.parent = ids.tpl;
  const subsub = page(ids.subsub, "Deep", [{ type: "p", html: "deep", indent: 0 }]);
  subsub.parent = ids.sub;
  const into = W.uuid4();
  const fill = (t, html) => T.fill(t, html, now, fmt);
  const made = plain(W.fromTemplate([subsub, sub, tpl], ids.tpl, into, fill, now));
  assert.equal(made.top.title, "Standup Fri 2 Oct");
  assert.equal(made.top.icon, "\u{1f5d3}");
  assert.equal(made.top.blocks[0].html, "Friday");
  assert.equal(made.top.blocks[1].checked, true, "as it is in the template");
  assert.deepEqual(made.top.blocks[3].table.rows[0], ["When", "09:05"]);
  assert.deepEqual(made.top.blocks[4].meeting, { color: "blue", background: "" }, "a meeting to record, each time");
  assert.equal(made.pages.length, 2, "the pages in it");
  assert.deepEqual(made.pages.map((p) => p.title), ["Notes", "Deep"], "parents first");
  const [nsub, nsubsub] = made.pages;
  assert.notEqual(nsub.id, ids.sub, "new pages");
  assert.equal(nsub.parent, into, "inside the page it's used for");
  assert.equal(nsubsub.parent, nsub.id);
  assert.equal(made.top.blocks[2].uid, nsub.id, "its page block points to the copy");
  assert.equal(W.childPages(nsub)[0], nsubsub.id);
  const uids = made.top.blocks.map((b) => b.uid);
  assert.ok(!uids.includes(tpl.content[0]), "every block a new id");
});

console.log(`usertemplates: ${passed} checks passed`);
