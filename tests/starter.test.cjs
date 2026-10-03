// Checks what a new Omanote starts with (Starter.js, from starter/): that
// StarterContent.js is up to date, every page is made (each after the page
// it's in), its links, people, events and files are there, dates are for
// the day it's made, and nothing's left unfilled but the templates' own.
// Usage (from the plugin directory): node tests/starter.test.cjs

const assert = require("node:assert/strict");
const { execFileSync } = require("node:child_process");
const { load, plain } = require("./load.cjs");

const S = load("Starter.js");
const W = load("Workspace.js");
const Md = load("Markdown.js");
const Email = load("Email.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const now = new Date(2026, 9, 2, 9, 0);
const made = plain(S.build(now, { folder: "~/Documents/Omanote" }));
const byTitle = (t) => made.pages.find((m) => m.page.title === t);

check("StarterContent.js is made from starter/", () => {
  execFileSync(process.execPath, ["dev/starter", "--check"], { stdio: "pipe" });
});

check("the pages, the templates, the people and the events", () => {
  const pages = made.pages.filter((m) => !m.template);
  const templates = made.pages.filter((m) => m.template);
  assert.ok(pages.length >= 12, "examples: " + pages.length);
  assert.ok(templates.length >= 5, "templates: " + templates.length);
  assert.equal(made.contacts.length, 4);
  assert.equal(made.events.length, 6);
  assert.equal(made.pages[0].page.title, "Welcome to Omanote", "the first page");
  assert.equal(made.favorites.length, 2);
  // A page comes after the page it's in.
  const seen = new Set();
  for (const m of made.pages) {
    if (m.page.parent) assert.ok(seen.has(m.page.parent), m.page.title + " after its page");
    seen.add(m.page.id);
    assert.ok(W.isUuid(m.page.id));
    assert.ok(m.page.title, "every page has a title");
    assert.ok(m.page.icon, m.page.title + " has an icon");
  }
  assert.ok(templates.every((m) => !m.page.parent), "templates at the top of theirs");
});

check("links, people, events and pages inside pages are all there", () => {
  const ids = new Set(made.pages.map((m) => m.page.id));
  const people = new Set(made.contacts.map((c) => c.id));
  const events = new Set(made.events.map((e) => e.id));
  for (const m of made.pages) {
    for (const b of W.flatten(m.page)) {
      const h = b.html || "";
      for (const x of h.matchAll(/omanote:\/\/page\/([0-9a-f-]{36})/g)) assert.ok(ids.has(x[1]), "a link in " + m.page.title);
      for (const x of h.matchAll(/omanote:\/\/contact\/([A-Za-z0-9_-]+)/g)) assert.ok(people.has(x[1]), "a person in " + m.page.title);
      if (b.type === "page") assert.ok(ids.has(b.uid));
      if (b.type === "contact") assert.ok(people.has(b.data.contact), "a card in " + m.page.title);
      if (b.type === "event") assert.ok(events.has(b.calendar.id));
    }
    // Each page's pages are on it, once.
    const inside = made.pages.filter((x) => x.page.parent === m.page.id).map((x) => x.page.id);
    assert.deepEqual(plain(W.childPages(m.page)).sort(), inside.slice().sort(), m.page.title + "'s pages");
  }
  for (const e of made.events) if (e.page) assert.ok(ids.has(e.page), e.title + "'s notes page");
});

check("dates are for the day it's made", () => {
  const p = byTitle("Website relaunch").page;
  assert.deepEqual(p.project, { status: "active", due: "2026-10-20" });
  const sync = made.events.find((e) => e.title === "Weekly sync");
  assert.equal(sync.start, "2026-10-06T10:00", "the next Tuesday");
  assert.equal(sync.repeat.freq, "weekly");
  const trip = made.events.find((e) => e.title === "Weekend in Lisbon");
  assert.equal(trip.start, "2026-10-11");
  assert.equal(trip.end, "2026-10-13");
  assert.equal(made.events.filter((e) => e.alert !== -1).length, 0, "no event sends a notification");
  assert.ok(byTitle("Thu 1 Oct"), "yesterday's journal entry");
  assert.equal(S.dayAt(now, "fri").getDate(), 2, "a Friday on a Friday is today");
  assert.equal(S.dayAt(now, "-3").getDate(), 29);
  const habits = made.pages.flatMap((m) => W.flatten(m.page)).filter((b) => b.type === "habit");
  assert.ok(habits.length > 0 && habits.every((b) => /^[01]{4}000$/.test(b.days)), "ticked only before today (a Friday)");
  const eml = made.assets.find((a) => /\.eml$/.test(a.name)).text;
  const m = Email.parse(eml);
  assert.equal(m.date ? new Date(m.date).getDate() : new Date(Email.summary(m).date).getDate(), 26, "sent six days before");
  assert.ok(eml.includes("DTSTART:20261011T072500"), "its calendar file on the trip's day");
});

check("nothing unfilled, nothing that reaches anyone", () => {
  const text = JSON.stringify(made.pages.filter((m) => !m.template)) + JSON.stringify(made.events) + made.assets.map((a) => a.text || "").join("");
  assert.deepEqual(text.match(/\{\{[^}]*\}\}/g), null);
  for (const c of made.contacts) {
    c.emails.forEach((e) => assert.ok(/\.(example|example\.org|example\.com)$/.test(e.value) || /@example\.(org|com)$/.test(e.value), e.value));
    c.phones.forEach((p) => assert.ok(/555 01\d\d$/.test(p.value), p.value));
  }
  for (const m of made.pages) Md.fromDocPage(m.page, null, {});
  const tpl = made.pages.filter((m) => m.template).map((m) => m.page.title);
  assert.ok(tpl.some((t) => t.includes("{{week}}")), "a template's own {{week}} is kept for when it's used");
});

check("the files: the PDF and picture copied, the email written", () => {
  const names = made.assets.map((a) => a.name).sort();
  assert.deepEqual(names, ["example-flight-confirmation.eml", "example-keyboard-shortcuts.pdf", "example-notebooks-shelf.jpg"]);
  for (const a of made.assets) if (a.text === undefined) assert.ok(require("node:fs").existsSync("starter/assets/" + a.file), a.file);
  const file = W.flatten(byTitle("Welcome to Omanote").page).find((b) => b.type === "file");
  assert.equal(file.data.src, "assets/example-keyboard-shortcuts.pdf");
  assert.equal(file.data.kind, "pdf");
  assert.ok(file.data.size > 1000);
});

console.log(`starter: ${passed} checks passed`);
