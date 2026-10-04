// Checks equations: kept as links that hold their LaTeX, shown as images
// that say which equation they are, MathJax's SVG sized and colored for Qt,
// and `$…$` read from Markdown as pandoc reads it.
// Usage (from the plugin directory): node tests/equations.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { load, plain, root } = require("./load.cjs");

const E = load("Equations.js");
const Html = load("Html.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("an equation in a line is a link that keeps its LaTeX", () => {
  const tex = "\\frac{a}{b} + x^2 & y < z";
  const l = E.link(tex);
  assert.match(l, /^<a href="uber-notebook:\/\/math\/[^"]+">/);
  assert.ok(l.includes("&amp;") && l.includes("&lt;"), "its text escaped");
  const links = plain(Html.links(l));
  assert.equal(links.length, 1);
  assert.equal(E.texOf(links[0].href), tex, "the LaTeX back from its address");
  assert.equal(Html.plainText(l), tex, "its text is its LaTeX (search, agents)");
  assert.equal(E.link("  "), "", "nothing: no link");
  assert.equal(E.texOf("https://example.com"), "");
  assert.equal(E.texOf("uber-notebook://math/%E0%A4%A"), "", "a broken address: nothing");
  assert.deepEqual(plain(E.inText("a " + E.link("x^2") + " b " + E.link("y") + " <a href=\"https://x.org\">x</a>")), ["x^2", "y"]);
  assert.equal(E.clean("x".repeat(5000)).length, E.MAX_TEX);
});

check("the link is an internal one: pasting keeps it", () => {
  const l = E.link("e^{i\\pi} + 1 = 0");
  assert.ok(Html.isInternal(plain(Html.links(l))[0].href));
  assert.equal(Html.sanitize(l), l.replace(/^<a href="([^"]+)">(.*)<\/a>$/, "<a href=\"$1\">$2</a>"));
  assert.equal(E.texOf(plain(Html.links(Html.sanitize(l)))[0].href), "e^{i\\pi} + 1 = 0");
});

const sample = "<svg style=\"vertical-align: -2.063ex;\" xmlns=\"http://www.w3.org/2000/svg\" width=\"13.932ex\" height=\"5.59ex\" role=\"img\" focusable=\"false\" viewBox=\"0 -1559 6157.7 2470.9\"><g stroke=\"currentColor\" fill=\"currentColor\"><path d=\"M0 0\"/></g></svg>";

check("MathJax's drawing, sized for Qt and in the text's color", () => {
  const b = plain(E.measure(sample));
  assert.equal(b.w, 6.1577);
  assert.equal(b.h, 2.4709);
  assert.ok(Math.abs(b.depth - 0.9119) < 1e-9, "how far below the line: " + b.depth);
  const s = plain(E.sized(sample, 20, "#c8d0e8"));
  assert.ok(Math.abs(s.width - 123.154) < 1e-9 && Math.abs(s.height - 49.418) < 1e-9);
  assert.match(s.svg, /^<svg[^>]* width="123\.15px"/);
  assert.match(s.svg, /^<svg[^>]* height="49\.42px"/);
  assert.ok(!/ex"/.test(s.svg), "no ex units (Qt doesn't know them)");
  assert.ok(!/style=/.test(s.svg.slice(0, 200)));
  assert.ok(!s.svg.includes("currentColor") && s.svg.includes("#c8d0e8"));
  assert.equal(E.measure("<svg></svg>"), null);
  assert.equal(E.sized("nope", 16, "#000"), null);
  assert.equal(E.errorOf("<g data-mml-node=\"merror\" data-mjx-error=\"Missing close brace\">"), "Missing close brace");
  assert.equal(E.errorOf(sample), "");
});

check("in the editor, an image that says which equation it is; kept as its link", () => {
  const inner = "Energy " + E.link("E = mc^2") + " and " + E.link("\\frac{1}{2}") + ".";
  const drawn = { "E = mc^2": E.sized(sample, 16, "#111111") };
  const shown = E.toImages(inner, (t) => drawn[t] || null, 16, "#111111");
  const imgs = shown.match(/<img [^>]+>/g);
  assert.equal(imgs.length, 2);
  assert.ok(!shown.includes("<a "), "no links left");
  assert.match(imgs[0], /width="99" height="40"/, "the drawing's size");
  assert.equal(E.texOfImage(/src="([^"]+)"/.exec(imgs[0])[1]), "E = mc^2");
  assert.ok(decodeURIComponent(/src="data:image\/svg\+xml;uber-notebook-math=[^,]*,([^"]+)"/.exec(imgs[1])[1]).includes("\\frac{1}{2}"), "one being drawn: its LaTeX, faint");
  assert.equal(E.toLinks(shown), inner, "and back, as it was");
  // As Qt writes it back (attributes its way, a self-closing tag).
  const asQt = shown.replace(/<img src="([^"]+)" width="(\d+)" height="(\d+)" style="vertical-align: middle;" \/>/g, "<img src=\"$1\" width=\"$2\" height=\"$3\" style=\"vertical-align: middle;\" />");
  assert.equal(E.toLinks(asQt), inner);
  assert.equal(E.toLinks("<img src=\"pic.png\" />"), "<img src=\"pic.png\" />", "a picture stays a picture");
  assert.equal(E.texOfImage("data:image/png;base64,AAAA"), "");
  assert.equal(E.toImages("no equations", null, 16, "#000"), "no equations");
});

