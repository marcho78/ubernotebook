// Checks that notes written before Omanote became Uber Notebook still work:
// their omanote:// links (to pages, dates, reminders, people and tags) are
// read as the new uber-notebook:// ones are, kept as they are when a page
// is saved again, and turned into new ones when they're changed (a tag
// renamed); new links are written with the new name.
// Usage (from the plugin directory): node tests/legacy.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Html = load("Html.js");
const Dates = load("Dates.js");
const Contacts = load("Contacts.js");
const Tags = load("Tags.js");
const W = load("Workspace.js");
const Mirror = load("Mirror.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const id = "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b";

check("links of either name, read the same", () => {
  for (const scheme of ["uber-notebook://", "omanote://"]) {
    assert.ok(Html.isInternal(scheme + "page/" + id), scheme);
    assert.equal(Html.pageOf(scheme + "page/" + id), id, scheme);
    assert.equal(Html.contactOf(scheme + "contact/c-1"), "c-1", scheme);
    assert.ok(Html.isTag(scheme + "tag/idea"), scheme);
    assert.deepEqual(plain(Dates.fromHref(scheme + "remind/2026-10-05T09:30")), plain(Dates.fromHref("uber-notebook://remind/2026-10-05T09:30")), scheme);
    assert.equal(Contacts.idOf(scheme + "contact/c-1"), "c-1", scheme);
    assert.equal(Tags.of(scheme + "tag/work%2Facme"), "work/acme", scheme);
  }
  assert.ok(!Html.isInternal("otherapp://page/" + id), "another app's: not ours");
  assert.equal(Html.pageOf("omanote://page/not-an-id"), "");
});

check("new links, with the new name", () => {
  assert.equal(Dates.href(new Date(2026, 9, 5), false, false), "uber-notebook://date/2026-10-05");
  assert.equal(Dates.href(new Date(2026, 9, 5, 9, 30), true, true), "uber-notebook://remind/2026-10-05T09:30");
  assert.equal(Contacts.href("c-1"), "uber-notebook://contact/c-1");
  assert.equal(Tags.href("idea"), "uber-notebook://tag/idea");
});

check("an old link kept as it is when the page is saved again", () => {
  const html = "See <a href=\"omanote://page/" + id + "\">Plans</a> and <a href=\"omanote://remind/2026-10-05T09:30\">@Mon 5 Oct 9:30</a>";
  const again = Html.serialize(Html.parse(html));
  assert.ok(again.includes("href=\"omanote://page/" + id + "\""), again);
  assert.ok(again.includes("href=\"omanote://remind/2026-10-05T09:30\""), again);
});

check("an old page link shows the page's name now", () => {
  const out = Html.refreshPageLinks("<a href=\"omanote://page/" + id + "\">Old name</a>", (pid) => (pid === id ? "New name" : ""));
  assert.ok(out.includes("New name"), out);
});

check("an old tag renamed or taken off; the renamed one written new", () => {
  const html = "<a href=\"omanote://tag/idea\">#idea</a> later";
  const renamed = Tags.rename(html, "idea", "ideas");
  assert.ok(renamed.includes("uber-notebook://tag/ideas"), renamed);
  assert.ok(!renamed.includes("omanote://"), renamed);
  const gone = Tags.remove(html, "idea");
  assert.ok(!gone.includes("tag/idea"), gone);
});

check("an old reminder still comes", () => {
  const page = W.newPage({ id, title: "Plans", blocks: [{ type: "p", indent: 0, html: "Call <a href=\"omanote://remind/2026-10-05T09:30\">@Mon 5 Oct 9:30</a>" }] });
  const r = plain(W.pageReminders(page));
  assert.equal(r.length, 1);
  assert.equal(r[0].text, "Call @Mon 5 Oct 9:30");
});

check("Markdown (read, the copy, exports) gives an old link with the new name", () => {
  const Md = load("Markdown.js");
  const page = W.newPage({ id, title: "Plans", blocks: [{ type: "p", indent: 0, html: "See <a href=\"omanote://page/" + id + "\">Plans</a> on <a href=\"omanote://date/2026-10-05\">@Mon 5 Oct</a>" }] });
  const md = Md.fromDocPage(page, null, {});
  assert.ok(md.includes("[Plans](uber-notebook://page/" + id + ")"), md);
  assert.ok(md.includes("(uber-notebook://date/2026-10-05)"), md);
  assert.ok(!md.includes("omanote://"), md);
});

check("an old Markdown copy's manifest is read", () => {
  assert.equal(Mirror.MANIFEST, ".uber-notebook-mirror.json");
  assert.equal(Mirror.LEGACY_MANIFEST, ".omanote-mirror.json");
});

console.log(`legacy: ${passed} checks passed`);
