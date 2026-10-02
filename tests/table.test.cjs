// Checks tables in Pages: what's kept, changing them, spreadsheet paste,
// Markdown.
// Usage (from the plugin directory): node tests/table.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const T = load("Table.js");
const Markdown = load("Markdown.js");
const Import = load("Import.js");
const Workspace = load("Workspace.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("what's kept", () => {
  const t = plain(T.clean({ rows: [["Name", "Qty", "x"], ["Apples"], "nope", ["<b>Pears</b>", "10"]], widths: [2, 1] }));
  assert.deepEqual(t.rows.map((r) => r.length), [3, 3, 3], "every row as long as the longest");
  assert.equal(t.rows.length, 3, "only rows");
  assert.equal(t.header, true, "a header row unless it's off");
  assert.equal(t.rows[2][0], '<span style="font-weight:700;">Pears</span>', "cells keep their formatting, cleaned");
  assert.equal(Math.round(t.widths.reduce((a, b) => a + b) * 1000), 1000, "widths add up to 1");
  assert.ok(t.widths[0] > t.widths[1]);
  assert.equal(T.clean({ rows: [] }), null);
  assert.equal(T.clean(null), null);
  assert.equal(plain(T.clean({ rows: [["a"]], header: false })).header, false);
  const big = plain(T.clean({ rows: Array.from({ length: 600 }, () => Array.from({ length: 40 }, () => "x")) }));
  assert.deepEqual([big.rows.length, big.rows[0].length], [T.MAX_ROWS, T.MAX_COLS]);
  assert.ok(!/<script|<img/.test(plain(T.clean({ rows: [['<img src="x"><script>a</script>b']] })).rows[0][0]), "nothing but text in a cell");
});

check("changing a table", () => {
  let t = plain(T.make(3, 2));
  assert.deepEqual([t.rows.length, t.rows[0].length], [2, 3]);
  t = plain(T.setCell(t, 1, 2, "hi"));
  t = plain(T.insertRow(t, 1));
  assert.deepEqual(t.rows.map((r) => r[2]), ["", "", "hi"], "a row in, above");
  t = plain(T.insertCol(t, 0));
  assert.deepEqual([t.rows[0].length, t.rows[2][3]], [4, "hi"], "a column in, before");
  assert.equal(Math.round(t.widths.reduce((a, b) => a + b) * 1000), 1000);
  t = plain(T.deleteCol(t, 0));
  t = plain(T.deleteRow(t, 1));
  assert.deepEqual(t.rows, [["", "", ""], ["", "", "hi"]]);
  assert.equal(plain(T.deleteRow(plain(T.make(2, 1)), 0)).rows.length, 1, "not the last row");
  assert.equal(plain(T.deleteCol(plain(T.make(1, 2)), 0)).rows[0].length, 1, "nor the last column");
  const r = plain(T.resize(plain(T.make(2, 1)), 0, 0.2));
  assert.deepEqual(r.widths, [0.7, 0.3]);
  assert.ok(plain(T.resize(plain(T.make(2, 1)), 0, 5)).widths[1] >= T.MIN_SHARE, "a column never goes");
});

check("moving rows and columns, pasting cells in", () => {
  let t = plain(T.clean({ rows: [["a", "b"], ["1", "2"], ["3", "4"]], widths: [0.7, 0.3] }));
  assert.deepEqual(plain(T.moveRow(t, 2, -1)).rows, [["a", "b"], ["3", "4"], ["1", "2"]]);
  assert.deepEqual(plain(T.moveRow(t, 0, -1)).rows, t.rows, "not past the top");
  const m = plain(T.moveCol(t, 0, 1));
  assert.deepEqual([m.rows[0], m.widths], [["b", "a"], [0.3, 0.7]], "its width goes with it");
  t = plain(T.pasteInto(t, 2, 1, plain(T.cellsOf("x\ty\nz\tw\n"))));
  assert.deepEqual(t.rows, [["a", "b", ""], ["1", "2", ""], ["3", "x", "y"], ["", "z", "w"]], "the table grows to take them");
  assert.equal(T.cellsOf("no tabs\nhere"), null);
});

