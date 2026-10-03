// The Library: what's put on pages (bookmarks, links in text and tables,
// files, videos, pictures, audio notes, meetings, sketches), kept in the
// index as a page is saved, cleaned as it's read back, gathered from every
// page (not the trash's or the templates'), newest first, by kind and words.
const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const C = load("Collection.js");
const W = load("Workspace.js");

let passed = 0;
function check(name, fn) { fn(); passed++; }

const U = (n) => "00000000-0000-4000-8000-00000000000" + n;

check("a block's things", () => {
  const bm = plain(C.ofBlock({ uid: "b1", type: "bookmark", data: { url: "https://omarchy.org/news", title: "Omarchy 4", site: "Omarchy", image: "assets/bm-20261002-120000-ghi.png" } }));
  assert.equal(bm.length, 1);
  assert.deepEqual([bm[0].kind, bm[0].title, bm[0].sub, bm[0].url, bm[0].thumb, bm[0].type], ["link", "Omarchy 4", "Omarchy", "https://omarchy.org/news", "assets/bm-20261002-120000-ghi.png", "bookmark"]);
  assert.equal(new Date(bm[0].at).getDate(), 2, "added: from the picture's name");
  const f = plain(C.ofBlock({ uid: "b2", type: "file", data: { src: "assets/file-20261001-090000-abc-spec.pdf", name: "Spec.pdf", size: 52311, kind: "pdf" } }));
  assert.deepEqual([f[0].kind, f[0].title, f[0].file, f[0].size], ["file", "Spec.pdf", "pdf", 52311]);
  assert.equal(C.detail(f[0]), "PDF  \u00b7  51 KB");
  assert.equal(C.iconOf(f[0]), "pdf");
  const v = plain(C.ofBlock({ uid: "b3", type: "video", data: { src: "assets/file-20261001-090000-abc-demo.mp4", name: "Demo.mp4", size: 10, poster: "assets/file-20261001-090000-abc-demo-still.jpg" } }));
  assert.deepEqual([v[0].kind, v[0].thumb], ["video", "assets/file-20261001-090000-abc-demo-still.jpg"]);
  const pic = plain(C.ofBlock({ uid: "b4", type: "image", src: "assets/20261001-101010-k3f2.png" }));
  assert.deepEqual([pic[0].kind, pic[0].thumb], ["picture", "assets/20261001-101010-k3f2.png"]);
  const au = plain(C.ofBlock({ uid: "b5", type: "audio", audio: { src: "assets/audio-20261001-101010-k3f.ogg", duration: 75, transcript: "Call the plumber about the sink" } }));
  assert.deepEqual([au[0].kind, au[0].title, au[0].sub], ["audio", "Call the plumber about the sink", "1:15"]);
  const me = plain(C.ofBlock({ uid: "b6", type: "meeting", meeting: { id: "abcdef12", title: "Weekly sync", duration: 1830, startedAt: "2026-10-01T09:30:00.000Z", segments: [] } }));
  assert.deepEqual([me[0].kind, me[0].title, me[0].at], ["meeting", "Weekly sync", "2026-10-01T09:30:00.000Z"]);
  assert.deepEqual(plain(C.ofBlock({ uid: "b7", type: "sketch", sketch: { strokes: [{}, {}] } }))[0].sub, "2 strokes");
  // Not yet there: nothing.
  assert.equal(C.ofBlock({ uid: "x", type: "file", data: { src: "" } }).length, 0);
  assert.equal(C.ofBlock({ uid: "x", type: "sketch", sketch: { strokes: [] } }).length, 0);
  assert.equal(C.ofBlock({ uid: "x", type: "meeting", meeting: { id: "" } }).length, 0);
});

check("links in text and tables (not to pages or tags, once each)", () => {
  const t = plain(C.ofBlock({ uid: "t1", type: "p", html: 'See <a href="https://example.com/a">the docs</a>, <a href="omanote://page/' + U(1) + '">a page</a>, <a href="omanote://tag/x">#x</a> and <a href="https://example.com/a">again</a> and <a href="https://github.com/basecamp/omarchy">https://github.com/basecamp/omarchy</a>' }));
  assert.deepEqual(t.map((r) => [r.title, r.url, r.sub, r.type]), [["the docs", "https://example.com/a", "example.com", "text"], ["github.com", "https://github.com/basecamp/omarchy", "github.com", "text"]]);
  assert.equal(C.detail(t[0]), "example.com  \u00b7  in the text");
  assert.equal(C.ofBlock({ uid: "c", type: "code", html: '<a href="https://example.com">x</a>' }).length, 0, "not in code");
  const tb = plain(C.ofBlock({ uid: "tb", type: "table", table: { rows: [["A", '<a href="https://ex.org/t">T</a>'], ["", ""]] } }));
  assert.deepEqual(tb.map((r) => r.url), ["https://ex.org/t"]);
});

