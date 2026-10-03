// Checks the kinds of blocks, numbering, shortcuts and what's read from disk.
// Usage (from the plugin directory): node tests/blocks.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Blocks = load("Blocks.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

function b(type, props) { return plain(Blocks.make(type, props)); }

check("new blocks get their kind's defaults", () => {
  const p = b("p");
  assert.equal(p.type, "p");
  assert.equal(p.html, "");
  assert.match(p.uid, /^b[0-9a-z]+$/);
  assert.equal(b("check").checked, false);
  assert.equal(b("callout").tone, "yellow");
  assert.equal(b("nonsense").type, "p", "unknown kinds are text");
  assert.equal(b("h1", { html: "Hi", indent: 3 }).indent, 0, "headings don't indent");
  assert.equal(b("bullet", { indent: 99 }).indent, 6, "at most six deep");
  const ids = new Set(Array.from({ length: 2000 }, () => Blocks.newUid()));
  assert.equal(ids.size, 2000, "ids don't repeat");
});

check("reading a page from disk keeps only what makes sense", () => {
  const list = plain(Blocks.cleanList([
    { uid: "a", type: "p", html: "x", align: "center", evil: "<script>" },
    { uid: "a", type: "check", html: "dup id", checked: "yes" },
    { type: "image", src: "../../etc/passwd" },
    { type: "image", src: "assets/pic-1.png", width: 7, align: "up" },
    { type: "callout", tone: "neon", icon: "<b>" },
    { type: "rocket" },
    "junk", null, 42,
  ]));
  assert.equal(list.length, 4);
  assert.deepEqual(list[0], { uid: "a", type: "p", indent: 0, html: "x", align: "center" });
  assert.notEqual(list[1].uid, "a", "a repeated id gets a new one");
  assert.equal(list[1].checked, false, "only true is checked");
  assert.deepEqual([list[2].src, list[2].width, list[2].align], ["assets/pic-1.png", 1, "center"], "a picture outside the notebook is dropped");
  assert.equal(list[3].tone, "yellow");
  assert.equal(list[3].icon, undefined);
  assert.equal(plain(Blocks.cleanList([])).length, 1, "a page always has a block to type in");
  assert.equal(plain(Blocks.cleanList("nope")).length, 1);
});

check("text from a page file is only Uber Notebook's own formatting", () => {
  const b = plain(Blocks.clean({ type: "p", html: 'hi <img src="https://track.example/x.png" /><span style="background-image:url(https://e.x/a.png); color:#aa0000; font-weight:700;">there</span> <a href="javascript:alert(1)">bad</a> <a href="https://ok.org">ok</a>' }));
  assert.equal(b.html, 'hi <span style="color:#aa0000; font-weight:700;">there</span> bad <a href="https://ok.org">ok</a>');
});

check("numbered lists count like an outline", () => {
  const blocks = [
    b("number", { uid: "n1" }), b("number", { uid: "n2" }),
    b("number", { uid: "n2a", indent: 1 }), b("number", { uid: "n2b", indent: 1 }),
    b("bullet", { uid: "x", indent: 2 }),
    b("number", { uid: "n2b1", indent: 2 }),
    b("number", { uid: "n3" }),
    b("p", { uid: "gap" }),
    b("number", { uid: "m1" }),
    b("h2", { uid: "head" }),
    b("number", { uid: "k1", indent: 1 }),
  ].map((x, i) => Object.assign(x, { uid: ["n1", "n2", "n2a", "n2b", "x", "n2b1", "n3", "gap", "m1", "head", "k1"][i] }));
  const labels = plain(Blocks.numbering(blocks));
  assert.equal(labels.n1, "1.");
  assert.equal(labels.n2, "2.");
  assert.equal(labels.n2a, "a.");
  assert.equal(labels.n2b, "b.");
  assert.equal(labels.n2b1, "i.");
  assert.equal(labels.n3, "3.", "counts on after deeper items");
  assert.equal(labels.m1, "1.", "starts again after text");
  assert.equal(labels.k1, "a.", "starts again after a heading");
  assert.equal(labels.x, undefined, "bullets have no number");
  assert.equal(Blocks.roman(1994), "mcmxciv");
  assert.equal(Blocks.letters(28), "ab");
});

check("markdown shortcuts", () => {
  const cases = { "-": "bullet", "*": "bullet", "1.": "number", "12)": "number", "[]": "check", "[ ]": "check", "#": "h1", "##": "h2", "###": "h3", ">": "quote", "```": "code", "!!": "callout" };
  for (const [prefix, type] of Object.entries(cases)) assert.equal(Blocks.shortcut(prefix).type, type, prefix);
  assert.equal(Blocks.shortcut("[x]").checked, true);
  for (const nope of ["", "--", "####", "1", "a.", "- x", "1000."]) assert.equal(Blocks.shortcut(nope), null, nope);
  assert.equal(Blocks.isDividerText("---"), true);
  assert.equal(Blocks.isDividerText(" *** "), true);
  assert.equal(Blocks.isDividerText("--"), false);
});

check("enter and backspace", () => {
  assert.equal(Blocks.kindAfterEnter("h1", true), "p");
  assert.equal(Blocks.kindAfterEnter("h2", false), "h2");
  assert.equal(Blocks.kindAfterEnter("check", true), "check");
  assert.equal(Blocks.kindAfterEnter("quote", true), "quote");
  assert.equal(Blocks.kindAfterEnter("code", true), "p");
  assert.equal(Blocks.backspaceAction({ type: "bullet", indent: 2 }), "convert");
  assert.equal(Blocks.backspaceAction({ type: "p", indent: 1 }), "outdent");
  assert.equal(Blocks.backspaceAction({ type: "p", indent: 0 }), "merge");
});

