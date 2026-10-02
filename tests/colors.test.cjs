// Checks colors of your own: hex colors, hue/saturation/value, contrast,
// readable text, and the colors picked last.
// Usage (from the plugin directory): node tests/colors.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const C = load("Colors.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("hex colors", () => {
  assert.equal(C.normalize("#F80"), "#ff8800");
  assert.equal(C.normalize("ff8800"), "#ff8800");
  assert.equal(C.normalize("#ccff8800"), "#ff8800", "Qt's #aarrggbb");
  for (const bad of ["", "red", "#ff88", "#gg0000", null, "rgb(1,2,3)"]) assert.equal(C.normalize(bad), "", String(bad));
  assert.equal(C.isHex("#abc"), true);
  assert.equal(C.isHex("#ccff8800"), false, "a color of yours has no alpha");
  assert.deepEqual(plain(C.rgb("#ff8000")), { r: 255, g: 128, b: 0 });
});

check("hue, saturation and value, there and back", () => {
  assert.equal(C.fromHsv(0, 1, 1), "#ff0000");
  assert.equal(C.fromHsv(120, 1, 1), "#00ff00");
  assert.equal(C.fromHsv(240, 1, 0.5), "#000080");
  assert.equal(C.fromHsv(0, 0, 1), "#ffffff");
  assert.equal(C.fromHsv(360, 1, 1), "#ff0000");
  for (const hex of ["#1e66f5", "#82fb9c", "#c05a36", "#000000", "#ffffff", "#7f7f7f", "#ff00ff"]) {
    const h = C.toHsv(hex);
    assert.equal(C.fromHsv(h.h, h.s, h.v), hex, hex);
  }
});

check("contrast and readable text", () => {
  assert.equal(Math.round(C.contrast("#000000", "#ffffff")), 21);
  assert.equal(C.contrast("#777777", "#777777"), 1);
  assert.ok(Math.abs(C.contrast("#767676", "#ffffff") - 4.54) < 0.02, "WCAG's own example");
  assert.equal(C.readableOn("#ffffff", "#2b2a28"), "#2b2a28", "the page's text, where it reads");
  assert.equal(C.readableOn("#1e1e2e", "#2b2a28"), "#ffffff", "else light on dark");
  assert.equal(C.readableOn("#ffe680", "#ddf7ff"), "#14161c", "and dark on light");
  assert.deepEqual(["good", "fair", "poor"], [C.rating(7), C.rating(3.2), C.rating(1.5)]);
  const line = C.visibleOn("#fffbe6", "#ffffff");
  assert.ok(C.contrast(line, "#ffffff") >= 1.8, "a pale branch on a light page is darkened until it shows");
  assert.ok(C.contrast(C.visibleOn("#0b0c18", "#0b0c16"), "#0b0c16") >= 1.8, "and a dark one lightened on a dark page");
  assert.equal(C.visibleOn("#1e66f5", "#ffffff"), "#1e66f5", "one that shows stays");
});

check("the colors picked last", () => {
  assert.deepEqual(plain(C.recentList("#AA0000, #bb0, nope,#aa0000")), ["#aa0000", "#bbbb00"]);
  assert.equal(C.withRecent("#aa0000,#bbbb00", "#BBBB00"), "#bbbb00,#aa0000", "newest first, once");
  let list = "";
  for (let i = 0; i < 12; i++) list = C.withRecent(list, C.fromHsv(i * 30, 1, 1));
  assert.equal(C.recentList(list).length, C.MAX_RECENT);
  assert.ok(list.length <= 64, "it fits in a setting");
});

console.log(`colors: ${passed} checks passed`);
