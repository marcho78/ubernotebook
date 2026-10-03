// Checks importing other people's notes: Markdown, HTML (Notion's too),
// plain text and Evernote, into blocks with nothing that matters lost.
// Usage (from the plugin directory): node tests/import.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Import = load("Import.js");
const Html = load("Html.js");
const Blocks = load("Blocks.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

function md(text, ctx, options) { return plain(Import.fromMarkdown(text, ctx, options)); }
function shape(blocks) { return blocks.map((b) => b.type + ":" + b.indent + (b.checked ? "x" : "") + ":" + Html.plainText(b.html || "")); }
function one(text) { return md(text).blocks[0].html; }

check("words: bold, italics, strikethrough, highlights, code", () => {
  assert.equal(one("a **bold** b"), 'a <span style="font-weight:700;">bold</span> b');
  assert.equal(one("an *italic* and _this_"), 'an <span style="font-style:italic;">italic</span> and <span style="font-style:italic;">this</span>');
  const both = one("***both***");
  assert.ok(/font-weight:700/.test(both) && /font-style:italic/.test(both) && Html.plainText(both) === "both", both);
  assert.equal(one("~~gone~~ ==marked=="), '<span style="text-decoration:line-through;">gone</span> <span style="background-color:#fbf3db;">marked</span>');
  assert.equal(one("run `ls -la` now"), 'run <span style="font-family:\'iA Writer Mono S\';">ls -la</span> now');
  assert.equal(Html.plainText(one("``a `b` c``")), "a `b` c", "backticks inside code");
  assert.equal(one("snake_case_name and 2*3*4"), "snake_case_name and 2<span style=\"font-style:italic;\">3</span>4");
  assert.equal(one("\\*not italic\\*"), "*not italic*");
  assert.equal(one("**unclosed"), "**unclosed");
  assert.equal(one("<u>under</u> <kbd>Ctrl</kbd>"), '<span style="text-decoration:underline;">under</span> <span style="font-family:\'iA Writer Mono S\';">Ctrl</span>');
});

check("links: inline, references, bare addresses, wiki links", () => {
  assert.equal(one("see [the **site**](https://example.com \"title\")"), 'see <a href="https://example.com">the <span style="font-weight:700;">site</span></a>');
  assert.equal(one("go to <https://omarchy.org>"), 'go to <a href="https://omarchy.org">https://omarchy.org</a>');
  assert.equal(one("visit https://example.com/a_b."), 'visit <a href="https://example.com/a_b">https://example.com/a_b</a>.');
  assert.equal(one("[docs][d] and [d]\n\n[d]: https://d.org"), '<a href="https://d.org">docs</a> and <a href="https://d.org">d</a>');
  const id = "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b";
  const ctx = { wiki: (n) => (n === "Plans" ? id : ""), link: (h) => (h === "Plans.md" ? "uber-notebook://page/" + id : h) };
  assert.equal(md("[[Plans]] and [[Plans|the plan]] and [[Nope]]", ctx).blocks[0].html, `<a href="uber-notebook://page/${id}">Plans</a> and <a href="uber-notebook://page/${id}">the plan</a> and Nope`);
  assert.equal(md("[plan](Plans.md)", ctx).blocks[0].html, `<a href="uber-notebook://page/${id}">plan</a>`, "a link to another page imported");
  assert.equal(one("[js](javascript:alert(1))"), "js", "no odd links");
});

check("headings, paragraphs, line breaks", () => {
  const r = md("# One\n\nTitle two\n=========\n\n## Two\n### Three\n#### Four\n\nline one\nline two  \nline three\\\nfour");
  assert.deepEqual(shape(r.blocks), ["h1:0:One", "h1:0:Title two", "h2:0:Two", "h3:0:Three", "h3:0:Four", "p:0:line one line two\nline three\nfour"]);
  assert.deepEqual(shape(md("Setext two\n---").blocks), ["h2:0:Setext two"]);
  assert.deepEqual(shape(md("text\n\n---\n\nmore").blocks), ["p:0:text", "divider:0:", "p:0:more"]);
});

check("lists: nested, numbered, to-dos with their ticks", () => {
  const r = md("- one\n  - one a\n    - one a i\n- two\n\n1. first\n2. second\n   continued\n\n   another paragraph\n3. third\n\n- [ ] todo\n- [x] done\n  - [X] done too\n* star\n+ plus");
  assert.deepEqual(shape(r.blocks), [
    "bullet:0:one", "bullet:1:one a", "bullet:2:one a i", "bullet:0:two",
    "number:0:first", "number:0:second continued", "p:1:another paragraph", "number:0:third",
    "check:0:todo", "check:0x:done", "check:1x:done too", "bullet:0:star", "bullet:0:plus",
  ]);
  assert.deepEqual(shape(md("- a\nlazy line\n- b").blocks), ["bullet:0:a lazy line", "bullet:0:b"]);
  assert.deepEqual(shape(md("1) paren").blocks), ["number:0:paren"]);
});

check("quotes and callouts", () => {
  assert.deepEqual(shape(md("> a quote\n> goes on\n>\n> - with a list").blocks), ["quote:0:a quote goes on", "bullet:1:with a list"]);
  const c = md("> [!WARNING]\n> Careful **now**\n> more").blocks;
  assert.equal(c[0].type, "callout");
  assert.equal(c[0].icon, "\u26a0\ufe0f");
  assert.equal(c[0].color, "yellow_background");
  assert.equal(Html.plainText(c[0].html), "Careful now more");
  const aside = md("<aside>\n\u{1f4a1} Notion callout\n\nwith more\n\n</aside>").blocks;
  assert.deepEqual([aside[0].type, aside[0].icon, Html.plainText(aside[0].html)], ["callout", "\u{1f4a1}", "Notion callout"]);
  assert.deepEqual(shape(aside.slice(1)), ["p:1:with more"]);
  const det = md("<details>\n<summary>More</summary>\n\nHidden **text**\n</details>").blocks;
  assert.deepEqual(shape(det), ["toggle:0:More", "p:1:Hidden text"]);
});

check("code, tables, pictures", () => {
  const code = md("```py\ndef f():\n    return 1\n```\n\n    indented\n    code").blocks;
  assert.equal(code[0].lang, "Python");
  assert.equal(Html.plainText(code[0].html), "def f():\n    return 1", "every space kept");
  assert.equal(code[1].type, "code");
  assert.equal(Html.plainText(code[1].html), "indented\ncode");
  assert.equal(md("```weirdlang\nx\n```").blocks[0].lang, "weirdlang", "a language Pages doesn't know is kept");
  const table = md("| Name | Qty |\n|---|:-:|\n| **Apples** | 3 |\n| Pears \\| plums | 10<br>more |").blocks;
  assert.equal(table.length, 1);
  assert.equal(table[0].type, "table", "a table, not its text");
  const t = table[0].table;
  assert.equal(t.header, true);
  assert.deepEqual(t.rows.map((r) => r.map((c) => Html.plainText(c))), [["Name", "Qty"], ["Apples", "3"], ["Pears | plums", "10\nmore"]]);
  assert.match(t.rows[1][0], /font-weight:700/, "a cell keeps its bold");
  const kept = plain(Blocks.clean(table[0], { nest: true }));
  assert.deepEqual(kept.table.rows, t.rows, "and it's kept as it is");
  assert.equal(Blocks.clean(table[0], null), null, "only in Pages");
  const ctx = { image: (src) => (src === "img/a.png" ? "assets/a.png" : "") };
  const pics = md("![A](img/a.png)\n\n![Web](https://x.org/b.png)", ctx).blocks;
  assert.deepEqual([pics[0].type, pics[0].src], ["image", "assets/a.png"]);
  assert.equal(pics[1].type, "p", "a picture on the web stays a link (Uber Notebook never goes online)");
  assert.ok(pics[1].html.includes('href="https://x.org/b.png"'));
});

check("a quick note as a page", () => {
  const q = (t) => plain(Import.quickNote(t));
  assert.equal(Import.quickNote("  \n \n"), null, "nothing in it");
  assert.deepEqual(q("Buy milk"), { title: "Buy milk", markdown: "" });
  assert.deepEqual(q("\nGroceries\n[] milk\n[x] eggs\n- bread\n"), { title: "Groceries", markdown: "- [ ] milk\n- [x] eggs\n- bread" }, "the first line the title, the quick note's to-dos Markdown's");
  assert.deepEqual(q("# Trip **plans**\n\nBook it"), { title: "Trip plans", markdown: "Book it" }, "a heading, as plain words");
  assert.deepEqual(q("- [ ] call the bank\n- [ ] pay rent"), { title: "call the bank", markdown: "- [ ] call the bank\n- [ ] pay rent" }, "a list names the page and stays in it");
  assert.deepEqual(q("> a thought"), { title: "a thought", markdown: "> a thought" });
  assert.equal(q("```js\nlet a = 1\n```").title, "Quick note");
  assert.equal(q("A | B is not a table").title, "A | B is not a table");
  const long = "This is a long first line that goes on and on about many things that I want to remember later on today";
  const r = q(long + "\nmore");
  assert.ok(r.title.length <= 81 && r.title.endsWith("\u2026"), r.title);
  assert.equal(r.markdown, long + "\n\nmore", "a long first line stays in the page");
  assert.equal(q("Plan\nline one\nline two\n- a\n- b\nafter").markdown, "line one\n\nline two\n\n- a\n- b\n\nafter", "each line its own, lists kept together");
  assert.equal(q("Code\n```\nx\ny\n```").markdown, "```\nx\ny\n```", "code as it is");
  // As blocks: the to-dos ticked or not, links to pages.
  const blocks = plain(Import.fromMarkdown(q("Groceries\n[] milk\n[x] eggs\nsee [[Shopping]]").markdown, { wiki: (n) => (n === "Shopping" ? "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b" : "") })).blocks;
  assert.deepEqual(blocks.map((b) => b.type + (b.checked ? "x" : "")), ["check", "checkx", "p"]);
  assert.ok(blocks[2].html.includes("uber-notebook://page/6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b"));
});

check("code keeps every tab and space", () => {
  const r = md("# Build\n\n```makefile\nall:\n\tgcc -o app  main.c\n\n  done\n```\n\n\tindented text");
  const code = r.blocks.find((b) => b.type === "code");
  assert.equal(Html.plainText(code.html), "all:\n\tgcc -o app  main.c\n\n  done");
  assert.equal(code.lang, "Makefile");
  assert.ok(!/&nbsp;|\u00a0/.test(code.html), "plain spaces, as Pages keeps code");
  const html = plain(Import.fromHtml('<pre><code class="language-go">func main() {\n\tx  := 1\n}</code></pre>', null, {}));
  assert.equal(Html.plainText(html.blocks[0].html), "func main() {\n\tx  := 1\n}");
  assert.equal(html.blocks[0].lang, "Go");
});

check("titles: front matter, a first heading", () => {
  assert.equal(md("---\ntitle: \"From front matter\"\ntags: [a]\n---\n\ntext").title, "From front matter");
  const h = md("# The title\n\ntext", null, { titleFromHeading: true });
  assert.equal(h.title, "The title");
  assert.deepEqual(shape(h.blocks), ["p:0:text"]);
  assert.equal(md("# Not the title\n\ntext").title, "", "only when asked");
  assert.equal(Import.looksLikeMarkdown("# Heading\n\ntext"), true);
  assert.equal(Import.looksLikeMarkdown("- a\n- b"), true);
  assert.equal(Import.looksLikeMarkdown("just some words"), false);
  assert.equal(Import.looksLikeMarkdown("two lines\nof words"), false);
  assert.equal(Import.looksLikeMarkdown("see **this**"), true);
});

check("HTML, and what Notion's export has in it", () => {
  const page = "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b";
  const html = `<html><head><title>Plans</title></head><body><article class="page">
    <header><div class="page-header-icon"><span class="icon">\u{1f5fa}\ufe0f</span></div><h1 class="page-title">Plans</h1></header>
    <div class="page-body">
      <h2>Trip</h2>
      <p>Book <strong>flights</strong> and <mark class="highlight-red">hotel</mark>.</p>
      <p class="block-color-blue_background">A blue block</p>
      <ul class="to-do-list"><li><div class="checkbox checkbox-on"></div> <span class="to-do-children-checked">Passport</span></li><li><div class="checkbox checkbox-off"></div> <span>Tickets</span></li></ul>
      <ul class="toggle"><li><details open=""><summary>More</summary><p>Inside</p></details></li></ul>
      <figure class="block-color-gray_background callout" style="white-space:pre-wrap;display:flex"><div style="font-size:1.5em"><span class="icon">\u{1f4a1}</span></div><div style="width:100%"><p>Note this</p></div></figure>
      <div class="column-list"><div style="width:50%" class="column"><p>Left</p></div><div style="width:50%" class="column"><p>Right</p></div></div>
      <pre class="code"><code class="language-JavaScript">let a = 1
  let b = 2</code></pre>
      <blockquote>Quoted</blockquote>
      <ol><li>One<ul><li>Nested</li></ul></li><li>Two</li></ol>
      <table><tr><th>A</th><th>B</th></tr><tr><td>1</td><td>2</td></tr></table>
      <figure class="link-to-page"><a href="Other%20${page.replace(/-/g, "")}.html">Other</a></figure>
      <hr/>
      <p><img src="Plans/pic.png" alt="pic"/></p>
    </div></article></body></html>`;
  const ctx = {
    link: (h) => (/Other/.test(h) ? "uber-notebook://page/" + page : h),
    image: (s) => (s === "Plans/pic.png" ? "assets/pic.png" : ""),
  };
  const r = plain(Import.fromHtml(html, ctx));
  assert.equal(r.title, "Plans");
  assert.equal(r.icon, "\u{1f5fa}\ufe0f");
  assert.deepEqual(shape(r.blocks), [
    "h2:0:Trip", "p:0:Book flights and hotel.", "p:0:A blue block",
    "check:0x:Passport", "check:0:Tickets",
    "toggle:0:More", "p:1:Inside",
    "callout:0:Note this",
    "columns:0:", "column:1:", "p:2:Left", "column:1:", "p:2:Right",
    "code:0:let a = 1\n  let b = 2",
    "quote:0:Quoted",
    "number:0:One", "bullet:1:Nested", "number:0:Two",
    "table:0:",
    "link:0:", "divider:0:", "image:0:",
  ]);
  const byType = (t) => r.blocks.find((b) => b.type === t);
  assert.deepEqual(byType("table").table, { rows: [["A", "B"], ["1", "2"]], header: true }, "a table, its <th> row the header");
  assert.ok(r.blocks[1].html.includes("color:#d44c47"), "Notion's red words stay red");
  assert.equal(r.blocks[2].color, "blue_background", "and its colored blocks colored");
  assert.ok(!byType("toggle").collapsed, "an open toggle stays open");
  assert.equal(byType("callout").icon, "\u{1f4a1}");
  assert.equal(byType("code").lang, "JavaScript");
  assert.equal(byType("column").width, 0.5);
  assert.equal(byType("link").target, page);
  assert.equal(byType("image").src, "assets/pic.png");
});

check("HTML from Word and LibreOffice", () => {
  const r = plain(Import.fromHtml("<ul><li><p>North</p></li><li><p>South</p><ul><li><p>deep</p></li></ul></li></ul><ol><li><p style=\"margin-bottom: 0in\">first</p></li></ol>"));
  assert.deepEqual(shape(r.blocks), ["bullet:0:North", "bullet:0:South", "bullet:1:deep", "number:0:first"]);
});

check("plain text and Evernote", () => {
  assert.deepEqual(shape(plain(Import.fromText("one\ntwo\n\n\nthree  spaced\n")).blocks), ["p:0:one", "p:0:two", "p:0:", "p:0:three  spaced"]);
  const enex = `<?xml version="1.0"?><en-export><note><title>Groceries &amp; more</title><content><![CDATA[<?xml version="1.0"?><en-note><div><en-todo checked="true"/>Milk</div><div><en-todo/>Eggs</div></en-note>]]></content><created>20260930T101500Z</created></note></en-export>`;
  const notes = plain(Import.enexNotes(enex));
  assert.equal(notes.length, 1);
  assert.equal(notes[0].title, "Groceries & more");
  assert.equal(notes[0].created, "2026-09-30T10:15:00Z");
  assert.ok(notes[0].html.includes('type="checkbox" checked'));
});

check("file names and where things are", () => {
  assert.equal(Import.notionId("Plans 6f1c2b9e0d3a4f6e9b1c2e8a7d5f4c3b.md"), "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b");
  assert.equal(Import.notionId("Plans.md"), "");
  assert.equal(Import.titleFromName("/x/My%20Plans 6f1c2b9e0d3a4f6e9b1c2e8a7d5f4c3b.md"), "My Plans");
  assert.equal(Import.titleFromName("/x/notes_on_things.markdown"), "notes on things");
  assert.equal(Import.kindOf("a.MD"), "markdown");
  assert.equal(Import.kindOf("a.docx"), "office");
  assert.equal(Import.kindOf("a.htm"), "html");
  assert.equal(Import.kindOf("a.enex"), "enex");
  assert.equal(Import.kindOf("a.zip"), "zip");
  assert.equal(Import.kindOf("a.png"), "");
  assert.equal(Import.resolvePath("/n/export/Plans/a.md", "img/pic%20one.png", "/n/export"), "/n/export/Plans/img/pic one.png");
  assert.equal(Import.resolvePath("/n/export/a.md", "../../etc/passwd", "/n/export"), "", "not out of the folder imported");
  assert.equal(Import.resolvePath("/n/a.md", "https://x.org/a.png"), "");
});

console.log(`import: ${passed} checks passed`);