check("colors", () => {
  let t = plain(T.clean({ rows: [["a", "b"], ["c", "d"]] }));
  assert.equal(t.colors, undefined, "none: left out");
  t = plain(T.setColors(t, plain(T.cellsIn(t, "row", 1)), "background", "yellow"));
  assert.deepEqual(t.colors, [["", ""], ["|yellow", "|yellow"]], "a row's background");
  t = plain(T.setColors(t, plain(T.cellsIn(t, "cell", 1, 0)), "color", "#FF8800"));
  assert.deepEqual(plain(T.colorOf(t, 1, 0)), { color: "#ff8800", background: "yellow" }, "a cell's text, a color of your own");
  assert.deepEqual(plain(T.colorsOf(t, plain(T.cellsIn(t, "row", 1)))), { color: "", background: "" }, "not all the same");
  assert.deepEqual(plain(T.colorsOf(t, plain(T.cellsIn(t, "col", 0, 1)))), { color: "", background: "" });
  // They go with their cells.
  let m = plain(T.moveRow(t, 1, -1));
  assert.deepEqual(m.colors[0], ["#ff8800|yellow", "|yellow"]);
  m = plain(T.insertCol(t, 0));
  assert.deepEqual(m.colors[1], ["", "#ff8800|yellow", "|yellow"]);
  m = plain(T.deleteRow(T.insertRow(t, 0), 0));
  assert.deepEqual(m.colors, t.colors);
  m = plain(T.moveCol(t, 0, 1));
  assert.deepEqual(m.colors[1], ["|yellow", "#ff8800|yellow"]);
  // Taken off again: gone.
  t = plain(T.setColors(t, plain(T.cellsIn(t, "row", 1)), "background", ""));
  t = plain(T.setColors(t, plain(T.cellsIn(t, "row", 1)), "color", ""));
  assert.equal(t.colors, undefined);
  const odd = plain(T.clean({ rows: [["a"]], colors: [["purple|nope"], ["x"]] }));
  assert.deepEqual(odd.colors, [["purple|"]], "only colors, one per cell");
  assert.equal(plain(T.clean({ rows: [["a"]], colors: [["<b>|javascript:"]] })).colors, undefined);
});

check("pasted from a spreadsheet", () => {
  assert.deepEqual(plain(T.fromTSV("Name\tQty\nApples\t3\nPears <b>\t10\n")), [["Name", "Qty"], ["Apples", "3"], ["Pears &lt;b&gt;", "10"]]);
  assert.equal(T.fromTSV("just text\nmore"), null);
  assert.equal(T.fromTSV("a\tb"), null, "one line of two isn't a table");
  assert.ok(T.fromTSV("a\tb\tc"), "of three, it is");
});

check("as Markdown", () => {
  const t = plain(T.clean({ rows: [["Name", "Note"], ['<span style="font-weight:700;">Apples</span>', "a | b"]] }));
  assert.equal(T.toMarkdown(t, Markdown.inline), "| Name | Note |\n| --- | --- |\n| **Apples** | a \\| b |");
  const plainRows = plain(T.clean({ rows: [["1", "2"]], header: false }));
  assert.equal(T.toMarkdown(plainRows), "|   |   |\n| --- | --- |\n| 1 | 2 |", "no header row: an empty one");
  assert.equal(T.text(t), "Name | Note\nApples | a | b");
});

check("out to Markdown and back", () => {
  const table = plain(T.clean({ rows: [["Item", "Note"], ['<span style="font-style:italic;">Tea</span>', 'see <a href="https://x.org">x</a> | y'], ["", "two<br />lines"]], widths: [0.3, 0.7] }));
  const id = Workspace.uuid4();
  const page = { title: "Shop", content: [id], blocks: { [id]: { type: "table", table, indent: 0 } } };
  const md = Markdown.fromDocPage(page);
  assert.ok(md.includes("| *Tea* | see [x](https://x.org) \\| y |"), md);
  const back = plain(Import.fromMarkdown(md, null, { titleFromHeading: true }));
  assert.equal(back.title, "Shop");
  assert.equal(back.blocks[0].type, "table");
  assert.deepEqual(back.blocks[0].table.rows, table.rows, "the same cells, formatting and all");
  const w = plain(Workspace.blockList(page, Markdown.inline));
  assert.equal(w[0].type, "table");
  assert.ok(w[0].text.startsWith("| Item | Note |"), "agents read it as Markdown");
  assert.ok(Workspace.pageText(page).includes("Tea | see x | y"), "and search finds its words");
});

console.log(`table: ${passed} checks passed`);
