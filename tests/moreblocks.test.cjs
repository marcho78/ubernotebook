// Checks the newer blocks' logic: files (what a file is, its copy's name,
// sizes, Markdown), bookmarks (links, what a page says about itself), boards
// (cards and columns moved, Markdown), and what blocks keep.
// Usage (from the plugin directory): node tests/moreblocks.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const F = load("Files.js");
const BM = load("Bookmark.js");
const B = load("Board.js");
const Blocks = load("Blocks.js");
const W = load("Workspace.js");
const Imp = load("Import.js");
const Md = load("Markdown.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("files", () => {
  assert.equal(F.kindOf("Report.PDF"), "pdf");
  assert.equal(F.kindOf("clip.webm"), "video");
  assert.equal(F.kindOf("a.tar.gz"), "archive");
  assert.equal(F.kindOf("notes"), "other");
  assert.equal(F.sizeLabel(512), "512 B");
  assert.equal(F.sizeLabel(2048), "2 KB");
  assert.equal(F.sizeLabel(3.4 * 1024 * 1024), "3.4 MB");
  const n = F.assetName("Q3 Report (final).pdf", new Date(2026, 9, 2, 10, 30, 12), "k3f");
  assert.equal(n, "file-20261002-103012-k3f-q3-report-final.pdf");
  assert.ok(Blocks.cleanAsset("assets/" + n), "a name assets takes");
  assert.ok(Blocks.cleanAsset("assets/" + F.assetName("../../etc/passwd", new Date())), "never outside it");
  const f = plain(F.clean({ src: "../x", name: "a/b\u0000c.pdf", size: -3, kind: "nope", height: 99999, color: "red" }));
  assert.equal(f.src, "");
  assert.equal(f.name, "a b c.pdf");
  assert.equal(f.size, 0);
  assert.equal(f.kind, "pdf", "from its name");
  assert.equal(f.height, 2000);
  assert.equal(F.toMarkdown({ src: "assets/x.pdf", name: "X.pdf", size: 2048, kind: "pdf" }, "../"), "[\u{1f4ce} X.pdf](../assets/x.pdf) (2 KB)");
});

check("bookmarks", () => {
  assert.equal(BM.cleanUrl("https://example.com/a?b=1"), "https://example.com/a?b=1");
  assert.equal(BM.cleanUrl("www.example.com"), "https://www.example.com");
  assert.equal(BM.cleanUrl("file:///etc/passwd"), "");
  assert.equal(BM.cleanUrl("javascript:alert(1)"), "");
  assert.equal(BM.cleanUrl("https://exa mple.com"), "");
  assert.equal(BM.domain("https://www.Example.com/x"), "example.com");
  const html = '<html><head><title>Plain title</title><meta content="The OG title &amp; more" property="og:title"><meta name="description" content="A line &#8212; about it"><meta property="og:image" content="img/pic.png"></head></html>';
  const p = plain(BM.parse(html, "https://example.com/blog/post"));
  assert.equal(p.title, "The OG title & more", "og:title, either order, decoded");
  assert.equal(p.description, "A line \u2014 about it");
  assert.equal(p.image, "https://example.com/blog/img/pic.png", "made absolute");
  assert.equal(p.site, "example.com");
  assert.equal(plain(BM.parse("<title>Only this</title>", "https://x.com")).title, "Only this");
  assert.equal(BM.imageName("image/jpeg", "https://x.com/a", new Date(2026, 9, 2, 10, 30, 12), "k3f"), "bm-20261002-103012-k3f.jpg");
  assert.equal(BM.imageName("text/html", "https://x.com/a", new Date()), "", "not a picture");
  assert.equal(BM.clean({ image: "../evil.png" }).image, "");
});

