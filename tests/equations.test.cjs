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

// A drawing `w` × `h` em as MathJax writes one (its box in thousandths of
// an em), with `inside` in it.
function box(w, h, inside) {
  return "<svg style=\"vertical-align: 0;\" xmlns=\"http://www.w3.org/2000/svg\" width=\"1ex\" height=\"1ex\" role=\"img\" focusable=\"false\" viewBox=\"0 -"
    + Math.round(h * 1000) + " " + Math.round(w * 1000) + " " + Math.round(h * 1000) + "\"><g stroke=\"currentColor\" fill=\"currentColor\">" + (inside || "") + "</g></svg>";
}

check("an ordinary equation is drawn as it always was, to the byte", () => {
  assert.equal(E.tooBig(sample), "");
  assert.equal(E.sized(sample, 20, "#c8d0e8").svg, "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"123.15px\" height=\"49.42px\" role=\"img\" focusable=\"false\" viewBox=\"0 -1559 6157.7 2470.9\"><g stroke=\"#c8d0e8\" fill=\"#c8d0e8\"><path d=\"M0 0\"/></g></svg>");
  assert.equal(JSON.stringify(E.sized(sample, 16, "#111111", 4)), "{\"svg\":\"<svg xmlns=\\\"http://www.w3.org/2000/svg\\\" width=\\\"98.52px\\\" height=\\\"41.89px\\\" role=\\\"img\\\" focusable=\\\"false\\\" viewBox=\\\"0 -1559.0 6157.7 2618.0\\\"><g stroke=\\\"#111111\\\" fill=\\\"#111111\\\"><path d=\\\"M0 0\\\"/></g></svg>\",\"width\":98.5232,\"height\":41.888,\"depth\":16.944}", "in a line, its middle on the text's");
  const d = E.sized(sample, 16, "#111111");
  assert.equal(E.toImages(E.link("x"), () => d, 16, "#111111"), "<img src=\"" + E.imageUrl(d.svg, "x") + "\" width=\"99\" height=\"40\" style=\"vertical-align: middle;\" />");
});

check("too big to draw: at each bound it's drawn, just past it it isn't", () => {
  // Ems across or down (400), and in all (10000).
  assert.equal(E.tooBig(box(400, 25)), "");
  assert.equal(E.sized(box(400, 25), 26, "#000000").width, 10400, "drawn, 400 em across");
  assert.equal(E.tooBig(box(400.001, 1)), "Too big to draw: 401 \u00d7 1 em, at most 400 a side");
  assert.equal(E.tooBig(box(0.5, 400.001)), "Too big to draw: 0.5 \u00d7 401 em, at most 400 a side");
  assert.equal(E.sized(box(400.001, 1), 1, "#000000"), null, "not drawn at all, however small");
  assert.equal(E.tooBig(box(100, 100)), "");
  assert.equal(E.tooBig(box(100, 100.001)), "Too big to draw: 100 \u00d7 101 em, at most 10000 em\u00b2 in all");
  assert.equal(E.sized(box(100, 100.001), 16, "#000000"), null);
  // Characters of SVG, and tags in it.
  const small = box(1, 1);
  const chars = (n) => small.replace("</g>", " ".repeat(n - small.length) + "</g>");
  assert.equal(chars(E.MAX_SVG).length, E.MAX_SVG);
  assert.equal(E.tooBig(chars(E.MAX_SVG)), "");
  assert.ok(E.sized(chars(E.MAX_SVG), 16, "#000000"));
  assert.equal(E.tooBig(chars(E.MAX_SVG + 1)), "Too much to draw: 1001 KB, at most 1000 KB");
  assert.equal(E.sized(chars(E.MAX_SVG + 1), 16, "#000000"), null);
  const tags = (n) => box(1, 1, "<a/>".repeat(n - 4));
  assert.equal(E.tooBig(tags(E.MAX_TAGS)), "");
  assert.equal(E.tooBig(tags(E.MAX_TAGS + 1)), "Too much to draw: more than 40000 parts");
  assert.equal(E.sized(tags(E.MAX_TAGS + 1), 16, "#000000"), null);
  // At any size, pixels across or down (16384), and in all (8192 × 8192).
  const wide = box(256, 1);
  assert.equal(E.sized(wide, 64, "#000000").width, 16384);
  assert.equal(E.sized(wide, 64.01, "#000000"), null);
  const square = box(64, 64);
  const most = E.sized(square, 128, "#000000");
  assert.equal(most.width * most.height, 8192 * 8192);
  assert.equal(E.sized(square, 128.01, "#000000"), null);
  // In a line, made taller to sit on the text: what it is then.
  const tall = box(1, 300);
  assert.ok(E.sized(tall, 40, "#000000"), "12000 px down: drawn");
  assert.equal(E.sized(tall, 40, "#000000", 10), null, "made taller past 16384 px: not");
  // How far in it can be zoomed: as big as it can be drawn, and no bigger.
  assert.ok(Math.abs(E.maxEm(wide) - 64) < 0.001);
  assert.ok(E.sized(wide, E.maxEm(wide), "#000000"));
  assert.equal(E.sized(wide, E.maxEm(wide) * 1.0001, "#000000"), null);
  assert.ok(Math.abs(E.maxEm(square) - 128) < 0.001);
  assert.ok(E.sized(square, E.maxEm(square), "#000000"));
  assert.equal(E.sized(square, E.maxEm(square) * 1.0001, "#000000"), null);
  const odd = box(1.911, 1.911);
  assert.ok(E.sized(odd, E.maxEm(odd), "#000000"), "drawn at the most, rounding and all");
  assert.equal(E.maxEm(box(400.001, 1)), 0);
  assert.equal(E.maxEm("nope"), 0);
});

