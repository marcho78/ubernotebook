// Checks Overlays.closeAll: as another profile opens, every popup in a
// view's tree is closed (nested in items, a popup's content, one a Loader
// made), and every overlay marked closesForSwitch; those kept, and what's
// in them, are left open.
// Usage (from the plugin directory): node tests/overlays.test.cjs

const assert = require("node:assert/strict");
const { load } = require("./load.cjs");

const Overlays = load("Overlays.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

function popup(name, kids) { return { name, modal: false, visible: true, contentData: kids || [], close() { this.visible = false; } }; }
function item(kids) { return { data: kids || [] }; }

check("closed wherever they are; those kept left open", () => {
  const inner = popup("inner");
  const outer = popup("outer", [item([inner])]);
  const made = popup("made by a loader");
  const loader = { sourceComponent: {}, item: made, data: [] };
  const picker = { closesForSwitch: true, visible: true, data: [], close() { this.visible = false; } };
  const shut = popup("already shut");
  shut.visible = false;
  let shutCalls = 0;
  shut.close = () => { shutCalls++; };
  const keptInside = popup("in Settings");
  const settings = popup("Settings", [item([keptInside])]);
  const plain = { data: [], visible: true, close() { throw new Error("not a popup"); } };
  const root = item([item([item([outer])]), loader, picker, shut, settings, plain, null, 42]);
  const closed = Overlays.closeAll(root, [settings]);
  assert.equal(outer.visible, false, "nested in items");
  assert.equal(inner.visible, false, "in a popup's content");
  assert.equal(made.visible, false, "one a Loader made");
  assert.equal(picker.visible, false, "an overlay that closes like one");
  assert.equal(shutCalls, 0, "one shut: left");
  assert.equal(settings.visible, true, "Settings left open");
  assert.equal(keptInside.visible, true, "and what's in it");
  assert.equal(closed, 4);
});

check("a Loader's item that's its child: walked once", () => {
  let calls = 0;
  const child = { data: [], modal: false, visible: true, close() { calls++; this.visible = false; } };
  const loader = { sourceComponent: {}, item: child, data: [child] };
  child.parent = loader;
  Overlays.closeAll(item([loader]), []);
  assert.equal(calls, 1);
});

console.log(`overlays: ${passed} checks passed`);
