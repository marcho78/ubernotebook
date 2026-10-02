// Checks sketches in Pages: what's kept, the eraser, paths and SVG.
// Usage (from the plugin directory): node tests/sketch.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const S = load("Sketch.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("what's kept", () => {
  assert.deepEqual(plain(S.make()), { height: 420, background: "dots", strokes: [] });
  assert.equal(S.clean(null), null);
  assert.equal(S.clean([1]), null);
  const s = plain(S.clean({ height: 99999, background: "stripes", strokes: [
    { tool: "pen", color: "blue", width: 4, points: [10, 10, 20.04, 30] },
    { tool: "marker", color: "#FF8800", width: 24, points: [0, 0, 5, 5] },
    { tool: "pen", color: "javascript:", width: 4, points: [1, 1] },
    { tool: "pen", color: "red", points: [1, "x"] },
    { tool: "pen", color: "red", points: [] },
    "nope",
    { tool: "laser", color: "", width: 999, points: [-500, 5000, 3, 4] }
  ] }));
  assert.equal(s.height, S.MAX_HEIGHT, "as tall as it can be, no taller");
  assert.equal(s.background, "dots", "a background it knows");
  assert.equal(s.strokes.length, 4, "only strokes with points");
  assert.deepEqual(s.strokes[0], { tool: "pen", color: "blue", width: 4, points: [10, 10, 20, 30] });
  assert.equal(s.strokes[1].color, "#ff8800", "a color of your own");
  assert.equal(s.strokes[2].color, "", "a color it can't read: the page's ink");
  assert.deepEqual(s.strokes[3], { tool: "pen", color: "", width: 80, points: [-20, 3020, 3, 4] }, "kept on the sketch, nib and all");
  assert.equal(plain(S.clean({ height: 10 })).height, S.MIN_HEIGHT);
  const many = plain(S.clean({ strokes: Array.from({ length: 4000 }, () => ({ color: "", points: [1, 1, 2, 2] })) }));
  assert.equal(many.strokes.length, S.MAX_STROKES);
});

check("drawing and erasing", () => {
  let s = plain(S.make("grid"));
  const st = plain(S.stroke("marker", "yellow", 4, [0, 0, 100, 0]));
  assert.deepEqual(st, { tool: "marker", color: "yellow", width: 24, points: [0, 0, 100, 0] }, "a highlighter six times the nib");
  s = plain(S.withStroke(s, st));
  s = plain(S.withStroke(s, plain(S.stroke("pen", "", 4, [0, 200, 100, 200]))));
  assert.equal(s.strokes.length, 2);
  let r = plain(S.erase(s, 50, 30, 10));
  assert.equal(r.removed, 0, "out of reach");
  r = plain(S.erase(s, 50, 18, 10));
  assert.equal(r.removed, 1, "the highlighter's width counts");
  assert.equal(r.sketch.strokes[0].tool, "pen");
  assert.equal(s.strokes.length, 2, "the sketch itself unchanged");
  r = plain(S.eraseAlong(s, 50, -100, 50, 300, 10));
  assert.equal(r.removed, 2, "a swipe across both takes both, however far apart it was reported");
  assert.equal(r.sketch.strokes.length, 0);
});

check("paths and SVG", () => {
  assert.equal(S.pathOf([1, 2]), "M 1 2 L 1.01 2", "a dot");
  assert.equal(S.pathOf([0, 0, 10, 10, 20, 0]), "M 0 0 Q 10 10 15 5 L 20 0", "curves through the points");
  assert.equal(S.pathOf([0, 0, 10, 10, 20, 0, 30, 10]), "M 0 0 Q 10 10 15 5 Q 20 0 25 5 L 30 10");
  assert.ok(S.backgroundPath("grid", 100, 25).startsWith("M 25 0 L 25 100"));
  assert.equal(S.backgroundPath("plain", 100), "");
  assert.equal(S.colorHex("", false), "#1f2430");
  assert.equal(S.colorHex("", true, "#ffffff"), "#ffffff", "the page's own ink");
  assert.equal(S.colorHex("#123456", true), "#123456");
  const svg = S.toSvg({ height: 300, strokes: [{ tool: "pen", color: "red", width: 4, points: [1, 2, 3, 4] }, { tool: "marker", color: "yellow", width: 24, points: [5, 5] }, { tool: "pen", color: "\"><script>", width: 2, points: [7, 7] }] }, "My <sketch>");
  assert.ok(svg.startsWith('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1000 300"'));
  assert.ok(svg.includes("<title>My &lt;sketch></title>"));
  assert.ok(/stroke="#[0-9a-f]{6}" stroke-width="4" stroke-linecap="round"/.test(svg), svg);
  assert.ok(svg.includes('stroke-opacity="0.5"'), "a highlighter, see-through");
  assert.equal(S.markerHex("yellow", false), "#ffdf3d", "a highlighter's yellow is bright");
  assert.equal(S.strokeHex({ tool: "pen", color: "yellow" }, false), S.colorHex("yellow", false), "a pen's is the text's");
  assert.equal(S.markerHex("#123456", true), "#123456");
  assert.ok(!svg.includes("<script"), "nothing but strokes");
});

console.log(`sketch: ${passed} checks passed`);