check("boards", () => {
  let b = B.make();
  assert.deepEqual(plain(b.columns.map((c) => c.name)), ["To do", "Doing", "Done"]);
  let r = B.addCard(b, b.columns[0].id, "Write");
  b = r[0];
  const id = r[1];
  r = B.addCard(b, b.columns[0].id, "Edit", 0);
  b = r[0];
  assert.deepEqual(plain(b.columns[0].cards.map((k) => k.text)), ["Edit", "Write"]);
  b = B.moveCard(b, id, b.columns[2].id, 0);
  assert.deepEqual([b.columns[0].cards.length, b.columns[2].cards[0].text], [1, "Write"]);
  b = B.moveCard(b, id, b.columns[2].id, 5);
  assert.equal(b.columns[2].cards.length, 1, "moved in its own column: once");
  b = B.setCard(b, id, { background: "yellow", text: "Write it" });
  assert.deepEqual([B.card(b, id).background, B.card(b, id).text], ["yellow", "Write it"]);
  b = B.addColumn(b, "Later");
  b = B.moveColumn(b, b.columns[3].id, -1);
  assert.deepEqual(plain(b.columns.map((c) => c.name)), ["To do", "Doing", "Later", "Done"]);
  b = B.removeColumn(b, b.columns[2].id);
  assert.equal(b.columns.length, 3);
  assert.equal(B.toMarkdown(b), "**To do**\n- Edit\n\n**Doing**\n\n**Done**\n- Write it");
  assert.equal(B.clean({ columns: [] }), null);
  assert.equal(plain(B.clean({ columns: [{ name: "A", cards: [{ text: "x", page: "nope", color: "javascript:" }] }] })).columns[0].cards[0].page, "");
  let one = B.make();
  for (let i = 0; i < 4; i++) one = B.removeColumn(one, one.columns[0].id);
  assert.equal(one.columns.length, 1, "the last one stays");
  // Sizes: a column dragged wider (0 while it fits), the board's height
  // (0 while it's as tall as its cards).
  b = B.setColumn(b, b.columns[0].id, { width: 340 });
  assert.equal(b.columns[0].width, 340);
  assert.equal(B.setColumn(b, b.columns[0].id, { width: 9000 }).columns[0].width, 600, "no wider than 600");
  assert.equal(B.setColumn(b, b.columns[0].id, { width: 40 }).columns[0].width, 0, "too narrow: fits again");
  assert.deepEqual([B.clean({ columns: [{ name: "A" }], height: 420 }).height, B.clean({ columns: [{ name: "A" }], height: "x" }).height, B.clean({ columns: [{ name: "A" }], height: 50 }).height], [420, 0, 0]);
  assert.equal(B.setCard(Object.assign(B.make(), { height: 500 }), "none", {}).height, 500, "kept through a change");
});

check("what blocks keep, and a board's pages copied with it", () => {
  const btn = plain(Blocks.cleanData("button", { label: "Go", template: "tpl:11111111-1111-4111-8111-111111111111", action: "page", color: "blue" }));
  assert.deepEqual(btn, { label: "Go", template: "tpl:11111111-1111-4111-8111-111111111111", action: "page", color: "blue", background: "" });
  assert.equal(Blocks.cleanData("button", { template: "../x" }).template, "");
  assert.equal(Blocks.cleanData("synced", { page: "x" }).page, "");
  assert.equal(Blocks.clean({ type: "board", data: {} }, null), null, "not in a notebook");
  const parent = W.uuid4(), cardPage = W.uuid4();
  const page = W.newPage({ id: parent, title: "P", blocks: [{ type: "board", indent: 0, data: { columns: [{ id: "a", name: "A", cards: [{ id: "k", text: "Card", page: cardPage }] }] } }] });
  assert.deepEqual(plain(W.childPages(page)), [cardPage], "a card's page is a page in it");
  assert.deepEqual(plain(W.linkedPages(page)), [cardPage]);
  const sub = W.newPage({ id: cardPage, title: "Card", blocks: [{ type: "p", html: "", indent: 0 }] });
  sub.parent = parent;
  const copies = plain(W.duplicate([page, sub], parent, new Date()));
  const card = W.flatten(copies[0])[0].data.columns[0].cards[0];
  assert.equal(card.page, copies[1].id, "the copy's card points to the copy's page");
});

check("agents' fenced blocks: a board, a bookmark, a person, an agenda, an event", () => {
  const b = B.make();
  assert.equal(B.toFence(b), "## To do\n\n## Doing\n\n## Done");
  const parsed = plain(B.fromFence("## To do\n- Write spec\n- [ ] Fix login\n\n**Doing**\n\nDone:\n1. Ship"));
  assert.deepEqual(parsed.columns.map((c) => c.name + ":" + c.cards.map((k) => k.text).join("+")), ["To do:Write spec+Fix login", "Doing:", "Done:Ship"]);
  assert.equal(B.toFence(parsed), "## To do\n- Write spec\n- Fix login\n\n## Doing\n\n## Done\n- Ship");
  assert.equal(B.fromFence(""), null, "nothing to make one of");
  assert.equal(B.fromFence("just words"), null);
  const ev = "0b6c3a52-7d1e-4c3f-9a41-2f8e5d6c7b10";
  const ctx = { contact: (q) => (q === "Sam Rivera" ? "c1" : ""), event: (id) => id === ev };
  const t = (lang, text) => plain(Imp.fenced(lang, text, ctx));
  assert.equal(t("board", "## A\n- x").type, "board");
  assert.equal(t("kanban", "## A\n- x").data.columns[0].cards[0].text, "x");
  assert.deepEqual(t("contact", "Sam Rivera"), { type: "contact", indent: 0, data: { contact: "c1", name: "Sam Rivera" } });
  assert.equal(t("contact", "Nobody").data.contact, "", "someone not in People: their name kept");
  assert.deepEqual(t("agenda", "today").calendar, { day: "" });
  assert.deepEqual(t("agenda", "2026-10-05").calendar, { day: "2026-10-05" });
  assert.deepEqual(t("event", ev).calendar, { id: ev });
  assert.equal(Imp.fenced("event", "e9", ctx), null, "an event not on the calendar: code");
  assert.equal(t("bookmark", "https://example.com/a").data.url, "https://example.com/a");
  assert.equal(Imp.fenced("bookmark", "not a link", ctx), null);
  assert.equal(Imp.fenced("python", "x = 1", ctx), null, "code stays code");
  // And back: read gives them as it takes them.
  const id = W.uuid4();
  const page = W.newPage({ id, title: "P", blocks: [t("board", "## A\n- x"), t("bookmark", "https://example.com/a"), t("contact", "Sam Rivera"), t("agenda", "today"), t("event", ev)] });
  const md = Md.fromDocPage(page, null, { fences: true });
  for (const f of ["```board\n## A\n- x\n```", "```bookmark\nhttps://example.com/a\n```", "```contact\nSam Rivera\n```", "```agenda\ntoday\n```", "```event\n" + ev + "\n```"]) assert.ok(md.includes(f), md);
  const again = plain(Imp.fromMarkdown(md, ctx, { titleFromHeading: true }).blocks).map((x) => x.type);
  assert.deepEqual(again.filter((x) => x !== "p"), ["board", "bookmark", "contact", "agenda", "event"]);
});

