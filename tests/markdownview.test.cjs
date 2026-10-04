// Checks Markdown someone else wrote, shown as rich text Qt draws without
// fetching or running anything (MarkdownView.js).
// Usage (from the plugin directory): node tests/markdownview.test.cjs

const assert = require("node:assert/strict");
const { load } = require("./load.cjs");

const View = load("MarkdownView.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("what an agent writes: headings, lists, to-dos, code, tables, links", () => {
  const r = View.rich("# Done\n\nI made **three** to-dos:\n\n- [x] Milk\n- [ ] Eggs\n1. one\n2. two\n\n> a quote\n\n```js\nvar a = 1 < 2\n```\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\nSee [the docs](https://e.org/a).", 13);
  assert.ok(r.includes('<span style="font-weight:700; font-size:18px;">Done</span>'), r);
  assert.ok(r.includes('<span style="font-weight:700;">three</span>'));
  assert.ok(r.includes("☑&nbsp;Milk") && r.includes("☐&nbsp;Eggs"));
  assert.ok(r.includes("1.&nbsp;one") && r.includes("2.&nbsp;two"));
  assert.ok(r.includes("<i>a quote</i>"));
  assert.ok(r.includes("<pre>var a = 1 &lt; 2</pre>"));
  assert.ok(r.includes("a │ b") && r.includes("1 │ 2"));
  assert.ok(r.includes('<a href="https://e.org/a">the docs</a>'));
});

check("nothing in it is fetched or run: no pictures, no HTML, no odd links", () => {
  const evil = [
    "![track](https://x.invalid/t.png)", "![t][x]\n\n[x]: https://x.invalid/ref.png", "<img src=\"https://x.invalid/a.png\">",
    "< img src=https://x.invalid/b.png>", "<script>alert(1)</script>", "[a](javascript:alert(1))", "[f](file:///etc/passwd)",
    "<span style=\"background-image:url(https://x.invalid/c.png)\">x</span>", "<a href=\"https://x.invalid\" style=\"color:red\" onclick=\"x()\">y</a>",
    "<iframe src=\"https://x.invalid\"></iframe>", "<link rel=stylesheet href=https://x.invalid/s.css>", "text <style>p{background:url(https://x.invalid/d.png)}</style>"
  ].join("\n\n");
  const r = View.rich(evil, 13);
  // Only these tags, with only these attributes, links only to the web.
  const tags = r.match(/<[^>]*>/g) || [];
  for (const t of tags) {
    assert.match(t, /^<\/?(p|span|a|i|pre|br)( (style|href)="[^"<>]*")*\s*\/?>$/, t);
    const href = /href="([^"]*)"/.exec(t);
    if (href) assert.match(href[1], /^(https?:\/\/|mailto:)/, t);
    const style = /style="([^"]*)"/.exec(t);
    if (style) assert.ok(!/url\(|expression|import/i.test(style[1]), t);
  }
  assert.ok(r.includes("&lt; img src=https://x.invalid/b.png&gt;"), "a broken tag stays text");
  // A picture's link stays a link (to open it, if you want).
  assert.ok(r.includes('<a href="https://x.invalid/t.png">track</a>'), r);
});

check("too much: cut, with an ellipsis; anything at all: something to show", () => {
  const big = "x".repeat(View.MAX + 500);
  const r = View.rich(big, 13);
  assert.ok(r.length < View.MAX + 200 && r.includes("…"));
  assert.equal(View.rich("", 13), "");
  assert.equal(typeof View.rich(null, 13), "string");
});

console.log(`markdownview: ${passed} checks passed`);
