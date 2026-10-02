// Checks mind maps in Pages: outlines read and written, Mermaid's mind maps,
// folds, lists, and the layout.
// Usage (from the plugin directory): node tests/mindmap.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const M = load("Mindmap.js");
const Import = load("Import.js");
const Markdown = load("Markdown.js");
const W = load("Workspace.js");
const Blocks = load("Blocks.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("an outline, read and kept", () => {
  assert.equal(M.clean("Launch plan\n  Marketing\n    Blog post\n  Engineering\n\tRelease notes"),
    "Launch plan\n  Marketing\n    Blog post\n  Engineering\n    Release notes", "tabs and spaces both indent");
  assert.equal(M.clean("- Topic\n  - A\n  * B\n    1. B1"), "Topic\n  A\n  B\n    B1", "list markers go");
  assert.equal(M.clean("One\nTwo\nThree"), "One\n  Two\n  Three", "lines as far left as the topic are its ideas");
  assert.equal(M.clean("Topic\n      deep\n  shallow"), "Topic\n  deep\n  shallow");
  assert.equal(M.clean("\n\n   \n"), "", "nothing in it");
  assert.equal(M.clean("a  b\u2028c"), "a b c");
  assert.equal(M.count("A\n  B\n    C\n  D"), 4);
  const many = "T\n" + Array.from({ length: 500 }, (_, i) => "  idea " + i).join("\n");
  assert.equal(M.count(many), M.MAX_NODES, "no more than " + M.MAX_NODES + " ideas");
  const deep = Array.from({ length: 20 }, (_, i) => " ".repeat(i * 2) + "level " + i).join("\n");
  assert.equal(Math.max(...plain(M.toList(deep)).map((x) => x.depth)), M.MAX_DEPTH, "nor deeper than " + M.MAX_DEPTH);
});

check("Mermaid's mind maps", () => {
  assert.equal(M.clean("mindmap\n  root((Launch))\n    Marketing[Market it]\n      ::icon(fa fa-book)\n      Blog\n    eng(Engineering):::urgent\n    Ship (v2)\n    b))Bang((\n    c{{Hex}}\n    d)Cloud(\n    \"Quoted\"\n    %% a comment"),
    "Launch\n  Market it\n    Blog\n  Engineering\n  Ship (v2)\n  Bang\n  Hex\n  Cloud\n  Quoted");
  assert.equal(M.clean("Plain(text)\n  a[b]"), "Plain(text)\n  a[b]", "shapes only in Mermaid");
});

check("folds", () => {
  const root = M.applyFolds(M.parse("T\n  A\n    A1\n  B\n    B1"), "1,3,9")
  assert.equal(M.foldsOf(root), "1,3");
  assert.equal(M.cleanFolds("3,1,1,0,9,x", 5), "1,3", "the topic doesn't fold, and each once");
  assert.equal(M.descendants(M.parse("T\n  A\n    A1\n    A2")), 3);
});

check("from and to lists", () => {
  assert.equal(M.fromList("Trip", [{ text: "Pack", depth: 1 }, { text: "Passport", depth: 2 }, { text: "Book", depth: 5 }, { text: "", depth: 1 }]),
    "Trip\n  Pack\n    Passport\n      Book", "an idea is at most one deeper than the one before");
  assert.equal(M.fromList("", []), "Mind map");
  assert.deepEqual(plain(M.toList("A\n  B\n    C")).map((x) => [x.text, x.depth]), [["A", 0], ["B", 1], ["C", 2]]);
  const t = M.copy(M.parse("A\n  \n  B"));
  t.children.push({ text: "", children: [], folded: false });
  assert.equal(M.serialize(M.prune(t)), "A\n  B", "empty ideas go");
});