check("agents' fenced blocks: a link to a page, a gallery", () => {
  const target = W.uuid4();
  const ctx = { wiki: (name) => (name.toLowerCase() === "target" ? target : "") };
  const t = (lang, text) => plain(Imp.fenced(lang, text, ctx));
  assert.deepEqual(t("link", "Target"), { type: "link", indent: 0, target }, "a page by its title");
  assert.deepEqual(t("link", target + "\nTarget"), { type: "link", indent: 0, target }, "or its id (the title after it ignored)");
  assert.equal(Imp.fenced("link", "Nowhere", ctx), null, "no such page: code");
  const g = t("gallery", "columns: 2\nheight: 300\n![Beach day](assets/a.png)\n![](assets/b.jpg)\n![x](../etc/passwd)");
  assert.equal(g.type, "gallery");
  assert.deepEqual(g.data.images, [{ src: "assets/a.png", caption: "Beach day" }, { src: "assets/b.jpg", caption: "" }], "only pictures in Pages/assets");
  assert.equal(g.data.columns, 2);
  assert.equal(g.data.height, 300);
  assert.equal(Imp.fenced("gallery", "columns: 3", ctx), null, "no pictures: code");
  // And back.
  const page = W.newPage({ id: W.uuid4(), title: "P", blocks: [t("link", "Target"), g] });
  const md = Md.fromDocPage(page, (id) => (id === target ? { title: "Target" } : null), { fences: true });
  assert.ok(md.includes("```link\n" + target + "\nTarget\n```"), md);
  assert.ok(md.includes("```gallery\ncolumns: 2\nheight: 300\n![Beach day](assets/a.png)\n![](assets/b.jpg)\n```"), md);
  const again = plain(Imp.fromMarkdown(md, ctx, { titleFromHeading: true }).blocks).filter((x) => x.type !== "p");
  assert.deepEqual(again.map((x) => x.type), ["link", "gallery"]);
  assert.deepEqual(again[1].data, g.data);
  // Without fences (an export): the link as a link, the gallery as pictures.
  const plainMd = Md.fromDocPage(page, (id) => (id === target ? { title: "Target" } : null), {});
  assert.ok(!plainMd.includes("```"), plainMd);
});

check("a gallery: what it keeps, the Library's pictures, Markdown", () => {
  const g = plain(Blocks.cleanData("gallery", { images: [{ src: "assets/a.png", caption: " Beach \n day " }, { src: "../etc/passwd" }, { src: "assets/b.jpg" }, "nope"], columns: 7, height: 30, color: "blue" }));
  assert.deepEqual(g, { images: [{ src: "assets/a.png", caption: "Beach day" }, { src: "assets/b.jpg", caption: "" }], columns: 3, height: 0, color: "blue", background: "" });
  assert.equal(Blocks.cleanData("gallery", { columns: 2, height: 5000 }).height, 800);
  assert.equal(Blocks.cleanData("gallery", { columns: 4 }).columns, 4);
  assert.deepEqual(plain(Blocks.cleanData("gallery", {})).images, []);
  const id = W.uuid4();
  const page = W.newPage({ id, title: "Trip", blocks: [{ type: "gallery", indent: 0, data: g }] });
  const C = load("Collection.js");
  const got = plain(W.pageCollected(page));
  assert.deepEqual(got.map((r) => r.kind + ":" + r.title + ":" + r.src), ["picture:Beach day:assets/a.png", "picture:Picture:assets/b.jpg"]);
  const md = Md.fromDocPage(page, null, {});
  assert.ok(md.includes("![Beach day](assets/a.png)\n![](assets/b.jpg)"), md);
  const listed = plain(W.blockList(page))[0];
  assert.equal(listed.text, "(a gallery of 2 pictures)");
  assert.deepEqual(listed.images, [{ src: "assets/a.png", caption: "Beach day" }, { src: "assets/b.jpg", caption: "" }]);
  assert.ok(W.pageText(page).includes("Beach day"), "found by its captions");
});

console.log(`moreblocks: ${passed} checks passed`);
