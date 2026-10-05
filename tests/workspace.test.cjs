// Checks Pages: block ids, what a page file may hold, a page's blocks as a
// tree and as a list, the tree of pages, and what Pages look like.
// Usage (from the plugin directory): node tests/workspace.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const W = load("Workspace.js");
const Docs = load("Docs.js");
const Blocks = load("Blocks.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const ids = Array.from({ length: 12 }, () => W.uuid4());
const [P, A, B, C, D, E, F, G, H] = ids;

check("block ids are version 4 UUIDs", () => {
  const seen = new Set();
  for (let i = 0; i < 20000; i++) {
    const id = W.uuid4();
    assert.match(id, /^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/);
    seen.add(id);
  }
  assert.equal(seen.size, 20000, "none repeat");
  assert.equal(W.uuid4(() => 0), "00000000-0000-4000-8000-000000000000");
  assert.equal(W.uuid4(() => 0.99999), "ffffffff-ffff-4fff-bfff-ffffffffffff");
  assert.equal(W.isUuid("0c3f5d2e-9b1a-11ef-8a2b-0242ac120002"), true, "other versions are fine as ids");
  for (const bad of ["", "0C3F5D2E-9B1A-41EF-8A2B-0242AC120002", "0c3f5d2e9b1a41ef8a2b0242ac120002", "../x", null]) assert.equal(W.isUuid(bad), false, String(bad));
});

check("a page file is checked", () => {
  const raw = {
    parent: "not-an-id", title: "  Plans\n2026 ", icon: "\u{1f5fa}\u{fe0f}", cover: "gradient:3", format: { width: "full", font: "comic" },
    content: [A, B, "junk", A, P, D],
    blocks: {
      [A]: { type: "h2", html: "Big <b>idea</b>", color: "blue_background", evil: 1 },
      [B]: { type: "toggle", html: "More", collapsed: true, content: [C, B] },
      [C]: { type: "code", html: "x = 1", lang: "python", content: [E] },
      [D]: { type: "link", target: "nope" },
      [E]: { type: "p", html: "under the code" },
      [F]: { type: "p", html: "unreachable" },
    },
  };
  const page = plain(W.cleanPage(raw, P));
  assert.equal(page.title, "Plans 2026");
  assert.equal(page.icon, "\u{1f5fa}\u{fe0f}");
  assert.equal(page.cover, "gradient:3");
  assert.deepEqual(page.format, { width: "full", size: "normal", font: "sans", locked: false });
  assert.equal(page.parent, "");
  assert.deepEqual(page.content, [A, B], "each block once; nothing that isn't one; the page isn't in itself");
  assert.equal(page.blocks[A].color, "blue_background");
  assert.equal(page.blocks[A].evil, undefined);
  assert.deepEqual(page.blocks[B].content, [C, E], "what a code block can't hold comes out after it");
  assert.equal(page.blocks[E].parent, B);
  assert.equal(page.blocks[C].lang, "python");
  assert.equal(page.blocks[B].collapsed, true);
  assert.equal(page.blocks[D], undefined, "a link needs a page to point to");
  assert.equal(page.blocks[F], undefined, "blocks nothing holds are left out");
  assert.match(page.text, /Plans 2026\nBig idea/);
  assert.equal(W.cleanPage({}, "x"), null);
  assert.equal(W.cleanIcon("abc"), "", "an icon is an emoji");
  assert.equal(W.cleanCover("gradient:40"), "");
  assert.equal(W.cleanCover("assets/cover-1.png"), "assets/cover-1.png");
  assert.equal(W.cleanCover("../x.png"), "");
});

check("very deep blocks come up to the deepest a page goes", () => {
  const chain = Array.from({ length: 20 }, () => W.uuid4());
  const blocks = {};
  chain.forEach((id, i) => { blocks[id] = { type: "bullet", html: String(i), content: i + 1 < chain.length ? [chain[i + 1]] : [] }; });
  const page = W.cleanPage({ content: [chain[0]], blocks }, P);
  const list = plain(W.flatten(page));
  assert.equal(list.length, 20, "none lost");
  assert.equal(Math.max(...list.map((b) => b.indent)), W.MAX_DEPTH);
});

check("a page's blocks as a list and back", () => {
  const list = [
    { uid: A, type: "toggle", html: "Plan", indent: 0 },
    { uid: B, type: "check", html: "one", indent: 1, checked: true },
    { uid: C, type: "check", html: "two", indent: 1 },
    { uid: D, type: "p", html: "note", indent: 2 },
    { uid: E, type: "h2", html: "Next", indent: 0 },
    { uid: F, type: "p", html: "too deep", indent: 3 },
  ];
  const tree = plain(W.unflatten(list, P));
  assert.deepEqual(tree.content, [A, E, F], "a heading can't hold blocks: the one under it is next to it");
  assert.deepEqual(tree.blocks[A].content, [B, C]);
  assert.deepEqual(tree.blocks[C].content, [D]);
  assert.equal(tree.blocks[D].parent, C);
  assert.equal(tree.blocks[A].parent, P);
  assert.equal(tree.blocks[B].indent, undefined, "depth isn't stored; the tree says it");
  const page = W.cleanPage(Object.assign({ title: "T" }, tree), P);
  const back = plain(W.flatten(page));
  assert.deepEqual(back.map((b) => [b.uid, b.indent]), [[A, 0], [B, 1], [C, 1], [D, 2], [E, 0], [F, 0]]);
  assert.equal(back[1].checked, true);
  assert.deepEqual(plain(W.childPages(W.newPage({ blocks: [{ uid: G, type: "page", indent: 0 }, { uid: H, type: "toggle", indent: 0 }, { uid: I(), type: "page", indent: 1 }] }))).length, 2);
});

function I() { return W.uuid4(); }

check("depths that make sense", () => {
  const list = [
    { type: "p", indent: 2 },
    { type: "bullet", indent: 1 },
    { type: "bullet", indent: 3 },
    { type: "code", indent: 2 },
    { type: "p", indent: 3 },
    { type: "h1", indent: 0, toggle: true },
    { type: "p", indent: 1 },
  ];
  assert.deepEqual(plain(W.normalizeDepths(list)).map((b) => b.indent), [0, 1, 2, 2, 2, 0, 1]);
  const flat = [{ type: "toggle", indent: 0 }, { type: "p", indent: 1 }, { type: "p", indent: 2 }, { type: "p", indent: 0 }];
  assert.equal(W.subtreeEnd(flat, 0), 2);
  assert.equal(W.subtreeEnd(flat, 1), 2);
  assert.equal(W.subtreeEnd(flat, 3), 3);
  assert.deepEqual(plain(W.depthRange(flat, 1)), { min: 1, max: 1 }, "between a toggle and its child: only inside");
  assert.deepEqual(plain(W.depthRange(flat, 3)), { min: 0, max: 3 });
  assert.deepEqual(plain(W.depthRange(flat, 4)), { min: 0, max: 1 });
  assert.deepEqual(plain(W.depthRange([{ type: "code", indent: 0 }], 1)), { min: 0, max: 0 }, "nothing goes inside code");
});

function index() {
  return W.cleanIndex({
    top: [A, B, A, "bad"],
    pages: {
      [A]: { title: "Home", icon: "\u{1f3e0}", parent: "", children: [C, D] },
      [B]: { title: "Work", parent: "", children: [] },
      [C]: { title: "Ideas", parent: A, children: [E] },
      [D]: { title: "Old", parent: A, trashed: true },
      [E]: { title: "Deep", parent: C },
      [F]: { title: "Lost", parent: C },
      [G]: { title: "Loop 1", parent: H, created: "2026-01-01T00:00:00Z" },
      [H]: { title: "Loop 2", parent: G, created: "2026-02-01T00:00:00Z" },
    },
  });
}

check("the tree of pages is checked", () => {
  const ix = plain(index());
  assert.deepEqual(ix.top, [A, B, G], "each page once, and a loop is broken at its oldest page");
  assert.deepEqual(ix.pages[A].children, [C, D]);
  assert.deepEqual(ix.pages[C].children, [E, F], "a page the tree didn't list goes under its parent");
  assert.deepEqual(ix.pages[G].children, [H]);
  assert.equal(ix.pages[G].parent, "");
  assert.equal(ix.pages.bad, undefined);
});

check("the sidebar, the path to a page, the trash", () => {
  const ix = index();
  assert.deepEqual(plain(W.rows(ix, {})).map((r) => r.id), [A, B, G]);
  const open = plain(W.rows(ix, { [A]: true, [C]: true }));
  assert.deepEqual(open.map((r) => [r.id, r.depth]), [[A, 0], [C, 1], [E, 2], [F, 2], [B, 0], [G, 0]], "the trash isn't in it");
  assert.equal(open[0].hasChildren, true);
  assert.equal(open[4].hasChildren, false);
  assert.deepEqual(plain(W.path(ix, E)).map((p) => p.title), ["Home", "Ideas", "Deep"]);
  assert.deepEqual(plain(W.trashed(ix)), [D]);
  assert.equal(W.inTrash(ix, D), true);
  ix.pages[C].trashed = true;
  assert.equal(W.inTrash(ix, E), true, "inside a page in the trash is in the trash");
  assert.deepEqual(plain(W.trashed(ix)).sort(), [C, D].sort());
  assert.deepEqual(plain(W.withDescendants(ix, C)), [C, E, F]);
  assert.deepEqual(plain(W.findTitles(ix, "wo")), [B]);
  assert.deepEqual(plain(W.findTitles(ix, "loop")).length, 2);
  assert.deepEqual(plain(W.findTitles(ix, "deep")), [], "not what's in the trash");
});

check("moving pages in the tree", () => {
  const ix = index();
  W.attach(ix, E, B, 0);
  assert.deepEqual(plain(ix.pages[B].children), [E]);
  assert.deepEqual(plain(ix.pages[C].children), [F]);
  assert.equal(ix.pages[E].parent, B);
  W.attach(ix, E, "", 1);
  assert.deepEqual(plain(ix.top), [A, E, B, G]);
  // A page's file says which pages are on it, in what order.
  assert.equal(W.syncChildren(ix, A, [E, C]), true);
  assert.deepEqual(plain(ix.pages[A].children), [E, C, D], "what's on it, then what it has in the trash");
  assert.equal(ix.pages[E].parent, A);
  assert.equal(plain(ix.top).indexOf(E), -1);
  assert.equal(W.syncChildren(ix, C, [A, F]), false, "never a page inside its own child");
  assert.equal(ix.pages[A].parent, "");
});

check("changing a page that isn't open", () => {
  const page = W.cleanPage({ content: [A, B], blocks: { [A]: { type: "toggle", html: "t", content: [C] }, [C]: { type: "p", html: "in", content: [D] }, [D]: { type: "p", html: "deeper" }, [B]: { type: "p", html: "b" } } }, P);
  assert.equal(W.removeBlock(page, C), true);
  assert.deepEqual(plain(page.content), [A, B]);
  assert.equal(page.blocks[A].content, undefined, "the toggle has nothing in it now");
  assert.equal(page.blocks[D], undefined, "what was inside went with it");
  assert.equal(W.removeBlock(page, C), false);
  assert.equal(W.appendPageBlock(page, E), true);
  assert.equal(W.appendPageBlock(page, E), false, "once");
  assert.deepEqual(plain(W.childPages(page)), [E]);
  assert.equal(W.score("Trip to Lisbon", "tram 28 and pastries", "lisbon tram"), 4);
  assert.equal(W.score("Trip", "tram", "bus"), 0);
  assert.deepEqual(plain(W.snippet("The quick brown fox jumps", "fox", 6)), { before: "\u2026brown ", match: "fox", after: " jumps" });
});

check("columns that make sense", () => {
  const L = (spec) => spec.map(([uid, type, indent]) => ({ uid, type, indent }));
  const ok = L([["cs", "columns", 0], ["c1", "column", 1], ["a", "p", 2], ["c2", "column", 1], ["b", "p", 2], ["b1", "p", 3], ["z", "p", 0]]);
  assert.equal(W.fixColumns(ok), null, "two columns with something in each are fine");
  const oneLeft = L([["cs", "columns", 0], ["c1", "column", 1], ["a", "p", 2], ["c2", "column", 1]]);
  const f1 = plain(W.fixColumns(oneLeft));
  assert.deepEqual(f1.remove.sort(), ["c1", "c2", "cs"], "an empty column goes, and one column isn't columns");
  assert.deepEqual(f1.indent, { a: 0 }, "what was in it takes its place");
  assert.deepEqual(plain(W.applyFix(oneLeft, W.fixColumns(oneLeft))).map((b) => [b.uid, b.indent]), [["a", 0]]);
  const three = L([["cs", "columns", 0], ["c1", "column", 1], ["a", "p", 2], ["c2", "column", 1], ["c3", "column", 1], ["b", "p", 2]]);
  assert.deepEqual(plain(W.fixColumns(three)), { remove: ["c2"], indent: {} }, "an empty column among others just goes");
  const deep = L([["t", "toggle", 0], ["cs", "columns", 1], ["c1", "column", 2], ["a", "p", 3], ["c2", "column", 2], ["b", "p", 3]]);
  assert.deepEqual(plain(W.applyFix(deep, W.fixColumns(deep))).map((b) => [b.uid, b.indent]), [["t", 0], ["a", 1], ["b", 1]], "columns only at the top of a page");
  const stray = L([["x", "p", 0], ["c", "column", 0], ["y", "p", 1]]);
  assert.deepEqual(plain(W.applyFix(stray, W.fixColumns(stray))).map((b) => [b.uid, b.indent]), [["x", 0], ["y", 0]], "a column outside columns goes");
  const odd = L([["cs", "columns", 0], ["q", "p", 1], ["c1", "column", 1], ["a", "p", 2], ["c2", "column", 1], ["b", "p", 2]]);
  assert.deepEqual(plain(W.applyFix(odd, W.fixColumns(odd))).map((b) => b.uid), ["q", "a", "b"], "holding something that isn't a column, it goes");
  // A page file with columns keeps them; a broken one comes out as plain blocks.
  const [cs, c1, c2, a, b] = Array.from({ length: 5 }, () => W.uuid4());
  const page = W.cleanPage({ content: [cs], blocks: { [cs]: { type: "columns", content: [c1, c2] }, [c1]: { type: "column", width: 0.3, content: [a] }, [c2]: { type: "column", content: [b] }, [a]: { type: "p", html: "left" }, [b]: { type: "p", html: "right" } } }, P);
  assert.deepEqual(plain(W.flatten(page)).map((x) => [x.type, x.indent]), [["columns", 0], ["column", 1], ["p", 2], ["column", 1], ["p", 2]]);
  assert.equal(page.blocks[c1].width, 0.3, "a column keeps its width");
  const broken = W.cleanPage({ content: [cs], blocks: { [cs]: { type: "columns", content: [c1] }, [c1]: { type: "column", content: [a] }, [a]: { type: "p", html: "alone" } } }, P);
  assert.deepEqual(plain(W.flatten(broken)).map((x) => [x.type, x.indent]), [["p", 0]]);
});

check("links between pages, backlinks and reminders", () => {
  const [p, q, r, a, b, c] = Array.from({ length: 6 }, () => W.uuid4());
  const page = W.cleanPage({
    content: [a, b, c],
    blocks: {
      [a]: { type: "p", html: 'See <a href="uber-notebook://page/' + q + '">Q</a> and <a href="uber-notebook://page/' + q + '">Q again</a>' },
      [b]: { type: "link", target: r },
      [c]: { type: "check", html: 'Call the bank <a href="uber-notebook://remind/2026-10-01T09:30">Thu 1 Oct 9:30</a> or <a href="uber-notebook://remind/2026-10-02">Fri 2 Oct</a> <a href="uber-notebook://date/2026-10-03">Sat</a>' },
    },
  }, p);
  assert.deepEqual(plain(W.linkedPages(page)).sort(), [q, r].sort(), "each page once");
  const rem = plain(W.pageReminders(page));
  assert.deepEqual(rem.map((x) => x.at), ["2026-10-01T09:30", "2026-10-02T09:00"], "a reminder on a day comes at 9, a plain date isn't one");
  assert.match(rem[0].text, /^Call the bank/);
  const ix = W.cleanIndex({
    top: [p, q, r],
    pages: {
      [p]: { title: "P", links: [q, r], reminders: rem },
      [q]: { title: "Q", links: [] },
      [r]: { title: "R", links: [q], trashed: true },
    },
    fired: { [p + "|" + c + "|2026-10-01T09:30"]: true, "junk": true },
  });
  assert.deepEqual(plain(W.backlinks(ix, q)), [p], "who links to it, not from the trash");
  assert.deepEqual(plain(W.backlinks(ix, p)), []);
  const due = plain(W.pendingReminders(ix));
  assert.equal(due.length, 1, "the one that came already doesn't again");
  assert.equal(due[0].page, p);
  assert.equal(Object.keys(plain(ix.fired)).length, 1, "nothing odd in the list of what came");
  assert.equal(W.cleanIndex({ pages: { [q]: { title: "Q" } } }).pages[q].links, null, "not worked out yet");
  assert.match(W.indexJson(ix), /"fired"/);
});

check("favorites, and copies of pages", () => {
  const [p, q, r, a, b] = Array.from({ length: 5 }, () => W.uuid4());
  const ix = W.cleanIndex({ top: [p, q], pages: { [p]: { title: "P", children: [r] }, [q]: { title: "Q", trashed: true }, [r]: { title: "R", parent: p } }, favorites: [r, q, "junk", r] });
  assert.deepEqual(plain(ix.favorites), [r, q], "each once, only pages that are there");
  assert.deepEqual(plain(W.favorites(ix)), [r], "not what's in the trash");
  const top = W.cleanPage({ title: "P", content: [a, r], blocks: { [a]: { type: "p", html: "hi" }, [r]: { type: "page" } } }, p);
  const inner = W.cleanPage({ title: "R", parent: p, content: [b], blocks: { [b]: { type: "check", html: "x", checked: true } } }, r);
  const copies = plain(W.duplicate([inner, top], p));
  assert.equal(copies.length, 2);
  assert.equal(copies[0].title, "P (copy)", "the top one first, called a copy");
  assert.notEqual(copies[0].id, p);
  const list = plain(W.flatten(copies[0]));
  assert.notEqual(list[0].uid, a, "new block ids");
  assert.equal(list[1].type, "page");
  assert.equal(list[1].uid, copies[1].id, "its page block points to the copy of the page inside it");
  assert.equal(copies[1].title, "R", "a page inside keeps its name");
  assert.equal(copies[1].parent, copies[0].id);
  assert.equal(W.flatten(copies[1])[0].checked, true);
  assert.equal(plain(W.cleanFormat({ locked: true })).locked, true);
});

check("Pages' look", () => {
  const p = plain(Docs.typeStyle("p", false));
  assert.deepEqual([p.size, p.lineHeight], [16, 24]);
  assert.equal(plain(Docs.typeStyle("p", true)).size, 14);
  assert.equal(plain(Docs.typeStyle("h1", false)).weight, 700);
  assert.deepEqual(plain(Docs.blockColors("blue", false)), { text: "#337ea9", background: "" });
  assert.deepEqual(plain(Docs.blockColors("red_background", true)), { text: "", background: "#522e2a" });
  assert.deepEqual(plain(Docs.blockColors("nope", true)), { text: "", background: "" });
  const dark = Docs.darkMap();
  const light = Docs.lightMap();
  for (const c of plain(Docs.COLORS)) {
    assert.equal(light[dark[c.text[0]]], c.text[0]);
    assert.equal(light[dark[c.background[0]]], c.background[0]);
    assert.ok(Blocks.isColor(c.id) && Blocks.isColor(c.id + "_background"));
  }
  assert.deepEqual(plain(Docs.findCommands("to")).slice(0, 2).map((c) => c.label), ["To-do list", "Toggle list"]);
  assert.equal(plain(Docs.findCommands("red"))[0].label, "Red");
  assert.equal(plain(Docs.findCommands("h2"))[0].label, "Heading 2");
  assert.equal(plain(Docs.findCommands("")).length, plain(Docs.COMMANDS).length);
  assert.deepEqual(plain(Docs.findCommands("zzz")), []);
  for (const c of plain(Docs.COMMANDS)) if (c.type) assert.ok(W.isKind(c.type), c.id);
  assert.ok(Docs.emojiList().length > 100);
  assert.equal(W.cleanIcon(Docs.randomEmoji(() => 0.5)) !== "", true, "every icon offered is one a page may have");
  for (const e of Docs.emojiList()) assert.equal(W.cleanIcon(e), e, e);
  assert.deepEqual(plain(Docs.coverStops("gradient:1")), ["#a1c4fd", "#c2e9fb"]);
  assert.equal(Docs.COVERS.length, W.COVERS);
});

check("typing shortcuts in Pages", () => {
  assert.deepEqual(plain(Blocks.shortcut(">", true)), { type: "toggle" });
  assert.equal(plain(Blocks.shortcut(">", false)).type, "quote");
  assert.equal(plain(Blocks.shortcut("\"", true)).type, "quote");
  assert.equal(Blocks.shortcut("9:30", true), null);
  assert.equal(Blocks.kindAfterEnter("toggle", true), "toggle");
  const heading = plain(Blocks.clean({ type: "h2", toggle: true, collapsed: true, indent: 9 }, { nest: true }));
  assert.deepEqual([heading.toggle, heading.collapsed, heading.indent], [true, true, 9]);
  assert.equal(plain(Blocks.clean({ type: "h2", indent: 9 })).indent, 0, "not in a notebook");
  assert.equal(plain(Blocks.clean({ type: "p", collapsed: true })).collapsed, undefined);
});

check("what commands need: pages described, found by name, added to", () => {
  const ix = W.emptyIndex();
  const [a, b, c] = [W.uuid4(), W.uuid4(), W.uuid4()];
  ix.pages[a] = { title: "Travel", icon: "", parent: "", children: [], trashed: false, modified: "2026-09-01" };
  ix.pages[b] = { title: "Lisbon", icon: "\u{1f1f5}\u{1f1f9}", parent: "", children: [], trashed: false, modified: "2026-09-02" };
  ix.pages[c] = { title: "lisbon", icon: "", parent: "", children: [], trashed: false, modified: "2026-09-03" };
  W.attach(ix, a, "", -1);
  W.attach(ix, b, a, -1);
  W.attach(ix, c, "", -1);
  assert.deepEqual(plain(W.describe(ix, b)), { id: b, title: "Lisbon", icon: "\u{1f1f5}\u{1f1f9}", path: "Travel", parent: a, modified: "2026-09-02" });
  assert.deepEqual(plain(W.allPages(ix)).map((p) => p.title), ["Travel", "Lisbon", "lisbon"], "every page, inside ones too");
  assert.equal(W.pageNamed(ix, " LISBON "), c, "any case; the last changed");
  ix.pages[c].trashed = true;
  assert.equal(W.pageNamed(ix, "lisbon"), b, "not one in the trash");
  assert.equal(W.pageNamed(ix, "Porto"), "");
  const page = W.newPage({ title: "Log", blocks: [{ type: "p", html: "first", indent: 0 }, { type: "p", html: "", indent: 0 }] });
  const child = W.uuid4();
  assert.equal(W.appendBlocks(page, [{ type: "bullet", html: "two", indent: 0 }, { type: "p", html: "in", indent: 1 }, { type: "page", uid: child, indent: 0 }]), 3);
  const flat = plain(W.flatten(page));
  assert.deepEqual(flat.map((x) => `${x.type}:${x.indent}`), ["p:0", "bullet:0", "p:1", "page:0", "p:0"], "before the empty line it ends with");
  assert.equal(flat[3].uid, child, "a page's block keeps its id");
  assert.ok(flat.every((x) => W.isUuid(x.uid)));
});

check("projects: kept, their progress, when they're due, the list", () => {
  const id = W.uuid4(), sub = W.uuid4(), c1 = W.uuid4(), c2 = W.uuid4();
  const page = W.cleanPage({ title: "Launch", project: { status: "nonsense", due: "2026-10-12" }, content: [c1, c2], blocks: {
    [c1]: { type: "check", html: "a", checked: true }, [c2]: { type: "check", html: "b" } } }, id);
  assert.deepEqual(plain(page.project), { status: "active", due: "2026-10-12" }, "a status it knows");
  assert.deepEqual(plain(W.cleanPage(JSON.parse(W.pageJson(page)), id).project), plain(page.project), "kept in its file");
  assert.equal(W.cleanPage({ title: "x", project: { due: "2026-13-40" } }, id).project.due, "", "a date that is one");
  assert.equal(W.cleanPage({ title: "x" }, id).project, undefined);
  assert.equal(JSON.parse(W.pageJson(W.cleanPage({ title: "x" }, id))).project, undefined, "none: not written");
  assert.deepEqual(plain(W.pageChecks(page)), { done: 1, total: 2 });
  W.putBlocks(page, 2, 0, [{ type: "p", html: "more", indent: 0 }], 0);
  assert.equal(page.project.due, "2026-10-12", "blocks put in keep it a project");
  const ix = W.cleanIndex({ top: [id], pages: {
    [id]: { title: "Launch", project: page.project, checks: { done: 1, total: 2 }, children: [sub] },
    [sub]: { title: "Tasks", parent: id, checks: { done: 2, total: 5 } } } });
  assert.deepEqual(plain(W.projectProgress(ix, id)), { done: 3, total: 7 }, "its pages' to-dos too");
  const now = new Date(2026, 9, 2, 10);
  assert.deepEqual(plain(W.dueInfo("2026-10-02", now)), { label: "Today", overdue: false, days: 0 });
  assert.equal(W.dueInfo("2026-10-03", now).label, "Tomorrow");
  assert.equal(W.dueInfo("2026-10-06", now).label, "Tue");
  assert.equal(W.dueInfo("2026-10-20", now).label, "Tue 20 Oct");
  assert.deepEqual(plain(W.dueInfo("2026-09-29", now)), { label: "3 days late", overdue: true, days: -3 });
  assert.equal(W.dueInfo("", now), null);
  const a = W.uuid4(), b = W.uuid4(), c = W.uuid4(), d = W.uuid4(), e = W.uuid4();
  const ix2 = W.cleanIndex({ top: [a, b, c, d, e], pages: {
    [a]: { title: "Paused one", project: { status: "paused" } },
    [b]: { title: "Late", project: { status: "active", due: "2026-09-01" } },
    [c]: { title: "Later", project: { status: "active", due: "2026-12-01" } },
    [d]: { title: "Put away", project: { status: "active" }, archived: true },
    [e]: { title: "No due", project: { status: "active" } } } });
  const list = plain(W.projectList(ix2, now));
  assert.deepEqual(list.map((p) => p.title), ["Late", "Later", "No due", "Paused one"], "active first, by when they're due; not the archive's");
  assert.equal(list[0].overdue, true);
  assert.ok(W.inArchive(ix2, d));
  assert.deepEqual(plain(W.archived(ix2)), [d]);
  assert.ok(JSON.parse(W.indexJson(ix2)).pages[d].archived, "kept");
});

check("the page tree, however deep or looped it says it is, read in time in step with its pages", () => {
  const id = (i) => "00000000-0000-4000-8000-" + String(i).padStart(12, "0");
  const n = 20000;
  const chain = {};
  for (let i = 0; i < n; i++) chain[id(i)] = { title: "p" + i, parent: i ? id(i - 1) : "", children: [], created: new Date(2026, 0, 1, 0, 0, n - i).toISOString() };
  let t0 = Date.now();
  const a = W.cleanIndex({ version: 1, pages: chain });
  assert.ok(Date.now() - t0 < 5000, "a chain: " + (Date.now() - t0) + " ms");
  assert.deepEqual([a.top.length, a.pages[id(n - 1)].parent], [1, id(n - 2)], "each under its parent");
  const loop = {};
  for (let i = 0; i < n; i++) loop[id(i)] = { title: "p" + i, parent: id((i + 1) % n), children: [] };
  t0 = Date.now();
  const b = W.cleanIndex({ version: 1, pages: loop });
  assert.ok(Date.now() - t0 < 5000, "a loop: " + (Date.now() - t0) + " ms");
  assert.equal(b.top.length, 1, "a loop broken once, at the top");
  assert.equal(Object.keys(b.pages).length, n, "and every page kept");
});

console.log(`workspace: ${passed} checks passed`);
