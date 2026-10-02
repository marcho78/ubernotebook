// Checks page history: versions' names, the list of them, and an earlier
// version made ready to put back without losing the pages in the page.
// Usage (from the plugin directory): node tests/history.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const W = load("Workspace.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("names and dates", () => {
  const d = new Date("2026-10-02T09:41:05.120Z");
  const name = W.versionName(d);
  assert.equal(name, "2026-10-02T09-41-05-120Z.json");
  assert.equal(W.versionDate(name).getTime(), d.getTime());
  assert.equal(W.versionDate("index.json"), null);
  assert.equal(W.historyDir("/n", "abc"), "/n/Pages/history/abc");
  const names = ["2026-10-01T08-00-00-000Z.json", "junk.json", "2026-10-02T08-00-00-000Z.json", "2026-09-30T08-00-00-000Z.json"];
  assert.deepEqual(plain(W.versionList(names)).map((v) => v.name), [names[2], names[0], names[3]], "newest first, nothing else");
  assert.deepEqual(plain(W.versionsPast(names, 2)), [names[3]], "past the newest two: the oldest");
});

check("when, as the history says it", () => {
  const now = new Date(2026, 9, 2, 12, 0);
  assert.equal(W.versionLabel(new Date(2026, 9, 2, 9, 5), now), "Today 09:05");
  assert.equal(W.versionLabel(new Date(2026, 9, 1, 18, 2), now), "Yesterday 18:02");
  assert.equal(W.versionLabel(new Date(2026, 8, 28, 14, 3), now), "Mon 28 Sep 14:03");
  assert.equal(W.versionLabel(new Date(2026, 7, 3, 7, 0), now), "3 Aug 07:00");
  assert.equal(W.versionLabel(new Date(2025, 7, 3, 7, 0), now), "3 Aug 2025 07:00");
  const list = [{ date: new Date(2026, 9, 2, 9, 5, 40) }, { date: new Date(2026, 9, 2, 9, 5, 10) }, { date: new Date(2026, 9, 2, 8, 0, 0) }];
  assert.deepEqual(plain(W.versionLabels(list, now)), ["Today 09:05:40", "Today 09:05:10", "Today 08:00"], "seconds only where they're needed");
  assert.equal(W.versionWhy("command"), "Before an agent or command changed it");
  assert.equal(W.versionWhy("edit"), "");
});

check("putting a version back keeps the pages in the page", () => {
  const id = W.uuid4(), kept = W.uuid4(), moved = W.uuid4(), gone = W.uuid4(), added = W.uuid4(), p1 = W.uuid4(), p2 = W.uuid4();
  const version = { id, title: "Old title", icon: "x", content: [p1, kept, moved, gone], blocks: {
    [p1]: { type: "p", html: "old text", content: [p2] }, [p2]: { type: "p", html: "inside" },
    [kept]: { type: "page" }, [moved]: { type: "page" }, [gone]: { type: "page" } } };
  const current = { id, title: "New", content: [kept, added], blocks: { [kept]: { type: "page" }, [added]: { type: "page" } } };
  const index = { pages: {
    [id]: { parent: "" }, [kept]: { parent: id }, [moved]: { parent: W.uuid4() }, [added]: { parent: id, trashed: false } } };
  const r = plain(W.versionToRestore(version, current, index));
  assert.equal(r.title, "Old title");
  assert.deepEqual(r.blocks.map((b) => b.type + ":" + b.indent), ["p:0", "p:1", "page:0", "link:0", "page:0"]);
  assert.equal(r.blocks[2].uid, kept, "a page still here, kept");
  assert.equal(r.blocks[3].target, moved, "a page moved elsewhere since: a link to it");
  assert.ok(W.isUuid(r.blocks[3].uid) && r.blocks[3].uid !== moved);
  assert.ok(!r.blocks.some((b) => b.uid === gone), "a page gone for good: left out");
  assert.equal(r.blocks[4].uid, added, "a page made since: still here, at the end");
  assert.equal(r.blocks[0].html, "old text");
});

console.log(`history: ${passed} checks passed`);