check("one too big is kept as what's wrong with it; what's kept stays small", () => {
  E.forget();
  const fine = { svg: sample, error: "" };
  E.remember("D:fine", fine);
  assert.equal(E.cached("D:fine"), fine, "an ordinary one, kept as it is");
  E.remember("D:huge", { svg: box(1000000, 1000000), error: "" });
  assert.deepEqual(plain(E.cached("D:huge")), { svg: "", error: "Too big to draw: 1000000 \u00d7 1000000 em, at most 400 a side" });
  E.remember("D:wrong", { svg: box(1, 1000000), error: "Missing close brace" });
  assert.deepEqual(plain(E.cached("D:wrong")), { svg: "", error: "Missing close brace" }, "MathJax's own error, if it said one");
  assert.equal(E.drawnChars, sample.length, "only what's shown is counted");
  // Up to MAX_DRAWN_SVG characters of SVG in all...
  E.forget();
  const full = box(1, 1).replace("</g>", " ".repeat(E.MAX_SVG - box(1, 1).length) + "</g>");
  const fit = Math.floor(E.MAX_DRAWN_SVG / E.MAX_SVG);
  for (let i = 0; i < fit; i++) E.remember("D:" + i, { svg: full, error: "" });
  assert.equal(E.drawnCount, fit);
  assert.equal(E.drawnChars, fit * E.MAX_SVG);
  E.remember("D:more", { svg: full, error: "" });
  assert.equal(E.drawnCount, 1, "then they're all let go");
  assert.equal(E.drawnChars, E.MAX_SVG);
  assert.equal(E.cached("D:0"), null);
  // ...and MAX_DRAWN of them.
  E.forget();
  for (let i = 0; i < E.MAX_DRAWN; i++) E.remember("I:" + i, { svg: sample, error: "" });
  assert.equal(E.drawnCount, E.MAX_DRAWN);
  E.remember("I:more", { svg: sample, error: "" });
  assert.equal(E.drawnCount, 1);
  // Kept again, the same one: counted once, as it is now.
  E.forget();
  E.remember("D:a", { svg: sample, error: "" });
  E.remember("D:a", { svg: sample + " ", error: "" });
  assert.equal(E.drawnCount, 1);
  assert.equal(E.drawnChars, sample.length + 1);
  E.forget();
  assert.equal(E.drawnChars, 0);
});