check("colors: an idea's text and background", () => {
  assert.equal(M.clean("Plan {blue background}\n  Marketing {red}\n    Blog {green, yellow background}"),
    "Plan {blue background}\n  Marketing {red}\n    Blog {green, yellow background}");
  assert.equal(M.clean("A\n  B {Pink_Background}\n  C {red bg, Gray}"), "A\n  B {pink background}\n  C {gray, red background}", "written one way");
  assert.equal(M.clean("A\n  Draft {not a color}\n  Set {}\n  {red}"), "A\n  Draft {not a color}\n  Set {}\n  {red}", "braces that aren't colors are words");
  const t = plain(M.parse("A {red}\n  B {pink background}"));
  assert.deepEqual([t.text, t.color, t.children[0].background], ["A", "red", "pink"]);
  assert.deepEqual(plain(M.COLORS), plain(Blocks.COLORS), "the colors Pages has");
  const c = M.copy(M.parse("A {red}"));
  c.background = "blue";
  assert.equal(M.serialize(c), "A {red, blue background}");
  assert.equal(M.fromList({ text: "T", background: "green" }, [{ text: "x", depth: 1, color: "red" }]), "T {green background}\n  x {red}");
  assert.equal(M.clean("mindmap\n  root((Launch)) {orange background}\n    a[Idea] {red}"), "Launch {orange background}\n  Idea {red}", "in Mermaid too");
  assert.equal(M.clean("A {#FF8800}\n  B {#1e66f5 background}\n  C {#f80, #222 bg}\n  D {#ff88}\n  E {#ggg}"),
    "A {#ff8800}\n  B {#1e66f5 background}\n  C {#ff8800, #222222 background}\n  D {#ff88}\n  E {#ggg}", "colors of your own, as hex");
  assert.deepEqual(["red", "#ff8800", "", ""].map(String), [M.cleanColor("Red"), M.cleanColor("#F80"), M.cleanColor("crimson"), M.cleanColor("#ff88")]);
  const page = W.newPage({ title: "P", blocks: [{ type: "mindmap", outline: "Plan {blue background}\n  Marketing {red}", indent: 0 }] });
  assert.ok(!/\{/.test(W.pageText(page)), "search reads the ideas, not their colors");
});

check("the layout", () => {
  const m = { advance: (s) => s.length * 8, lineHeight: () => 20, maxWidth: (d) => (d === 0 ? 200 : 120), pad: () => ({ x: 10, y: 5 }),
    minWidth: 30, gapX: () => 40, gapY: () => 10, margin: 8, available: 900 };
  const L = plain(M.layout(M.parse("Launch plan\n  Marketing\n    Blog post\n    Newsletter\n  Engineering\n    Release notes\n  Design\n  Support"), m));
  assert.equal(L.nodes.length, 8);
  assert.equal(L.edges.length, 7, "a line to every idea");
  assert.ok(L.nodes.some((n) => n.side > 0) && L.nodes.some((n) => n.side < 0), "on both sides of the topic");
  const boxes = L.nodes;
  for (let i = 0; i < boxes.length; i++) for (let j = i + 1; j < boxes.length; j++) {
    const a = boxes[i], b = boxes[j];
    const apart = a.x + a.w <= b.x || b.x + b.w <= a.x || a.y + a.h <= b.y || b.y + b.h <= a.y;
    assert.ok(apart, `ideas ${a.lines} and ${b.lines} don't overlap`);
  }
  assert.ok(boxes.every((n) => n.x >= 0 && n.y >= 0 && n.x + n.w <= L.width && n.y + n.h <= L.height), "all inside it");
  assert.equal(L.scale, 1);
  const long = plain(M.layout(M.parse("T\n  " + "word ".repeat(30)), m));
  assert.ok(long.nodes[1].lines.length > 1 && long.nodes[1].w <= 120 + 20, "long ideas wrap");
  // Too wide for both sides: all on the right, if that needs less shrinking.
  const wide = "T\n" + ["A", "B"].map((x) => `  ${x} long idea here\n    ${x}1 long idea here\n      ${x}2 long idea here`).join("\n");
  const narrow = plain(M.layout(M.parse(wide), Object.assign({}, m, { available: 500 })));
  assert.ok(narrow.scale < 1);
  const folded = plain(M.layout(M.applyFolds(M.parse("T\n  A\n    A1\n    A2"), "1"), m));
  assert.equal(folded.nodes.length, 2, "folded branches aren't drawn");
});

check("as Markdown, in and out", () => {
  const r = plain(Import.fromMarkdown("```mindmap\nLaunch\n  Marketing\n```\n\n```mermaid\nmindmap\n  root((Q4))\n    Hire\n```\n\n```mermaid\ngraph TD\nA-->B\n```", null, {}));
  assert.deepEqual(r.blocks.map((b) => b.type), ["mindmap", "mindmap", "code"], "a Mermaid chart that isn't a mind map stays code");
  assert.equal(r.blocks[1].outline, "Q4\n  Hire");
  const h = plain(Import.fromHtml('<pre><code class="language-mermaid">mindmap\n  Topic\n    Idea</code></pre>', null, {}));
  assert.equal(h.blocks[0].type, "mindmap");
  const page = W.newPage({ title: "P", blocks: r.blocks });
  assert.deepEqual(plain(W.flatten(page)).map((b) => b.type), ["mindmap", "mindmap", "code"], "kept on a page");
  assert.ok(Markdown.fromDocPage(page, () => null).includes("```mindmap\nLaunch\n  Marketing\n```"), "and written back the same way");
  assert.ok(W.pageText(page).includes("Marketing"), "its ideas are found by search");
  const list = plain(W.blockList(page, Markdown.inline));
  assert.equal(list[0].text, "Launch\n  Marketing", "blocks gives its outline");
});

check("only in Pages, and never empty", () => {
  assert.equal(Blocks.clean({ type: "mindmap", outline: "T\n  A" }), null, "not in a notebook");
  assert.equal(Blocks.clean({ type: "mindmap", outline: "  " }, { nest: true }), null);
  const b = plain(Blocks.clean({ type: "mindmap", outline: "T\n  A\n    B", folds: "1,7" }, { nest: true }));
  assert.deepEqual([b.outline, b.folds], ["T\n  A\n    B", "1"]);
});

console.log(`mindmap: ${passed} checks passed`);
