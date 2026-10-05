// Checks a page made one HTML document for a PDF, a Word file or printing
// (Export.js): what's on it as text, never markup; links only to the web,
// email or the document; pictures named for the files helper, never linked.
// Usage (from the plugin directory): node tests/export.test.cjs

const assert = require("node:assert/strict");
const { load } = require("./load.cjs");

const Export = load("Export.js");
const Equations = load("Equations.js");
const Notes = load("Notes.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const A = "11111111-1111-4111-8111-111111111111";
const B = "22222222-2222-4222-8222-222222222222";
const C = "33333333-3333-4333-8333-333333333333";
function page(id, title, list) {
  const blocks = {};
  list.forEach((b, i) => { b.id = b.id || "b" + i; blocks[b.id] = b; });
  return { id, title, icon: "", content: list.filter((b) => !b.child).map((b) => b.id), blocks };
}
const doc = (pages, o) => Export.toHtml(pages, Object.assign({ lookup: (id) => ({ [B]: { title: "Plans" }, [C]: { title: "Elsewhere", icon: "\u{1f4c1}" } })[id] || null }, o || {}));
// The markup in it (text and attribute values taken out).
const tags = (html) => (html.match(/<[a-z][^>]*>/gi) || []).map((t) => t.replace(/"[^"]*"/g, '""'));

check("what's on a page is text, never markup", () => {
  const html = doc([page(A, "<script>alert(1)</script>", [
    { type: "p", html: "&lt;img src=x onerror=alert(1)&gt; and <b>bold</b>" },
    { type: "code", lang: "HTML", html: "&lt;iframe src=&quot;https://evil.example&quot;&gt;" },
    { type: "callout", icon: "<b>", html: "Note" }
  ])]);
  assert.ok(!/<script|<iframe|onerror=/i.test(html.replace(/&lt;[^&]*&gt;/g, "")), "no live markup");
  assert.ok(html.includes("&lt;script&gt;alert(1)&lt;/script&gt;"), "the title as its words");
  assert.ok(html.includes("&lt;img src=x onerror=alert(1)&gt;"));
  assert.ok(html.includes("<strong>bold</strong>"), "formatting as its own tags");
  assert.ok(tags(html).every((t) => /^<(html|head|meta|title|style|body|section|div|p|span|a|strong|em|u|s|sup|sub|code|pre|br|mark|h[123]|blockquote|ul|ol|li|table|tr|td|th|colgroup|col|img|hr)\b/i.test(t)), "only the tags it writes");
});

check("links: the web and email; a page in the document goes there; nothing else", () => {
  const html = doc([page(A, "Top", [
    { type: "p", html: '<a href="https://e.org/?a=1&amp;b=2">web</a> <a href="mailto:a@e.org">mail</a> <a href="javascript:alert(1)">js</a> <a href="file:///etc/passwd">file</a> <a href="uber-notebook://page/' + B + '">in it</a> <a href="uber-notebook://page/' + C + '">not in it</a> <a href="uber-notebook://tag/x">#x</a>' }
  ]), page(B, "Plans", [{ type: "p", html: "Hi" }])]);
  const hrefs = (html.match(/href="[^"]*"/g) || []);
  assert.deepEqual(hrefs, ['href="https://e.org/?a=1&amp;b=2"', 'href="mailto:a@e.org"', 'href="#p-' + B + '"']);
  for (const word of ["js", "file", "not in it", "#x"]) assert.ok(html.includes(">" + word + "<") || html.includes(" " + word), word + ": its words kept");
});

check("pictures: named for the helper, only Pages' own; never a path or the web", () => {
  const html = doc([page(A, "Pictures", [
    { type: "image", src: "assets/a.png", width: 0.5, align: "left" },
    { type: "image", src: "assets/../../etc/passwd" },
    { type: "image", src: "/home/me/x.png" },
    { type: "gallery", data: { columns: 2, images: [{ src: "assets/g1.jpg", caption: "One" }, { src: "https://evil.example/x.png", caption: "Two" }] } },
    { type: "bookmark", data: { url: "https://e.org", title: "E", image: "assets/bm-1.png" } },
    { type: "video", data: { src: "assets/v.mp4", name: "Clip", poster: "assets/v.jpg" } }
  ])]);
  const srcs = (html.match(/src="[^"]*"/g) || []);
  assert.deepEqual(srcs.filter((s) => !s.startsWith('src="data:')), ['src="uber-notebook-asset:a.png"', 'src="uber-notebook-asset:g1.jpg"', 'src="uber-notebook-asset:bm-1.png"', 'src="uber-notebook-asset:v.jpg"']);
  assert.ok(html.includes('style="width:50%;"'), "its share of the page, for the helper to size");
  assert.ok(!/passwd|evil\.example|\/home\/me/.test(html));
});

check("equations drawn in; footnotes numbered at the page's end; LaTeX shown when it couldn't be drawn", () => {
  const svg = '<svg xmlns="http://www.w3.org/2000/svg" width="2ex" height="1ex" viewBox="0 -500 1000 600"><path d="M0 0"/></svg>';
  const html = doc([page(A, "Maths", [
    { type: "p", html: "E: " + Equations.link("e=mc^2") + " and" + Notes.link("Said by Einstein") + " again" + Notes.link("Said by Einstein") },
    { type: "code", lang: "Math", html: "\\int x" },
    { type: "code", lang: "Math", html: "\\broken" }
  ])], { math: (tex) => tex === "\\broken" ? null : svg });
  assert.equal((html.match(/src="data:image\/svg\+xml;base64,/g) || []).length, 2, "two drawn");
  assert.ok(html.includes('<code class="tex">\\broken</code>'));
  assert.equal((html.match(/<sup class="fn">1<\/sup>/g) || []).length, 2, "one footnote, said twice");
  assert.ok(html.includes('<ol class="notes"><li>Said by Einstein</li></ol>'));
});

check("diagrams as their pictures, by a plain name only; other code in its colors", () => {
  const html = doc([page(A, "Code", [
    { id: "d1", type: "code", lang: "Mermaid", html: "flowchart LR<br />A --&gt; B" },
    { id: "d2", type: "code", lang: "Mermaid", html: "flowchart LR<br />C" },
    { id: "c1", type: "code", lang: "JavaScript", html: "const a = 1" }
  ])], { drawing: (id) => ({ d1: "d1.png", d2: "../../etc/x.png" })[id] });
  assert.ok(html.includes('src="uber-notebook-drawing:d1.png"'));
  assert.ok(!html.includes("etc/x.png") && /<pre class="code" id="b-d2"/.test(html), "a name that isn't one: its Mermaid instead");
  assert.ok(/<pre class="code"[^>]*><span class="lang">JavaScript<\/span><br \/><span style="color:/.test(html));
});

check("lists, to-dos, toggles, tables, columns, boards, as they stand", () => {
  const html = doc([page(A, "Lists", [
    { type: "bullet", html: "one", content: ["n1"] }, { id: "n1", child: true, type: "number", html: "inner" },
    { type: "check", html: "done", checked: true }, { type: "check", html: "to do" },
    { type: "toggle", html: "folded", collapsed: true, content: ["t1"] }, { id: "t1", child: true, type: "p", html: "inside" },
    { type: "table", table: { rows: [["H1", "H2"], ["a", "b"]], header: true, widths: [0.3, 0.7], colors: [["", ""], ["red|", "|yellow"]] } },
    { type: "columns", content: ["c1", "c2"] }, { id: "c1", child: true, type: "column", width: 1, content: ["x1"] }, { id: "c2", child: true, type: "column", width: 3, content: [] },
    { id: "x1", child: true, type: "p", html: "left" },
    { type: "board", data: { columns: [{ name: "To do", cards: [{ text: "Write" }] }, { name: "Done", cards: [] }] } }
  ])]);
  assert.ok(/<ul><li[^>]*>one<ol><li[^>]*>inner<\/li><\/ol><\/li><\/ul>/.test(html), "nested");
  assert.ok(html.includes("☑︎</span> done") && html.includes("☐︎</span> to do"), "ticked or not");
  assert.ok(html.includes('<ul class="toggles">') && html.includes("inside"), "a toggle open");
  assert.ok(/<th style="[^"]*">H1<\/th>/.test(html) && html.includes("color:#d44c47;") && html.includes("background:#fbf3db;"), "a table, its colors");
  assert.ok(html.includes('<col width="30%" />'));
  assert.ok(html.includes('<td style="width:25%;') && html.includes('<td style="width:75%;'), "columns, their shares");
  assert.ok(/<th style="[^"]*">To do<\/th>/.test(html) && html.includes("Write"), "a board's columns");
});

check("the document: its policy, one section a page, each after the first on a sheet of its own", () => {
  const html = doc([page(A, "One", []), page(B, "Two", [])], { paper: "Letter", font: "serif", small: true });
  assert.ok(html.includes(`<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'" />`));
  assert.ok(html.includes("@page { size: letter;"));
  assert.ok(html.includes('"Lora", "Noto Serif", serif') && html.includes("font-size: 14px"));
  assert.equal((html.match(/<section class="page/g) || []).length, 2);
  assert.ok(html.includes('<h1 class="title" style="page-break-before:always;">Two</h1>'));
  assert.ok(!/url\(|@import|\\/.test(html.slice(html.indexOf("<style>"), html.indexOf("</style>"))), "a style that loads nothing");
  assert.equal(Export.toHtml([page(A, "x", [])], { paper: "A3" }).includes("size: A4;"), true, "A4 unless it's Letter");
});

check("base64 of any text, as the browser reads it", () => {
  for (const t of ["", "a", "ab", "abc", "été ✓ \u{1f600}", "<svg>x</svg>"]) assert.equal(Export.base64(t), Buffer.from(t, "utf8").toString("base64"), JSON.stringify(t));
});

console.log(`export: ${passed} checks passed`);