check("text of a page", () => {
  const blocks = [b("h1", { html: "Groceries" }), b("check", { html: "milk", checked: true }), b("check", { html: "eggs &amp; ham" }), b("divider")];
  assert.equal(Blocks.plainText(blocks), "Groceries\nmilk\neggs & ham");
  assert.equal(Blocks.firstLine(blocks), "Groceries");
  assert.equal(Blocks.firstLine([b("p", { html: "x".repeat(80) })], 10), "xxxxxxxxx…");
  assert.equal(Blocks.wordCount(blocks), 5);
  assert.deepEqual(plain(Blocks.checklistProgress(blocks)), { total: 2, done: 1 });
  assert.equal(Blocks.isBlank([b("p")]), true);
  assert.equal(Blocks.isBlank([b("p", { html: " " })]), true);
  assert.equal(Blocks.isBlank([b("divider")]), false);
});

check("planner blocks", () => {
  const list = plain(Blocks.cleanList([
    { type: "time", label: "  07:00\n", html: "run" },
    { type: "time", label: "a very long label indeed", html: "" },
    { type: "habit", days: "0101000", html: "read", hint: "A habit\u2028to keep" },
    { type: "habit", days: "yes" },
    { type: "calendar", month: "2026-09", marks: "14, 3,3,40,x,21" },
    { type: "calendar", month: "2026-13", marks: 7 },
    { type: "divider", hint: "not text" },
  ]));
  assert.equal(list[0].label, "07:00");
  assert.equal(list[1].label.length, 12, "labels are short");
  assert.deepEqual([list[2].days, list[2].hint], ["0101000", "A habit to keep"]);
  assert.equal(list[3].days, "0000000");
  assert.deepEqual([list[4].month, list[4].marks], ["2026-09", "3,14,21"]);
  assert.match(list[5].month, /^\d{4}-\d{2}$/, "a bad month is this month");
  assert.equal(list[5].marks, "");
  assert.equal(list[6].hint, undefined, "hints are for text");
  assert.equal(b("habit").days, "0000000");
  assert.match(b("calendar").month, /^\d{4}-\d{2}$/);
});

check("time slots", () => {
  assert.equal(Blocks.nextLabel("07:00", ""), "08:00");
  assert.equal(Blocks.nextLabel("09:30", "09:00"), "10:00", "the same step as before");
  assert.equal(Blocks.nextLabel("23:00", "22:00"), "00:00");
  assert.equal(Blocks.nextLabel("12:00", "07:00"), "13:00", "big gaps aren't steps");
  assert.equal(Blocks.nextLabel("Mon 3", "Sun 2"), "");
  assert.deepEqual(plain(Blocks.shortcut("9:30")), { type: "time", label: "09:30" });
  assert.equal(Blocks.shortcut("24:00"), null);
  assert.equal(Blocks.shortcut("9:5"), null);
  assert.equal(Blocks.kindAfterEnter("habit", true), "habit");
  assert.equal(Blocks.kindAfterEnter("time", true), "p");
});

check("calendars and habits", () => {
  assert.deepEqual(plain(Blocks.monthLayout("2026-09")), { offset: 1, days: 30, weeks: 5 });
  assert.deepEqual(plain(Blocks.monthLayout("2026-02")), { offset: 6, days: 28, weeks: 5 });
  assert.deepEqual(plain(Blocks.monthLayout("2027-02")), { offset: 0, days: 28, weeks: 4 });
  assert.deepEqual(plain(Blocks.monthLayout("2026-08")), { offset: 5, days: 31, weeks: 6 });
  assert.equal(Blocks.shiftMonth("2026-12", 1), "2027-01");
  assert.equal(Blocks.shiftMonth("2026-01", -1), "2025-12");
  assert.equal(Blocks.toggleMark("3,14", 7), "3,7,14");
  assert.equal(Blocks.toggleMark("3,7,14", 7), "3,14");
  assert.equal(Blocks.toggleMark("", 32), "");
  assert.equal(Blocks.hasMark("3,14", 14), true);
  assert.equal(Blocks.hasMark("3,14", 1), false);
  assert.equal(Blocks.toggleDay("0000000", 2), "0010000");
  assert.equal(Blocks.toggleDay("0010000", 2), "0000000");
  assert.equal(Blocks.toggleDay("0010000", 9), "0010000");
});

check("moving blocks", () => {
  assert.deepEqual(plain(Blocks.moveRange(5, 1, 2, -1)), { from: 0, to: 1 });
  assert.equal(Blocks.moveRange(5, 0, 1, -1), null);
  assert.equal(Blocks.moveRange(5, 3, 4, 1), null);
});

check("numbers in Pages go by the lists they're in, not by columns", () => {
  const list = [
    { uid: "cols", type: "columns", indent: 0 }, { uid: "col", type: "column", indent: 1 },
    { uid: "a", type: "number", indent: 2 }, { uid: "b", type: "number", indent: 2 },
    { uid: "c", type: "number", indent: 3 }, { uid: "t", type: "toggle", indent: 2 }, { uid: "d", type: "number", indent: 3 },
    { uid: "e", type: "bullet", indent: 0 }, { uid: "f", type: "number", indent: 1 },
  ];
  const doc = plain(Blocks.numbering(list, true));
  assert.deepEqual([doc.a, doc.b, doc.c, doc.d, doc.f], ["1.", "2.", "a.", "1.", "a."]);
  const paper = plain(Blocks.numbering(list));
  assert.equal(paper.a, "i.", "a notebook's lists still go by depth");
});

console.log(`blocks: ${passed} checks passed`);
