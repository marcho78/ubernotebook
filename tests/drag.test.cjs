// Checks pages dragged in the sidebar: where a drop puts a page, and its
// block put in its place on the page it goes on.
// Usage (from the plugin directory): node tests/drag.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const W = load("Workspace.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const ids = {};
["a", "b", "c", "a1", "a2", "a3", "a21"].forEach((k) => (ids[k] = W.uuid4()));
function tree() {
  const p = (title, parent, children) => ({ title, parent: parent ? ids[parent] : "", children: children.map((c) => ids[c]) });
  return W.cleanIndex({ top: [ids.a, ids.b, ids.c], pages: {
    [ids.a]: p("A", "", ["a1", "a2", "a3"]), [ids.b]: p("B", "", []), [ids.c]: p("C", "", []),
    [ids.a1]: p("A1", "a", []), [ids.a2]: p("A2", "a", ["a21"]), [ids.a3]: p("A3", "a", []), [ids.a21]: p("A21", "a2", []) } });
}
const name = (id) => Object.keys(ids).find((k) => ids[k] === id) || id;

check("where a drop puts a page", () => {
  const ix = tree();
  const before = plain(W.dropPlace(ix, ids.c, ids.a2, "before"));
  assert.deepEqual([before.parent, before.at, name(before.before), name(before.after)].map((x) => (x === ids.a ? "a" : x)), ["a", 1, "a2", "a1"], "in front of A2, after A1");
  const after = plain(W.dropPlace(ix, ids.a1, ids.a3, "after"));
  assert.deepEqual([name(after.parent), after.at, after.before, name(after.after)], ["a", 2, "", "a3"], "after the last: at the end (its own place not counted)");
  const inside = plain(W.dropPlace(ix, ids.b, ids.a2, "inside"));
  assert.deepEqual([name(inside.parent), inside.at, name(inside.after)], ["a2", 1, "a21"], "inside, at its end");
  const end = plain(W.dropPlace(ix, ids.a1, "", "end"));
  assert.deepEqual([end.parent, end.at, name(end.after)], ["", 3, "c"]);
  assert.equal(W.dropPlace(ix, ids.a, ids.a21, "inside"), null, "not into a page inside it");
  assert.equal(W.dropPlace(ix, ids.a, ids.a, "after"), null, "not onto itself");
  const back = plain(W.placeOf(ix, ids.a2));
  assert.deepEqual([name(back.parent), back.at, name(back.before), name(back.after)], ["a", 1, "a3", "a1"], "where it is, to put it back");
});

check("its block, in its place on the page", () => {
  const page = { id: ids.a, content: [], blocks: {} };
  const t = W.uuid4(), col = W.uuid4();
  page.content = [t, ids.a1, col];
  page.blocks = { [t]: { id: t, type: "p", parent: ids.a, html: "x" }, [ids.a1]: { id: ids.a1, type: "page", parent: ids.a },
    [col]: { id: col, type: "toggle", parent: ids.a, html: "more", content: [ids.a2] }, [ids.a2]: { id: ids.a2, type: "page", parent: col } };
  W.placePageBlock(page, ids.c, ids.a1, "");
  assert.deepEqual(page.content.map(name), [t, "c", "a1", col].map(name), "in front of it");
  W.placePageBlock(page, ids.b, "", ids.a2);
  assert.deepEqual(page.blocks[col].content.map(name), ["a2", "b"], "right after it, where it is (in the toggle)");
  assert.equal(page.blocks[ids.b].parent, col);
  W.placePageBlock(page, ids.c, "", "");
  assert.equal(page.content[page.content.length - 1], ids.c, "else at the end (moved, not twice)");
  assert.equal(page.content.filter((x) => x === ids.c).length, 1);
  assert.deepEqual(plain(W.childPages(page)).map(name), ["a1", "a2", "b", "c"]);
});

check("projects in the sidebar: apart from the pages, each once", () => {
  const ix = tree();
  const now = new Date(2026, 9, 2);
  ix.pages[ids.a].project = { status: "active", due: "" };
  ix.pages[ids.a2].project = { status: "paused", due: "" };
  ix.pages[ids.c].project = { status: "active", due: "2026-09-30" };
  const open = { [ids.a]: true, [ids.a2]: true, [ids.c]: true };
  const t = plain(W.sidebarRows(ix, open, now));
  assert.deepEqual(t.pages.map((r) => name(r.id)), ["b"], "Pages: not the projects, nor what's in them");
  assert.deepEqual(t.projects.map((r) => name(r.id) + ":" + r.depth), ["c:0", "a:0", "a1:1", "a3:1", "a2:0", "a21:1"],
    "every project at the top (late first, paused last), its pages under it; a project in a project at the top too");
  assert.equal(t.projects[0].overdue, true);
  assert.equal(t.projects[0].isProject, true);
  assert.equal(t.projects[2].isProject, undefined);
  assert.equal(t.projects.find((r) => r.id === ids.a).hasChildren, true);
  ix.pages[ids.a2].archived = true;
  ix.pages[ids.a1].trashed = true;
  const u = plain(W.sidebarRows(ix, open, now));
  assert.deepEqual(u.projects.map((r) => name(r.id)), ["c", "a", "a3"], "not the archive's or the trash's");
});

check("without Projects in the sidebar: the projects in Pages, where they are", () => {
  const ix = tree();
  const now = new Date(2026, 9, 2);
  ix.pages[ids.a2].project = { status: "paused", due: "" };
  ix.pages[ids.c].project = { status: "active", due: "" };
  const open = { [ids.a]: true, [ids.a2]: true };
  const t = plain(W.sidebarRows(ix, open, now, true));
  assert.deepEqual(t.projects, [], "no Projects");
  assert.deepEqual(t.pages.map((r) => name(r.id) + ":" + r.depth), ["a:0", "a1:1", "a2:1", "a21:2", "a3:1", "b:0", "c:0"], "each page once, in its place");
  assert.equal(t.pages.find((r) => r.id === ids.a2).isProject, undefined, "a page's row, as the others");
});

console.log(`drag: ${passed} checks passed`);