check("$\u2026$ in Markdown, as pandoc reads it", () => {
  const spans = (t) => plain(E.inlineSpans(t)).map((s) => s.tex);
  assert.deepEqual(spans("Energy $E = mc^2$ here."), ["E = mc^2"]);
  assert.deepEqual(spans("It costs $5 and $10."), [], "money stays money");
  assert.deepEqual(spans("$ x$ and $x $"), [], "not with a space inside the marks");
  assert.deepEqual(spans("$a$ and $b$"), ["a", "b"]);
  assert.deepEqual(spans("`$not$` but $yes$"), ["yes"], "not in code");
  assert.deepEqual(spans("\\$5 \\$ and $x\\$y$"), ["x\\$y"], "an escaped $ isn't a mark");
  assert.deepEqual(spans("inline $$\\sum_i x_i$$ too"), ["\\sum_i x_i"]);
  assert.deepEqual(spans("$1$2"), [], "not before a digit");
  const s = plain(E.inlineSpans("x $y$ z"))[0];
  assert.deepEqual([s.start, s.end], [2, 5]);
  assert.equal(E.fence("  a = b \n"), "$$\na = b\n$$");
  assert.ok(E.isLang("Math") && E.isLang("math") && !E.isLang("Python"));
});

check("the MathJax bundle is there, with its license and how it's built", () => {
  const dir = path.join(root, "vendor", "mathjax");
  const bundle = fs.readFileSync(path.join(dir, "tex-svg.mjs"), "utf8");
  assert.ok(bundle.length > 1000000 && bundle.length < 2500000, "about 1.6 MB: " + bundle.length);
  assert.ok(!/\.connect=/.test(bundle) && !/Styles\.connect\b/.test(bundle), "Styles.connect renamed for Qt");
  assert.ok(fs.readFileSync(path.join(dir, "LICENSE"), "utf8").includes("Apache License"));
  assert.ok(fs.readFileSync(path.join(dir, "README.md"), "utf8").includes("Styles.connectRules"), "its changes said");
  assert.ok(fs.existsSync(path.join(dir, "build", "build.mjs")) && fs.existsSync(path.join(dir, "build", "entry.js")));
});

check("MathJax draws in Node as it will in Qt", async () => {});

(async () => {
  const mod = await import(path.join(root, "vendor", "mathjax", "tex-svg.mjs"));
  const svg = mod.render("\\int_0^1 x^2 \\, dx = \\frac{1}{3}", true);
  assert.ok(/^<svg\b/.test(svg) && svg.includes("viewBox"), "an svg");
  assert.ok(E.measure(svg).w > 3, "about as wide as it should be");
  assert.equal(E.errorOf(svg), "");
  assert.ok(E.errorOf(mod.render("\\frac{a}{", false)).length > 0, "a mistake is said, not thrown");
  passed++;
  console.log(`equations: ${passed} checks passed`);
})().catch((e) => { console.error(e); process.exit(1); });
