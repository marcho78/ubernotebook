// Checks that a click on a button, a popover's choice or an overlay is
// theirs alone: in Qt a TapHandler as it comes (DragThreshold) takes only a
// passive grab, and the tap goes on to the page under it too (a bookmark's
// card there opened its site when Allow was clicked over it). Every
// TapHandler in a popover or dialog (a file whose root is Pop or Popup, or a
// Pop declared inside another), in the overlays (the agent panel, the start
// screen, the picture picker, the format bar, the toast) and in the shared
// buttons and swatches takes its tap (an exclusive gesturePolicy).
// tests/qml/tst_clickthrough.qml shows it.
// Usage (from the plugin directory): node tests/clickthrough.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { root } = require("./load.cjs");

let passed = 0;
function check(name, fn) { fn(); passed++; }

const app = path.join(root, "app");
const files = fs.readdirSync(app).filter((f) => f.endsWith(".qml"));
const rootType = (text) => (/^([A-Z][A-Za-z_]*)\s*\{/m.exec(text) || [])[1] || "";
// Over the page, whole: popovers and dialogs (a file whose root is Pop or
// Popup), the agent panel, the start screen, the picture picker, the format
// bar, the toast; and the shared buttons and swatches used in them.
const whole = new Set(["AgentPanel.qml", "App.qml", "FirstRun.qml", "PicturePicker.qml", "FormatBar.qml", "AgentTiles.qml",
  "TextButton.qml", "IconButton.qml", "Toggle.qml", "Chip.qml", "MenuRow.qml", "AppName.qml", "Swatch.qml"]);

// Each `<re> { ... }` in a file: [start, end], to its closing brace.
function blocks(text, re) {
  const out = [];
  let m;
  while ((m = re.exec(text))) {
    let depth = 0, i = text.indexOf("{", m.index);
    for (; i < text.length; i++) {
      if (text[i] === "{") depth++;
      else if (text[i] === "}" && --depth === 0) break;
    }
    out.push([m.index, i]);
  }
  return out;
}

check("every tap in a popover (wherever it's declared), an overlay and the shared buttons is its own", () => {
  const loose = [];
  let seen = 0;
  for (const f of files) {
    const text = fs.readFileSync(path.join(app, f), "utf8");
    const over = whole.has(f) || ["Pop", "Popup"].includes(rootType(text)) ? [[0, text.length]]
      : blocks(text, /(?:^|\s)(?:Pop|Popup|[A-Z][A-Za-z]*Pop|Menu)\s*\{/g);
    for (const [a, b] of blocks(text, /\bTapHandler\s*\{/g)) {
      if (!over.some(([s, e]) => a >= s && b <= e)) continue;
      seen++;
      // (ReleaseWithinBounds or WithinBounds: an exclusive grab; the default,
      // DragThreshold, said or not, is only a passive one.)
      if (!/gesturePolicy\s*:\s*TapHandler\.(?:ReleaseWithinBounds|WithinBounds)\b/.test(text.slice(a, b + 1))) {
        loose.push(`app/${f}:${text.slice(0, a).split("\n").length}`);
      }
    }
  }
  assert.ok(seen >= 45, "the taps found: " + seen);
  assert.deepEqual(loose, []);
});

console.log(`clickthrough: ${passed} checks passed`);