check("kept in the index, cleaned as it's read back", () => {
  const page = W.newPage({ id: U(1), title: "Launch", blocks: [
    { type: "p", html: 'A <a href="https://example.com">link</a>', indent: 0 },
    { type: "bookmark", indent: 0, data: { url: "https://omarchy.org", title: "Omarchy" } },
    { type: "file", indent: 0, data: { src: "assets/file-20261001-090000-abc-spec.pdf", name: "Spec.pdf", size: 9, kind: "pdf" } }
  ] });
  const list = plain(W.pageCollected(page));
  assert.deepEqual(list.map((r) => r.kind), ["link", "link", "file"]);
  assert.deepEqual(plain(C.clean(list)), list, "as kept: the same read back");
  const bad = plain(C.clean([
    { block: "a", kind: "link", url: "javascript:alert(1)" },
    { block: "b", kind: "file", src: "../../etc/passwd" },
    { block: "c", kind: "nope" },
    { block: "d e", kind: "sketch" },
    { block: "e", kind: "file", src: "assets/x.pdf", thumb: "/etc/x", size: "big", title: "x".repeat(500) }
  ]));
  assert.equal(bad.length, 1);
  assert.deepEqual([bad[0].thumb, bad[0].size, bad[0].title.length], ["", 0, 200]);
  // The index written and read back keeps it.
  const ix = W.emptyIndex();
  ix.pages[U(1)] = W.entry({ title: "Launch", created: "2026-10-01T00:00:00.000Z", collected: list });
  const back = JSON.parse(W.indexJson(ix));
  assert.equal(back.pages[U(1)].collected.length, 3);
  assert.equal(plain(W.cleanIndex(back)).pages[U(1)].collected.length, 3, "kept by this version: kept");
  delete back.collected;
  assert.equal(plain(W.cleanIndex(back)).pages[U(1)].collected, null, "by an older one: worked out again");
});

check("gathered from every page, newest first, by kind and words", () => {
  const ix = W.emptyIndex();
  const mk = (id, extra) => { ix.pages[id] = W.entry(Object.assign({ created: "2026-09-01T00:00:00.000Z", modified: "2026-09-20T00:00:00.000Z" }, extra)); };
  mk(U(1), { title: "Launch", collected: [
    { block: "a1", kind: "file", title: "Spec.pdf", src: "assets/file-20261001-090000-abc-spec.pdf", file: "pdf", at: "2026-10-01T09:00:00.000Z" },
    { block: "a2", kind: "link", title: "the docs", url: "https://example.com/a", sub: "example.com", type: "text" } ] });
  mk(U(2), { title: "Trip", collected: [{ block: "b1", kind: "picture", title: "Picture", src: "assets/20261002-101010-k3f2.png", at: "2026-10-02T10:10:10.000Z" }] });
  mk(U(3), { title: "Old", trashed: true, collected: [{ block: "c1", kind: "link", url: "https://trash.example.com", title: "gone" }] });
  mk(U(4), { title: "Template", template: true, collected: [{ block: "d1", kind: "link", url: "https://tpl.example.com", title: "tpl" }] });
  const all = plain(W.collected(ix));
  assert.deepEqual(all.map((r) => r.block), ["b1", "a1", "a2"], "newest first; a thing with no date: its page's last change");
  assert.deepEqual([all[0].page, all[0].pageTitle], [U(2), "Trip"]);
  const n = plain(C.counts(all));
  assert.deepEqual([n.all, n.file, n.link, n.picture, n.video], [3, 1, 1, 1, 0]);
  assert.deepEqual(plain(C.filter(all, "link", "")).map((r) => r.block), ["a2"]);
  assert.deepEqual(plain(C.filter(all, "", "launch spec")).map((r) => r.block), ["a1"], "the page's title counts");
  assert.deepEqual(plain(C.filter(all, "", "example")).map((r) => r.block), ["a2"]);
  // A synced block's things: on the page it's shown on.
  mk(U(5), { title: "Synced block", synced: true, collected: [{ block: "s1", kind: "link", url: "https://shared.example.com", title: "shared" }] });
  mk(U(6), { title: "Team", icon: "\u{1f465}", links: [U(5)] });
  const shared = plain(W.collected(ix)).filter((r) => r.block === "s1")[0];
  assert.deepEqual([shared.page, shared.pageTitle, shared.pageIcon], [U(6), "Team", "\u{1f465}"]);
});

check("someone named twice on a page, or a link written twice: once", () => {
  const ix = { pages: { [U(1)]: { title: "Sync", icon: "", modified: "2026-10-02T09:00:00.000Z", collected: [
    { kind: "person", block: "b1", type: "mention", title: "Sam", person: "sam" },
    { kind: "link", block: "b2", type: "text", title: "Plan", url: "https://example.com/plan" },
    { kind: "person", block: "b3", type: "mention", title: "Sam", person: "sam" },
    { kind: "person", block: "b4", type: "contact", title: "Sam", person: "sam" },
    { kind: "person", block: "b5", type: "mention", title: "Priya", person: "priya" },
    { kind: "link", block: "b6", type: "text", title: "Plan again", url: "https://example.com/plan" }
  ] } } };
  const list = plain(C.gather(ix));
  assert.deepEqual(list.map((r) => r.kind + ":" + (r.person || r.url)), ["person:sam", "link:https://example.com/plan", "person:priya"]);
  assert.equal(list[0].type, "contact", "their card, when there's one");
  assert.equal(list[0].block, "b4", "a click goes to the card");
});

console.log("collection: " + passed + " checks passed");
