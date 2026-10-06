// Checks that a click on a button, a popover's choice or the agent panel is
// theirs alone: in Qt a TapHandler as it comes (DragThreshold) takes only a
// passive grab, and the tap goes on to the page under it too (a bookmark's
// card there opened its site when Allow was clicked over it). Every
// TapHandler in a popover or dialog (a file whose root is Pop or Popup), in
// the agent panel and the toast, and in the shared buttons, says how it
// takes its tap (gesturePolicy). tests/qml/tst_clickthrough.qml shows it.
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
const overlays = files.filter((f) => ["Pop", "Popup"].includes(rootType(fs.readFileSync(path.join(app, f), "utf8"))))
  .concat(["AgentPanel.qml", "App.qml", "AgentTiles.qml", "TextButton.qml", "IconButton.qml", "Toggle.qml", "Chip.qml", "MenuRow.qml", "AppName.qml"]);

// Each TapHandler { ... } in a file: its text, to its closing brace.
function handlers(text) {
  const out = [];
  const re = /\bTapHandler\s*\{/g;
  let m;
  while ((m = re.exec(text))) {
    let depth = 0, i = m.index + m[0].length - 1;
    for (; i < text.length; i++) {
      if (text[i] === "{") depth++;
      else if (text[i] === "}" && --depth === 0) break;
    }
    out.push({ at: text.slice(0, m.index).split("\n").length, body: text.slice(m.index, i + 1) });
  }
  return out;
}

check("every tap in a popover, a dialog, the agent panel, the toast and the shared buttons is its own", () => {
  assert.ok(overlays.length > 30, "the popovers found: " + overlays.length);
  const loose = [];
  for (const f of overlays) {
    for (const h of handlers(fs.readFileSync(path.join(app, f), "utf8"))) {
      if (!/gesturePolicy\s*:/.test(h.body)) loose.push(`app/${f}:${h.at}`);
    }
  }
  assert.deepEqual(loose, []);
});

console.log(`clickthrough: ${passed} checks passed`);
