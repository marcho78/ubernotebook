// Checks papers, pens, inks and the type sizes they make.
// Usage (from the plugin directory): node tests/papers.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Papers = load("Papers.js");
const Defaults = load("Defaults.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("every choice in the settings exists", () => {
  const choices = plain(Defaults.SCHEMA).choices;
  assert.deepEqual(choices.paper, plain(Papers.PATTERNS.map((p) => p.id)));
  assert.deepEqual(choices.paperColor, plain(Papers.PAPERS.map((p) => p.id)));
  assert.deepEqual(choices.spacing, plain(Papers.SPACINGS.map((s) => s.id)));
  assert.deepEqual(choices.pen, plain(Papers.PENS.map((p) => p.id)));
});

check("papers resolve to everything the page draws", () => {
  const ivory = plain(Papers.resolve({ pattern: "ruled", color: "ivory", spacing: "regular" }, {}));
  assert.equal(ivory.shader, 1);
  assert.equal(ivory.pitch, 30);
  assert.equal(ivory.dark, false);
  assert.equal(ivory.hasMargin, true);
  for (const key of ["paper", "line", "margin", "ink", "muted", "edge", "back", "link", "selection"]) {
    assert.match(ivory[key], /^#[0-9a-f]{6}$/, key);
  }
  const night = plain(Papers.resolve({ pattern: "dots", color: "night" }, {}));
  assert.equal(night.dark, true);
  assert.equal(night.hasMargin, false, "only ruled paper has a margin");
  const odd = plain(Papers.resolve({ pattern: "zigzag", color: "plaid", spacing: "huge" }, {}));
  assert.deepEqual([odd.pattern, odd.color, odd.spacing], ["ruled", "ivory", "regular"], "unknown choices fall back");
});

check("theme paper follows the Omarchy theme", () => {
  const dark = plain(Papers.resolve({ color: "theme" }, { background: "#1a1b26", foreground: "#c0caf5", accent: "#7aa2f7" }));
  assert.equal(dark.dark, true);
  assert.equal(dark.ink, "#c0caf5");
  assert.equal(dark.margin, "#7aa2f7");
  assert.notEqual(dark.paper, "#1a1b26", "lifted off the desk");
  const light = plain(Papers.resolve({ color: "theme" }, { background: "#fdf6e3", foreground: "#586e75", accent: "#268bd2" }));
  assert.equal(light.dark, false);
});

check("inks and highlighters have dark twins that map both ways", () => {
  const toDark = plain(Papers.darkMap());
  const toLight = plain(Papers.lightMap());
  for (const c of Papers.INKS.concat(Papers.HIGHLIGHTS)) {
    assert.equal(toDark[c.light], c.dark);
    assert.equal(toLight[c.dark], c.light);
    assert.ok(Papers.luminance(c.dark) !== Papers.luminance(c.light));
  }
  // Every ink reads (WCAG AA) on the papers it's meant for.
  const light = ["white", "ivory", "yellow", "gray"].map((id) => Papers.PAPERS.find((p) => p.id === id).paper);
  const dark = ["night"].map((id) => Papers.PAPERS.find((p) => p.id === id).paper);
  for (const ink of Papers.INKS) {
    for (const paper of light) assert.ok(Papers.contrast(ink.light, paper) >= 4.5, `${ink.id} on ${paper}: ${Papers.contrast(ink.light, paper).toFixed(2)}`);
    for (const paper of dark) assert.ok(Papers.contrast(ink.dark, paper) >= 4.5, `${ink.id} on ${paper}: ${Papers.contrast(ink.dark, paper).toFixed(2)}`);
  }
  // And the paper's own ink reads on it.
  for (const paper of Papers.PAPERS.filter((p) => p.ink)) {
    assert.ok(Papers.contrast(paper.ink, paper.paper) >= 7, paper.id);
  }
  assert.equal(Papers.readable("#000000", "#111111", "#eeeeee"), "#eeeeee");
  assert.equal(Papers.inkColor("blue", true), "#8ab4f8");
  assert.equal(Papers.highlightColor("nope", false), "");
});

check("type sizes fit their lines", () => {
  for (const pen of Papers.PENS) {
    for (const sp of Papers.SPACINGS) {
      for (const type of ["p", "h1", "h2", "h3", "quote", "code", "callout"]) {
        const st = plain(Papers.typeStyle(type, pen.id, sp.id));
        assert.ok(st.size <= sp.pitch * st.rows * 0.9, `${type} in ${pen.id}/${sp.id}: ${st.size}px on a ${sp.pitch * st.rows}px line`);
        assert.ok(st.size >= 12, "readable");
      }
    }
  }
  assert.equal(plain(Papers.typeStyle("h1", "sans", "regular")).rows, 2, "a title takes two lines");
  assert.ok(plain(Papers.typeStyle("p", "hand", "regular")).size > plain(Papers.typeStyle("p", "sans", "regular")).size, "handwriting is written bigger");
});

check("color helpers", () => {
  assert.equal(Papers.mix("#000000", "#ffffff", 0.5), "#808080");
  assert.equal(Papers.hex("#ABC"), "#aabbcc");
  assert.equal(Papers.hex("#80aabbcc"), "#aabbcc", "Qt's #aarrggbb");
  assert.equal(Papers.hex("red"), "");
});

console.log(`papers: ${passed} checks passed`);