check("in a line, one too big to be an image is its placeholder", () => {
  const inner = "Tall " + E.link("\\rule{1em}{1000000em}") + " end";
  const placeholder = E.toImages(inner, () => null, 16, "#111111");
  const handed = [
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"22.00px\" height=\"22000000.00px\" viewBox=\"0 -1000000000 1000 1000000000\"><g/></svg>",
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"9000.00px\" height=\"9000.00px\" viewBox=\"0 -1000 1000 1000\"><g/></svg>",
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"2262443.439ex\" height=\"1ex\" viewBox=\"0 -1000 1000000000 1000\"><g/></svg>",
    "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"20.00px\" height=\"20.00px\" viewBox=\"0 -1000 1000 1000\">" + " ".repeat(E.MAX_SVG) + "</svg>",
  ];
  for (const svg of handed) {
    const shown = E.toImages(inner, () => ({ svg }), 16, "#111111");
    assert.equal(shown, placeholder, "its placeholder, not " + svg.slice(0, 90));
    assert.equal(E.toLinks(shown), inner, "kept as its link");
  }
  assert.match(placeholder, /width="\d{2,3}" height="20"/);
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
  // It and the parts it imports: about 1.6 MB in all, no file over 480 KB
  // (the marketplace's scan reads files up to 512 KiB), every part there.
  const parts = fs.readdirSync(dir).filter((n) => /^tex-svg(-[A-Z0-9]+)?\.mjs$/.test(n));
  assert.ok(parts.includes("tex-svg.mjs"));
  const sizes = parts.map((n) => fs.statSync(path.join(dir, n)).size);
  const total = sizes.reduce((a, b) => a + b, 0);
  assert.ok(total > 1000000 && total < 2500000, "about 1.6 MB in all: " + total);
  assert.ok(sizes.every((n) => n <= 480 * 1024), "each part at most 480 KB: " + sizes.join(", "));
  for (const n of parts) {
    for (const m of fs.readFileSync(path.join(dir, n), "utf8").matchAll(/from\s*"\.\/([^"]+)"/g)) assert.ok(parts.includes(m[1]), n + " imports " + m[1]);
  }
  const bundle = parts.map((n) => fs.readFileSync(path.join(dir, n), "utf8")).join("\n");
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

  // Too big to draw: said, and never asked of Qt at its size (its popover
  // draws at 22 px an em, its block at 18, a line at 19.2, the large view
  // at 26 to 156).
  for (const [tex, said] of [["\\rule{1000000em}{1000000em}", "1000000 \u00d7 1000000"], ["\\rule{1em}{1000000em}", "1 \u00d7 1000000"]]) {
    const huge = mod.render(tex, true);
    assert.ok(huge.length < 600, "a few hundred bytes: " + huge.length);
    assert.equal(E.tooBig(huge), "Too big to draw: " + said + " em, at most 400 a side");
    for (const em of [22, 18, 15, 19.2, 26, 26 * 6, 1]) assert.equal(E.sized(huge, em, "#000000"), null, "no size at " + em + " px an em");
    assert.equal(E.sized(huge, 19.2, "#000000", 4), null);
    assert.equal(E.maxEm(huge), 0);
    E.remember(E.key(tex, true), { svg: huge, error: E.errorOf(huge) });
    assert.deepEqual(plain(E.cached(E.key(tex, true))), { svg: "", error: E.tooBig(huge) });
    const shown = E.toImages(E.link(tex), (t) => E.sized(huge, 19.2, "#000000", 4), 16, "#000000");
    assert.match(shown, /width="\d{2,3}" height="20"/, "in a line: its placeholder");
  }
  E.forget();
  // However MathJax writes a box past any size.
  assert.match(E.tooBig(mod.render("\\rule{" + "9".repeat(25) + "em}{1em}", true)), /^Too big to draw: [\d.]+e\+25 \u00d7 1 em/);
  assert.match(E.tooBig(mod.render("\\rule{" + "9".repeat(400) + "em}{1em}", true)), /^Too big to draw: Infinity \u00d7 1 em/);
  assert.match(E.tooBig(mod.render("x\\kern{1000000em}y", true)), /^Too big to draw: 1000002 \u00d7/);
  // A macro that makes megabytes of SVG from a few hundred characters.
  const much = mod.render("\\def\\b{" + "x".repeat(1000) + "}" + "\\b".repeat(10), true);
  assert.ok(much.length > E.MAX_SVG);
  assert.match(E.tooBig(much), /^Too much to draw: \d+ KB, at most 1000 KB$/);
  // Big real math is drawn: the biggest matrix MAX_TEX characters make, and
  // a long aligned derivation.
  const rows = [];
  for (let r = 0; r < 44; r++) rows.push(Array.from({ length: 44 }, (_, c) => String((r * c) % 10)).join("&"));
  const lines = [];
  for (let i = 0; i < 30; i++) lines.push("&= \\frac{\\partial^2 f}{\\partial x_" + i + "^2} + \\sum_{k=1}^{n} \\binom{n}{k} a_k^{" + i + "} x^{k} - \\int_0^\\infty e^{-t} t^{" + i + "} \\, dt");
  for (const tex of ["\\begin{pmatrix}" + rows.join("\\\\") + "\\end{pmatrix}", "\\begin{aligned} f(x) " + lines.join(" \\\\\n") + "\\end{aligned}"]) {
    assert.ok(tex.length <= E.MAX_TEX, "fits in an equation: " + tex.length);
    const svg = mod.render(tex, true);
    assert.equal(E.tooBig(svg), "", "drawn: " + JSON.stringify(plain(E.measure(svg))));
    for (const em of [22, 18, 26]) assert.ok(E.sized(svg, em, "#000000"), "at " + em + " px an em");
    assert.ok(E.maxEm(svg) / 26 > 3, "zoomed in on, past 300%");
  }
  passed++;
  console.log(`equations: ${passed} checks passed`);
})().catch((e) => { console.error(e); process.exit(1); });
