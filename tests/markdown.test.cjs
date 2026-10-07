// Checks pages exported as Markdown.
// Usage (from the plugin directory): node tests/markdown.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Markdown = load("Markdown.js");
const Blocks = load("Blocks.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

function b(type, props) { return plain(Blocks.make(type, props)); }

check("inline formatting", () => {
  assert.equal(Markdown.inline('a <span style=" font-weight:700;">bold </span>move'), "a **bold** move", "spaces stay outside the markers");
  assert.equal(Markdown.inline('<span style=" font-weight:700;">x</span><span style=" font-weight:700; color:#ff0000;">y</span>'), "**xy**", "colors don't split it");
  assert.equal(Markdown.inline('<span style=" font-style:italic; text-decoration: line-through;">gone</span>'), "*~~gone~~*");
  assert.equal(Markdown.inline('<span style=" background-color:#fff27a;">key</span> <span style=" text-decoration: underline;">u</span>'), "==key== <u>u</u>");
  assert.equal(Markdown.inline("<span style=\" font-family:'iA Writer Mono S';\">a`b</span>"), "``a`b``");
  assert.equal(Markdown.inline('<a href="https://e.org/a b">site</a>'), "[site](https://e.org/a%20b)");
  assert.equal(Markdown.inline("1 * 2 = [x] &lt;y&gt;"), "1 \\* 2 \\= \\[x\\] \\<y\\>");
  assert.equal(Markdown.inline("line<br />next"), "line\\\nnext");
});

check("blocks", () => {
  const md = Markdown.fromBlocks([
    b("h1", { html: "Trip" }),
    b("p", { html: "Packing:" }),
    b("check", { html: "passport", checked: true }),
    b("check", { html: "socks" }),
    b("number", { html: "fly" }),
    b("number", { html: "land" }),
    b("number", { html: "taxi", indent: 1 }),
    b("bullet", { html: "note", indent: 2 }),
    b("quote", { html: "Go far" }),
    b("callout", { html: "Remember" }),
    b("code", { html: "ls -la<br />cd ~" }),
    b("divider"),
    b("image", { src: "assets/p.png" }),
  ]);
  assert.equal(md, [
    "# Trip",
    "",
    "Packing:",
    "",
    "- [x] passport",
    "- [ ] socks",
    "1. fly",
    "2. land",
    "   1. taxi",
    "      - note",
    "",
    "> Go far",
    "",
    "> [!NOTE]",
    "> Remember",
    "",
    "```",
    "ls -la",
    "cd ~",
    "```",
    "",
    "---",
    "",
    "![](assets/p.png)",
    "",
  ].join("\n"));
});

check("planner blocks", () => {
  const md = Markdown.fromBlocks([
    b("time", { label: "07:00", html: "Run" }),
    b("time", { label: "08:00" }),
    b("habit", { html: "Read", days: "1010000" }),
    b("habit", { html: "a|b", days: "0000001" }),
    b("calendar", { month: "2026-09", marks: "3,30" }),
  ]);
  assert.equal(md, [
    "- **07:00** Run",
    "- **08:00**",
    "",
    "| Habit | Mo | Tu | We | Th | Fr | Sa | Su |",
    "| --- | :-: | :-: | :-: | :-: | :-: | :-: | :-: |",
    "| Read | \u2713 |   | \u2713 |   |   |   |   |",
    "| a\\|b |   |   |   |   |   |   | \u2713 |",
    "",
    "**September 2026**",
    "",
    "| Mo | Tu | We | Th | Fr | Sa | Su |",
    "| :-: | :-: | :-: | :-: | :-: | :-: | :-: |",
    "|   | 1 | 2 | **3** | 4 | 5 | 6 |",
    "| 7 | 8 | 9 | 10 | 11 | 12 | 13 |",
    "| 14 | 15 | 16 | 17 | 18 | 19 | 20 |",
    "| 21 | 22 | 23 | 24 | 25 | 26 | 27 |",
    "| 28 | 29 | **30** |   |   |   |   |",
    "",
  ].join("\n"));
});

check("a page in Pages", () => {
  const W = load("Workspace.js");
  const [p, a, b, c, d, e, f, sub] = Array.from({ length: 8 }, () => W.uuid4());
  const page = W.cleanPage({
    title: "Plan", icon: "\u{1f5fa}\u{fe0f}",
    content: [a, d, e, sub, f],
    blocks: {
      [a]: { type: "toggle", html: "Trip", content: [b] },
      [b]: { type: "check", html: "tickets", checked: true, content: [c] },
      [c]: { type: "p", html: "by Friday" },
      [d]: { type: "callout", icon: "\u{1f4a1}", html: "Remember", content: [] },
      [e]: { type: "code", html: "ls", lang: "Bash" },
      [sub]: { type: "page" },
      [f]: { type: "number", html: "one" },
    },
  }, p);
  const md = Markdown.fromDocPage(page, (id) => (id === sub ? { title: "Ideas", icon: "", file: "Ideas.md" } : null));
  assert.equal(md, [
    "# \u{1f5fa}\u{fe0f} Plan",
    "",
    "- Trip",
    "  - [x] tickets",
    "    by Friday",
    "",
    "> \u{1f4a1} Remember",
    "",
    "```bash",
    "ls",
    "```",
    "",
    "[Ideas](Ideas.md)",
    "",
    "1. one",
    "",
  ].join("\n"));
});

check("columns in Markdown", () => {
  const W = load("Workspace.js");
  const [p, cs, c1, c2, a, b] = Array.from({ length: 6 }, () => W.uuid4());
  const page = W.cleanPage({ content: [cs], blocks: { [cs]: { type: "columns", content: [c1, c2] }, [c1]: { type: "column", content: [a] }, [c2]: { type: "column", content: [b] }, [a]: { type: "p", html: "left" }, [b]: { type: "bullet", html: "right" } } }, p);
  assert.equal(Markdown.fromDocPage(page, () => null), "left\n\n- right\n", "one after the other, not indented");
});

check("a page and its file name", () => {
  const page = { title: "Plan *A*", created: "2026-09-30T10:00:00Z", blocks: [b("p", { html: "go" })] };
  assert.equal(Markdown.fromPage(page), "# Plan \\*A\\*\n\ngo\n");
  assert.equal(Markdown.fileName(page, 0), "2026-09-30 Plan *A*.md".replace("*A*", "A"));
  assert.equal(Markdown.fileName({ title: "a/b:c", created: "" , blocks: [] }, 2), "a b c.md");
  assert.equal(Markdown.fileName({ blocks: [] }, 2), "Page 3.md");
});

check("habits and calendars in Pages", () => {
  const W = load("Workspace.js");
  const [p, h1, h2, x, cal] = Array.from({ length: 5 }, () => W.uuid4());
  const page = W.cleanPage({ content: [h1, h2, x, cal], blocks: {
    [h1]: { type: "habit", html: "Run", days: "1010000" }, [h2]: { type: "habit", html: "Read", days: "0000001" },
    [x]: { type: "p", html: "then" }, [cal]: { type: "calendar", month: "2026-09", marks: "14" } } }, p);
  const md = Markdown.fromDocPage(page, () => null);
  assert.ok(md.startsWith("| Habit | Mo | Tu | We | Th | Fr | Sa | Su |\n"), md);
  assert.ok(md.includes("| Run | \u2713 |   | \u2713 |") && md.includes("| Read |") , "one table for the habits together");
  assert.equal(md.split("| Habit |").length, 2);
  assert.ok(md.includes("then\n\n**September 2026**"), "and the month as a table");
  assert.ok(md.includes("**14**"), "its circled dates in bold");
});

check("synced blocks in Markdown: never the page itself, only so many", () => {
  const A = "11111111-1111-4111-8111-111111111111", B = "22222222-2222-4222-8222-222222222222";
  const mk = (id, list) => { const blocks = {}; list.forEach((b) => { blocks[b.id] = b; }); return { id, title: id.slice(0, 1), icon: "", content: list.map((b) => b.id), blocks }; };
  const b = mk(B, [{ id: "x", type: "p", html: "y".repeat(100000) }]);
  const a = mk(A, Array.from({ length: 200 }, (_, i) => ({ id: "s" + i, type: "synced", data: { page: B } })).concat([{ id: "self", type: "synced", data: { page: A } }]));
  const md = Markdown.fromDocPage(a, () => null, { syncedPage: (id) => (id === B ? b : id === A ? a : null) });
  assert.ok(md.length < 5000000, "bounded: " + md.length);
  assert.ok(md.includes("*(A synced block)*"), "the rest said");
  // Many pages written at once (the Markdown copy), one budget for them all.
  const budget = { chars: 0, max: 1000000 };
  const many = Array.from({ length: 20 }, (_, n) => mk("p" + n, Array.from({ length: 5 }, (_, i) => ({ id: "t" + i, type: "synced", data: { page: B } }))));
  const out = many.map((p) => Markdown.fromDocPage(p, () => null, { syncedPage: (id) => (id === B ? b : null), syncedBudget: budget }));
  const total = out.reduce((n, t) => n + t.length, 0);
  assert.ok(total < 1000000 + 100000 + 20000, "all of them within it: " + total);
  assert.ok(out[19].includes("*(A synced block: open the page in Uber Notebook)*"), "past it: said");
  // For an agent: words that would read as a column's marker, escaped in
  // a synced block too (and read back as the words).
  const Import = load("Import.js");
  const Html = load("Html.js");
  const src = mk(B, [{ id: "m1", type: "p", html: "::next" }, { id: "m2", type: "p", html: "::columns 50 50" }, { id: "m3", type: "p", html: "::end" },
    { id: "m4", type: "code", html: "::next", lang: "" }]);
  const outer = mk(A, [{ id: "h", type: "h2", html: "Outer" }, { id: "s", type: "synced", data: { page: B } }]);
  const agent = Markdown.fromDocPage(outer, () => null, { fences: true, syncedPage: (id) => (id === B ? src : null) });
  assert.ok(agent.includes("\\::next\n\n\\::columns 50 50\n\n\\::end"), agent);
  const back = plain(Import.fromMarkdown(agent, null, { columns: true })).blocks;
  assert.deepEqual(back.map((x) => x.type + ":" + Html.plainText(x.html || "")), ["h1:1", "h2:Outer", "p:::next", "p:::columns 50 50", "p:::end", "code:::next"]);
  const copy = Markdown.fromDocPage(outer, () => null, { syncedPage: (id) => (id === B ? src : null) });
  assert.ok(copy.includes("\n::next\n"), "the Markdown copy: as written");
  assert.ok(out[0].includes("y".repeat(1000)), "the first pages as always");
});

console.log(`markdown: ${passed} checks passed`);
