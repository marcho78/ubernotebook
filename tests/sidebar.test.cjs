// Checks Pages' sidebar: what can be left out of it, the lists it keeps
// (left out, folded), and its rows changed a row at a time.
// Usage (from the plugin directory): node tests/sidebar.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const S = load("Sidebar.js");
const D = load("Defaults.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

// The steps applied to `from`, as the sidebar applies them to its rows.
function apply(from, steps) {
  const rows = from.slice();
  steps.forEach((s) => {
    if (s.op === "remove") rows.splice(s.at, 1);
    else if (s.op === "insert") rows.splice(s.at, 0, s.key);
    else rows.splice(s.to, 0, rows.splice(s.from, 1)[0]);
  });
  return rows;
}

check("what can be left out, and where it is", () => {
  const items = plain(S.ITEMS);
  assert.deepEqual(items.map((i) => i.id), ["search", "calendar", "library", "people", "today", "favorites", "projects", "tags", "import", "templates", "archive", "trash"]);
  assert.ok(!items.some((i) => i.id === "pages" || i.id === "settings"), "Pages and Settings are always there");
  assert.deepEqual(plain(S.itemsAt("top")).map((i) => i.id), ["search", "calendar", "library", "people"]);
  assert.deepEqual(plain(S.itemsAt("foot")).map((i) => i.id), ["import", "templates", "archive", "trash"]);
  assert.equal(S.label("favorites"), "Favorites");
  assert.equal(S.label("nope"), "");
  for (const i of items) assert.match(i.id, /^[a-z][a-z0-9-]{0,23}$/, i.id + " fits the setting's list");
  assert.deepEqual(plain(D.DEFAULTS.sidebarHidden), [], "everything there to begin with");
  assert.deepEqual(plain(D.DEFAULTS.sidebarFolded), [], "nothing folded");
});

check("left out or folded: in the list or not, each once", () => {
  assert.deepEqual(plain(S.setIn([], "tags", true)), ["tags"]);
  assert.deepEqual(plain(S.setIn(["tags"], "tags", true)), ["tags"], "once");
  assert.deepEqual(plain(S.setIn(["tags", "trash"], "tags", false)), ["trash"]);
  assert.deepEqual(plain(S.setIn(undefined, "trash", true)), ["trash"]);
  assert.deepEqual(plain(S.toggled(["pages"], "pages")), []);
  assert.deepEqual(plain(S.toggled(["pages"], "tags")), ["pages", "tags"]);
});

check("rows changed a row at a time", () => {
  const cases = [
    [[], ["a", "b", "c"]],
    [["a", "b", "c"], []],
    [["a", "b", "c"], ["a", "b", "c"]],
    [["a", "b", "c"], ["a", "x", "y", "b", "c"]],
    [["a", "x", "y", "b", "c"], ["a", "b", "c"]],
    [["a", "b", "c", "d"], ["d", "a", "b", "c"]],
    [["a", "b", "c", "d"], ["b", "c", "d", "a"]],
    [["a", "b", "c", "d"], ["d", "c", "b", "a"]],
    [["a", "b", "c"], ["c", "q", "a"]],
  ];
  for (const [from, to] of cases) {
    assert.deepEqual(apply(from, plain(S.steps(from, to))), to, from.join() + " → " + to.join());
  }
  assert.deepEqual(plain(S.steps(["a", "b", "c"], ["a", "b", "c"])), [], "nothing changed: nothing done");
  assert.deepEqual(plain(S.steps(["a", "b", "c"], ["a", "x", "b", "c"])), [{ op: "insert", at: 1, key: "x" }], "a page opened: its row, and no other");
  assert.deepEqual(plain(S.steps(["a", "x", "b"], ["a", "b"])), [{ op: "remove", at: 1 }]);
  // Any order, any change.
  let seed = 7;
  const rand = (n) => { seed = (seed * 1103515245 + 12345) % 2147483648; return seed % n; };
  for (let k = 0; k < 300; k++) {
    const pool = "abcdefghij".split("");
    const pick = () => pool.filter(() => rand(3) > 0).sort(() => rand(3) - 1);
    const from = pick(), to = pick();
    assert.deepEqual(apply(from, plain(S.steps(from, to))), to, from.join() + " → " + to.join());
  }
});

console.log(`sidebar: ${passed} checks passed`);
