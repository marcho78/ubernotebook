// Checks diagrams: Mermaid's flowcharts read (shapes, icons, links and their
// text, chains, &, subgraphs, directions), what it can't draw said, and the
// layout: ranks in order, nothing overlapping, groups round what's in them.
// Their colors: classDef, class, :::, style and linkStyle, as Mermaid ranks
// them, CSS's colors, and drawn readable on a light or a dark page.
// Usage (from the plugin directory): node tests/diagram.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const D = load("Diagram.js");
const C = load("Colors.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const parse = (t) => plain(D.parse(t));
const measure = (t) => String(t).length * 7;

check("nodes: their shapes, labels and icons", () => {
  const g = parse([
    "graph TD",
    "  a[Box] --> b(Rounded) --> c([Stadium]) --> d[[Sub]] --> e[(Database)]",
    "  f((Circle)) --> g{Decide?} --> h{{Hex}} --> i[/In/] --> j[\\Out\\]",
    "  k[/Trap\\] --> l>Flag] --> m[\"Quoted [with] brackets\"]",
    "  n[fa:fa-server Web server] --> o@{ shape: cyl, label: \"Store\", icon: \"database\" }",
    "  p[Two<br>lines] --> q"
  ].join("\n"));
  const shape = {};
  g.nodes.forEach((n) => (shape[n.id] = n.shape));
  assert.deepEqual(shape, { a: "box", b: "rounded", c: "stadium", d: "subroutine", e: "cylinder", f: "circle", g: "diamond", h: "hexagon",
    i: "lean-right", j: "lean-left", k: "trapezoid", l: "flag", m: "box", n: "box", o: "cylinder", p: "box", q: "box" });
  const byId = Object.fromEntries(g.nodes.map((n) => [n.id, n]));
  assert.equal(byId.m.label, "Quoted [with] brackets");
  assert.equal(byId.n.label, "Web server");
  assert.equal(byId.n.icon, "server", "fa:fa-server: the icon, out of the words");
  assert.equal(byId.o.label, "Store");
  assert.equal(byId.o.icon, "database");
  assert.equal(byId.p.label, "Two\nlines");
  assert.equal(byId.q.label, "q", "no label: its id");
  assert.deepEqual(g.errors, []);
});

check("links: kinds, text, chains, & and lengths", () => {
  const g = parse([
    "flowchart LR",
    "  a --> b",
    "  b --- c",
    "  c -.-> d",
    "  d ==> e",
    "  e -- yes --> f",
    "  f -->|no| g",
    "  g -. maybe .-> h",
    "  h <--> i",
    "  i --o j",
    "  j --x k",
    "  k ---> l",
    "  x & y --> z & w",
    "  A-->B"
  ].join("\n"));
  const e = (from, to) => g.edges.find((x) => x.from === from && x.to === to);
  assert.equal(g.direction, "LR");
  assert.deepEqual([e("a", "b").style, e("a", "b").arrowEnd], ["solid", "arrow"]);
  assert.deepEqual([e("b", "c").style, e("b", "c").arrowEnd, e("b", "c").length], ["solid", "", 1]);
  assert.equal(e("c", "d").style, "dotted");
  assert.equal(e("d", "e").style, "thick");
  assert.equal(e("e", "f").label, "yes");
  assert.equal(e("f", "g").label, "no");
  assert.deepEqual([e("g", "h").label, e("g", "h").style], ["maybe", "dotted"]);
  assert.deepEqual([e("h", "i").arrowStart, e("h", "i").arrowEnd], ["arrow", "arrow"]);
  assert.equal(e("i", "j").arrowEnd, "circle");
  assert.equal(e("j", "k").arrowEnd, "cross");
  assert.equal(e("k", "l").length, 2, "---> is a rank longer");
  assert.equal(e("a", "b").length, 1);
  assert.ok(e("x", "z") && e("x", "w") && e("y", "z") && e("y", "w"), "& on both sides: every pair");
  assert.ok(e("A", "B"), "no spaces round the arrow");
  assert.equal(g.edges.filter((x) => x.from === "b" && x.to === "c").length, 1);
  // A chain, with text partway.
  const c = parse("graph TD\n  a --> b -->|go| c --- d");
  assert.deepEqual(c.edges.map((x) => x.from + x.to + x.label), ["ab", "bcgo", "cd"]);
  // "A --- B --> C" isn't a link with "- B" written on it.
  const t = parse("graph TD\n  A --- B --> C");
  assert.deepEqual(t.edges.map((x) => x.from + x.to + x.label), ["AB", "BC"]);
});

check("subgraphs: what's in them, their names, inside each other", () => {
  const g = parse([
    "flowchart TB",
    "  subgraph cloud [The cloud]",
    "    direction LR",
    "    api --> db[(DB)]",
    "    subgraph inner",
    "      cache",
    "    end",
    "  end",
    "  subgraph \"Office LAN\"",
    "    pc",
    "  end",
    "  pc --> api",
    "  api --> cache"
  ].join("\n"));
  const groups = Object.fromEntries(g.groups.map((x) => [x.id, x]));
  assert.equal(groups.cloud.label, "The cloud");
  assert.equal(groups.cloud.direction, "LR");
  assert.equal(groups.inner.parent, "cloud");
  assert.ok(g.groups.some((x) => x.label === "Office LAN"));
  const byId = Object.fromEntries(g.nodes.map((n) => [n.id, n]));
  assert.equal(byId.api.group, "cloud");
  assert.equal(byId.cache.group, "inner");
  assert.equal(byId.pc.group, g.groups.find((x) => x.label === "Office LAN").id);
  assert.equal(g.direction, "TD", "TB is TD");
});

check("what it can't draw, or doesn't understand, is said", () => {
  const seq = parse("sequenceDiagram\n  Alice->>Bob: Hi");
  assert.equal(seq.unsupported, true);
  assert.match(D.problem(seq), /flowcharts.*sequenceDiagram/);
  const bad = parse("graph TD\n  a --> b\n  a -> b");
  assert.equal(bad.errors.length, 1);
  assert.match(D.problem(bad), /^Line 3/);
  assert.equal(D.problem(parse("graph TD")), "Nothing to draw yet.");
  assert.equal(D.problem(parse("graph TD\n  a --> b")), "");
  // Comments, styles and classes: not drawn, not mistakes.
  const quiet = parse("graph TD\n  %% a note\n  a --> b:::warn\n  classDef warn fill:#f00\n  style a fill:#0f0\n  linkStyle 0 stroke:#00f\n  click a href \"https://x.org\"");
  assert.deepEqual(quiet.errors, []);
  assert.deepEqual(quiet.nodes.map((n) => n.id), ["a", "b"]);
  // No header: a flowchart, down the page.
  assert.equal(parse("a --> b").direction, "TD");
  assert.ok(D.isLang("Mermaid") && D.isLang("mermaid") && !D.isLang("Math"));
});

function overlaps(a, b) { return a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h; }

check("laid out down the page: ranks in order, nothing on top of anything", () => {
  const g = parse(D.STARTERS.decision);
  const l = plain(D.layout(g, measure, {}));
  const n = l.nodes;
  assert.ok(n.q1.y + n.q1.h <= n.q2.y, "an arrow goes down a rank");
  assert.ok(n.q2.y + n.q2.h <= n.q3.y);
  assert.ok(Math.abs(n.a1.y - n.q2.y) < 40, "both answers on the rank after the question");
  const ids = Object.keys(n);
  for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) assert.ok(!overlaps(n[ids[i]], n[ids[j]]), ids[i] + " and " + ids[j] + " overlap");
  for (const id of ids) assert.ok(n[id].x >= 0 && n[id].y >= 0 && n[id].x + n[id].w <= l.w && n[id].y + n[id].h <= l.h, id + " inside the drawing");
  assert.equal(l.edges.length, g.edges.length);
  for (const e of l.edges) {
    assert.ok(e.points.length >= 2);
    if (e.label) assert.ok(e.labelAt, "where its words go");
  }
  // An edge starts on its box's side, not its middle.
  const e1 = l.edges.find((e) => e.from === "q1" && e.to === "q2");
  assert.ok(e1.points[0].y > n.q1.y + n.q1.h / 2, "from the bottom of the question");
});

check("across (LR), and turned round (BT, RL)", () => {
  const lr = plain(D.layout(parse("graph LR\n  a --> b --> c"), measure, {}));
  assert.ok(lr.nodes.a.x + lr.nodes.a.w <= lr.nodes.b.x && lr.nodes.b.x + lr.nodes.b.w <= lr.nodes.c.x, "left to right");
  assert.ok(Math.abs(lr.nodes.a.y - lr.nodes.c.y) < 1, "on one line");
  const bt = plain(D.layout(parse("graph BT\n  a --> b"), measure, {}));
  assert.ok(bt.nodes.a.y > bt.nodes.b.y, "bottom to top");
  const rl = plain(D.layout(parse("graph RL\n  a --> b"), measure, {}));
  assert.ok(rl.nodes.a.x > rl.nodes.b.x, "right to left");
});

check("groups round what's in them; loops and long lines", () => {
  const g = parse(D.STARTERS.system);
  const l = plain(D.layout(g, measure, {}));
  const app = l.groups.find((x) => x.id === "App");
  for (const id of ["api1", "api2"]) {
    const b = l.nodes[id];
    assert.ok(b.x >= app.x && b.y >= app.y && b.x + b.w <= app.x + app.w && b.y + b.h <= app.y + app.h, id + " inside Application");
  }
  for (const id of ["user", "db", "worker"]) assert.ok(!overlaps(l.nodes[id], app), id + " not inside it");
  // A loop: still laid out, its way back drawn.
  const loop = plain(D.layout(parse("graph TD\n  a --> b --> c --> a"), measure, {}));
  assert.equal(loop.edges.length, 3);
  assert.ok(loop.nodes.a.y < loop.nodes.b.y && loop.nodes.b.y < loop.nodes.c.y);
  // A long line goes round, through the ranks between.
  const long = plain(D.layout(parse("graph TD\n  a --> b --> c --> d\n  a --> d"), measure, {}));
  assert.ok(long.edges.find((e) => e.from === "a" && e.to === "d").points.length >= 4, "through points between");
  // To itself.
  const self = plain(D.layout(parse("graph TD\n  a --> a"), measure, {}));
  assert.equal(self.edges[0].points.length, 4);
  // Every starter lays out with nothing overlapping.
  for (const k of Object.keys(D.STARTERS)) {
    const s = plain(D.layout(parse(D.STARTERS[k]), measure, {}));
    const ids = Object.keys(s.nodes);
    assert.ok(ids.length >= 4, k);
    for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) assert.ok(!overlaps(s.nodes[ids[i]], s.nodes[ids[j]]), k + ": " + ids[i] + " and " + ids[j] + " overlap");
    assert.deepEqual(parse(D.STARTERS[k]).errors, [], k + " reads without a mistake");
  }
});

check("words on lines have room of their own: on no box, on no other words", () => {
  // As an agent wrote it: three answers, long ones, from one question.
  const g = parse([
    "flowchart TD",
    "  q1{What do you want from it?}",
    "  q1 -->|A picture you can redraw| q2{Happy with a little algebra?}",
    "  q2 -->|No| r[Rearrangement: four triangles in a square]",
    "  q2 -->|Yes| g[Garfield's trapezoid]",
    "  q1 -->|The fewest steps| s[Similar triangles from the altitude]",
    "  q1 -->|Rigor from first principles| e[Euclid's windmill, Elements I.47]"
  ].join("\n"));
  const l = plain(D.layout(g, measure, { lineHeight: 18 }));
  const boxes = l.edges.filter((e) => e.label).map((e) => {
    const w = Math.max(...e.labelLines.map((x) => measure(x))) + 10;
    const h = e.labelLines.length * 16 + 4;
    return { x: e.labelAt.x - w / 2, y: e.labelAt.y - h / 2, w, h, label: e.label };
  });
  assert.equal(boxes.length, 5);
  for (let i = 0; i < boxes.length; i++) {
    for (let j = i + 1; j < boxes.length; j++) assert.ok(!overlaps(boxes[i], boxes[j]), boxes[i].label + " and " + boxes[j].label + " overlap");
    for (const id of Object.keys(l.nodes)) assert.ok(!overlaps(boxes[i], l.nodes[id]), boxes[i].label + " is on " + id);
  }
  const ids = Object.keys(l.nodes);
  for (let i = 0; i < ids.length; i++) for (let j = i + 1; j < ids.length; j++) assert.ok(!overlaps(l.nodes[ids[i]], l.nodes[ids[j]]));
});

check("big ones stay within bounds", () => {
  const lines = ["graph TD"];
  for (let i = 0; i < 60; i++) lines.push("  n" + i + " --> n" + ((i * 7 + 3) % 60));
  const t0 = Date.now();
  const l = plain(D.layout(parse(lines.join("\n")), measure, {}));
  assert.ok(Date.now() - t0 < 1500, "quick enough: " + (Date.now() - t0) + " ms");
  assert.equal(Object.keys(l.nodes).length, 60);
  const many = parse(Array.from({ length: 400 }, (_, i) => "a" + i + " --> b" + i).join("\n"));
  assert.equal(many.nodes.length, D.MAX_NODES);
});

check("colors: classDef, class, :::, style and linkStyle, as Mermaid ranks them", () => {
  const g = parse([
    "flowchart LR",
    "  a[A]:::warm --> b[B] --> c[C]",
    "  subgraph G [Group]",
    "    c --> d[D]",
    "  end",
    "  classDef default fill:#eeeeee,color:#111111",
    "  classDef warm fill:#ffedd5,stroke:#ea580c,color:#7c2d12",
    "  classDef cool,calm fill:#dbeafe",
    "  class b,c cool",
    "  style c fill:red,stroke-width:3px,stroke-dasharray: 5, 5,font-weight:bold,font-style:italic",
    "  style G fill:#f0fdf4,stroke:#86efac,color:#14532d",
    "  linkStyle default stroke:gray",
    "  linkStyle 1,2 stroke:#ff0000,stroke-width:2px,color:blue"
  ].join("\n"));
  const p = Object.fromEntries(g.nodes.map((n) => [n.id, n.paint]));
  assert.deepEqual(p.a, { fill: "#ffedd5", stroke: "#ea580c", color: "#7c2d12" }, "default, then its class (:::)");
  assert.deepEqual(p.b, { fill: "#dbeafe", color: "#111111" }, "a class named with another, over default");
  assert.deepEqual(p.c, { fill: "#ff0000", color: "#111111", width: 3, dash: [5, 5], bold: true, italic: true }, "its own style over its class");
  assert.deepEqual(p.d, { fill: "#eeeeee", color: "#111111" }, "default alone");
  assert.deepEqual(g.groups[0].paint, { fill: "#f0fdf4", stroke: "#86efac", color: "#14532d" }, "a group's style (not default's)");
  assert.deepEqual(g.edges.map((e) => e.paint), [{ stroke: "#808080" }, { stroke: "#ff0000", width: 2, color: "#0000ff" }, { stroke: "#ff0000", width: 2, color: "#0000ff" }], "lines by number, over the default");
  assert.deepEqual(g.errors, []);
  // Without any: nothing of their own.
  const none = parse("flowchart TD\n  a --> b");
  assert.ok(none.nodes.every((n) => n.paint === undefined) && none.edges.every((e) => e.paint === undefined));
});

check("colors: CSS's ways of writing one", () => {
  const c = D.cssColor;
  assert.equal(c("#F9F"), "#ff99ff");
  assert.equal(c("#ff99ff"), "#ff99ff");
  assert.equal(c("#f9f8"), "#88ff99ff", "#rgba: Qt's #aarrggbb");
  assert.equal(c("#11223380"), "#80112233");
  assert.equal(c("rgb(255, 0, 0)"), "#ff0000");
  assert.equal(c("rgba(0,0,255,0.5)"), "#800000ff");
  assert.equal(c("rgb(100% 50% 0% / 25%)"), "#40ff8000");
  assert.equal(c("hsl(120, 100%, 25%)"), "#008000");
  assert.equal(c("hsla(0, 100%, 50%, 1)"), "#ff0000");
  assert.equal(c("LightCoral"), "#f08080");
  assert.equal(c("rebeccapurple"), "#663399");
  assert.equal(c("none"), "#00000000");
  for (const bad of ["", "#12", "#ggg", "rgb(1,2)", "var(--x)", "notacolor", "url(#p)", "hasOwnProperty"]) assert.equal(c(bad), "", bad);
  assert.equal(Object.keys(D.NAMED).length, 148, "every CSS name");
});

check("style lines: one it can't read is said; what it doesn't draw is left out", () => {
  const g = parse(["flowchart TD", "  a --> b", "  classDef", "  linkStyle x stroke:red", "  style a", "  style b fill:#abc,rx:10,font-size:20px,opacity:0.5"].join("\n"));
  assert.deepEqual(g.errors.map((e) => e.line), [4, 5]);
  assert.match(D.problem(g), /^Line 4 isn't understood: linkStyle x/);
  assert.deepEqual(g.nodes[1].paint, { fill: "#aabbcc" });
  // linkStyle with how the line curves first; dashes as a list, or none.
  const h = parse(["flowchart TD", "  a --> b -.-> c", "  linkStyle 0 interpolate basis stroke:#00f", "  linkStyle 1 stroke-dasharray:none,stroke-width:0"].join("\n"));
  assert.deepEqual(h.edges.map((e) => e.paint), [{ stroke: "#0000ff" }, { dash: [], width: 0 }]);
  assert.deepEqual(h.errors, []);
});

check("its own colors, readable on the page, light or dark", () => {
  const light = { ink: "#2b2a28", paper: "#eeeae2" };
  const dark = { ink: "#c0caf5", paper: "#1a1b26" };
  // Colors that read: as they are, on either page.
  const box = { fill: "#dbeafe", stroke: "#2563eb", color: "#1e3a8a" };
  for (const page of [light, dark]) assert.deepEqual(plain(D.look(box, page.ink, page.paper, false)), { fill: "#dbeafe", stroke: "#2563eb", text: "#1e3a8a", width: -1, dash: null, bold: false, italic: false });
  // A fill and no words' color: the words in what reads on it.
  assert.equal(D.look({ fill: "#1e3a8a" }, light.ink, light.paper, false).text, "#ffffff");
  assert.equal(D.look({ fill: "#fef9c3" }, dark.ink, dark.paper, false).text, "#14161c");
  // Words with nothing behind them but the page: their color, made to read
  // there (still that color).
  for (const [color, page] of [["#1e3a8a", dark], ["#16a34a", light], ["#fef9c3", light]]) {
    const t = D.look({ color: color }, page.ink, page.paper, false).text;
    assert.ok(C.contrast(t, page.paper) >= 3, color + " -> " + t);
    const hue = (x) => C.toHsv(x).h;
    assert.ok(Math.abs(hue(t) - hue(color)) < 12, "still its color: " + color + " -> " + t);
  }
  assert.equal(D.look({ color: "#16a34a" }, dark.ink, dark.paper, true).text, "#16a34a", "one that reads stays");
  // Lines: no fill; one that wouldn't show, made to; their words on the page.
  const line = D.look({ stroke: "#222222", fill: "#ff0000", color: "#1e3a8a" }, dark.ink, dark.paper, true);
  assert.equal(line.fill, "");
  assert.ok(C.contrast(line.stroke, dark.paper) >= 1.8);
  assert.ok(C.contrast(line.text, dark.paper) >= 3);
  // An outline round a fill: as it is (the fill shows the shape).
  assert.equal(D.look({ fill: "#ffedd5", stroke: "#ffffff" }, light.ink, light.paper, false).stroke, "#ffffff");
  // Nothing of its own: the page's.
  assert.deepEqual(plain(D.look(undefined, light.ink, light.paper, false)), { fill: "", stroke: "", text: "", width: -1, dash: null, bold: false, italic: false });
});

check("bold words get the room they take", () => {
  const g = parse(["flowchart LR", "  a[Same words here] --> b[Same words here]", "  style b font-weight:bold"].join("\n"));
  const l = plain(D.layout(g, (t, bold) => String(t).length * (bold ? 8 : 7), {}));
  assert.ok(l.nodes.b.w > l.nodes.a.w, l.nodes.b.w + " vs " + l.nodes.a.w);
  assert.deepEqual(l.nodes.b.paint, { bold: true });
  assert.equal(l.nodes.a.paint, undefined);
});

check("a cylinder and a subroutine: filled whole, their lines inside drawn over", () => {
  for (const shape of ["cylinder", "subroutine"]) {
    assert.equal((D.shapePath(shape, 120, 60).match(/M /g) || []).length, 1, shape + ": one outline, to fill");
    assert.ok(D.shapeLines(shape, 120, 60).length > 0, shape + ": its lines inside");
  }
  assert.equal(D.shapeLines("box", 120, 60), "");
});

check("a line back up the page ends where it points (its arrowhead there)", () => {
  const l = plain(D.layout(parse("flowchart TD\n  a[Top] --> b[Middle] --> c[Bottom]\n  c -.-> a"), measure, {}));
  const back = l.edges.find((e) => e.from === "c" && e.to === "a");
  const centre = (id) => ({ x: l.nodes[id].x + l.nodes[id].w / 2, y: l.nodes[id].y + l.nodes[id].h / 2 });
  const dist = (p, q) => Math.hypot(p.x - q.x, p.y - q.y);
  const first = back.points[0];
  const last = back.points[back.points.length - 1];
  assert.ok(dist(first, centre("c")) < dist(first, centre("a")), "starts at c");
  assert.ok(dist(last, centre("a")) < dist(last, centre("c")), "ends at a, where its arrowhead goes");
  // Down the page, as before.
  const down = l.edges.find((e) => e.from === "a" && e.to === "b");
  assert.ok(down.points[0].y < down.points[down.points.length - 1].y);
});

check("words inside their diamond, and their circle", () => {
  const g = parse("flowchart TD\n  q{1. Interviewed 5+ in one narrow segment about their life, not your idea?} --> r((A circle with a few words in it))\n  q --> s{Short?}");
  const lineH = 18;
  const l = plain(D.layout(g, measure, { lineHeight: lineH }));
  for (const id of ["q", "s"]) {
    const n = l.nodes[id];
    const tw = Math.max(...n.lines.map(measure));
    const th = n.lines.length * lineH;
    assert.ok(n.lines.length >= 1);
    assert.ok(tw / n.w + th / n.h <= 1, id + ": its words' corners inside the diamond (" + (tw / n.w + th / n.h).toFixed(3) + ")");
  }
  const c = l.nodes.r;
  const cw = Math.max(...c.lines.map(measure));
  const ch = c.lines.length * lineH;
  assert.ok(Math.hypot(cw / 2, ch / 2) <= c.w / 2, "inside the circle");
  assert.equal(c.w, c.h);
});

// Read and laid out (when there's anything to lay out), and how long that took.
function timed(text) {
  const t0 = process.hrtime.bigint();
  const g = D.parse(text);
  const l = g.nodes.length ? D.layout(g, measure, {}) : null;
  const ms = Number(process.hrtime.bigint() - t0) / 1e6;
  return { g: plain(g), l: l && plain(l), ms };
}
function within(b, g) { return b.x >= g.x && b.y >= g.y && b.x + b.w <= g.x + g.w && b.y + b.h <= g.y + g.h; }

check("a very long line, and a group inside itself: laid out at once, never thrown", () => {
  const long = timed("graph TD\nA " + "-".repeat(18000) + "> B");
  assert.ok(long.ms < 100, "quick: " + long.ms.toFixed(1) + " ms");
  assert.equal(long.g.edges[0].length, D.MAX_LENGTH);
  assert.equal(long.l.edges[0].points.length, D.MAX_LENGTH + 1, "through a point on each rank between");
  const inside = timed("graph TD\nsubgraph a\nsubgraph a\nx\nend\nend");
  assert.ok(inside.ms < 100, "quick: " + inside.ms.toFixed(1) + " ms");
  assert.deepEqual(inside.g.groups.map((g) => [g.id, g.parent]), [["a", ""]], "the one group");
  assert.equal(inside.g.nodes[0].group, "a");
  assert.deepEqual(inside.g.errors, []);
  assert.deepEqual(inside.l.groups.map((g) => [g.id, g.depth]), [["a", 0]]);
  assert.ok(within(inside.l.nodes.x, inside.l.groups[0]));
  // Nothing in it at all: an empty drawing.
  assert.deepEqual(plain(D.layout(parse("graph TD"), measure, {})), { nodes: {}, edges: [], groups: [], w: 0, h: 0 });
});

check("a line's length: a rank longer for each dash, up to MAX_LENGTH ranks", () => {
  const length = (t) => parse("graph TD\n" + t).edges[0].length;
  assert.equal(length("A " + "-".repeat(D.MAX_LENGTH + 1) + "> B"), D.MAX_LENGTH, "as long as it can be");
  assert.equal(length("A " + "-".repeat(D.MAX_LENGTH + 2) + "> B"), D.MAX_LENGTH, "a dash more: no longer");
  assert.equal(length("A -- t " + "-".repeat(D.MAX_LENGTH) + "> B"), D.MAX_LENGTH);
  assert.equal(length("A -- t " + "-".repeat(D.MAX_LENGTH + 1) + "> B"), D.MAX_LENGTH);
  assert.equal(length("A " + "=".repeat(D.MAX_LENGTH + 2) + "> B"), D.MAX_LENGTH);
  assert.equal(length("A " + "~".repeat(D.MAX_LENGTH + 2) + " B"), D.MAX_LENGTH);
  assert.equal(length("A " + "~".repeat(D.MAX_LENGTH + 3) + " B"), D.MAX_LENGTH);
  // However long it's given as, laid out no longer.
  const box = (id) => ({ id: id, label: id, shape: "box", icon: "", group: "" });
  const l = plain(D.layout({ direction: "TD", nodes: [box("a"), box("b")], edges: [{ from: "a", to: "b", label: "", style: "solid", length: 1e9 }], groups: [] }, measure, {}));
  assert.equal(l.edges[0].points.length, D.MAX_LENGTH + 1);
});

check("groups: one begun again, or inside itself, is the one group, round all that's in it", () => {
  const again = parse("graph TD\nsubgraph a [First]\nx\nend\nsubgraph b\nsubgraph a\ny\nend\nend");
  assert.deepEqual(again.groups.map((g) => [g.id, g.label, g.parent]), [["a", "First", ""], ["b", "b", ""]]);
  assert.deepEqual(again.nodes.map((n) => n.group), ["a", "a"]);
  const l = plain(D.layout(again, measure, {}));
  const a = l.groups.find((g) => g.id === "a");
  for (const id of ["x", "y"]) assert.ok(within(l.nodes[id], a), id + " inside a");
  assert.ok(!l.groups.some((g) => g.id === "b"), "b, with nothing in it, not drawn");
  // a inside b inside a, as written: b in a, and no further.
  const loop = parse("graph TD\nsubgraph a\nsubgraph b\nsubgraph a\nsubgraph b\nx --> y\nend\nend\nend\nend");
  assert.deepEqual(loop.groups.map((g) => [g.id, g.parent]), [["a", ""], ["b", "a"]]);
  assert.deepEqual(loop.nodes.map((n) => n.group), ["b", "b"]);
  assert.deepEqual(plain(D.layout(loop, measure, {})).groups.map((g) => [g.id, g.depth]), [["a", 0], ["b", 1]]);
  // A group with a quoted name gets an id no other group has.
  const named = parse("graph TD\nsubgraph group0\nx\nend\nsubgraph \"Title\"\ny\nend");
  assert.equal(new Set(named.groups.map((g) => g.id)).size, 2);
  // Given groups in each other some other way: laid out all the same.
  const odd = { direction: "TD", nodes: [{ id: "x", label: "x", shape: "box", icon: "", group: "a" }], edges: [],
    groups: [{ id: "a", label: "A", parent: "b" }, { id: "b", label: "B", parent: "a" }, { id: "a", label: "Again", parent: "" }] };
  const lo = plain(D.layout(odd, measure, {}));
  assert.deepEqual(lo.groups.map((g) => g.id).sort(), ["a", "b"]);
  assert.ok(lo.groups.every((g) => Number.isFinite(g.x) && g.w > 0));
});

check("groups: at most MAX_GROUPS, MAX_DEPTH deep; one past that is said, what's in it kept", () => {
  const nest = (n) => "graph TD\n" + Array.from({ length: n }, (_, i) => "subgraph g" + i).join("\n") + "\nx\n" + "end\n".repeat(n);
  const deep = parse(nest(D.MAX_DEPTH));
  assert.equal(deep.groups.length, D.MAX_DEPTH);
  assert.deepEqual(deep.errors, []);
  assert.equal(deep.nodes[0].group, "g" + (D.MAX_DEPTH - 1));
  assert.equal(Math.max(...plain(D.layout(deep, measure, {})).groups.map((g) => g.depth)), D.MAX_DEPTH - 1);
  const deeper = parse(nest(D.MAX_DEPTH + 1));
  assert.equal(deeper.groups.length, D.MAX_DEPTH);
  assert.deepEqual(deeper.errors.map((e) => e.line), [D.MAX_DEPTH + 2], "the one too deep, said");
  assert.match(D.problem(deeper), new RegExp("isn't understood: subgraph g" + D.MAX_DEPTH + "$"));
  assert.equal(deeper.nodes[0].group, "g" + (D.MAX_DEPTH - 1), "what's in it: in the group it's in");
  const many = (n) => "graph TD\n" + Array.from({ length: n }, (_, i) => "subgraph s" + i + "\nn" + i + "\nend").join("\n");
  const full = parse(many(D.MAX_GROUPS));
  assert.equal(full.groups.length, D.MAX_GROUPS);
  assert.deepEqual(full.errors, []);
  const over = parse(many(D.MAX_GROUPS + 1));
  assert.equal(over.groups.length, D.MAX_GROUPS);
  assert.deepEqual(over.errors.map((e) => e.text), ["subgraph s" + D.MAX_GROUPS]);
  assert.equal(over.nodes[D.MAX_GROUPS].group, "", "what's in it: in no group");
  assert.equal(plain(D.layout(over, measure, {})).groups.length, D.MAX_GROUPS);
});

check("ranks: at most MAX_RANKS down the page; past that, the long lines a rank shorter till they fit", () => {
  // A chain of lines MAX_LENGTH ranks long, MAX_RANKS - 1 ranks in all.
  const lengths = [];
  for (let total = 0; total < D.MAX_RANKS - 1; total += lengths[lengths.length - 1]) lengths.push(Math.min(D.MAX_LENGTH, D.MAX_RANKS - 1 - total));
  const chain = (ls) => "graph TD\n" + ls.map((len, i) => "n" + i + " " + "-".repeat(len + 1) + "> n" + (i + 1)).join("\n");
  const fits = plain(D.layout(parse(chain(lengths)), measure, {}));
  assert.equal(fits.edges[0].points.length, D.MAX_LENGTH + 1, "as long as it's written");
  // One rank more.
  const over = plain(D.layout(parse(chain(lengths.concat([1]))), measure, {}));
  assert.equal(over.edges[0].points.length, D.MAX_LENGTH, "a rank shorter");
  for (let i = 0; i < lengths.length; i++) assert.ok(over.nodes["n" + i].y < over.nodes["n" + (i + 1)].y, "still in order");
});

check("points for long lines: at most MAX_BENDS all told; past that, the longest go straight", () => {
  // A chain n0 .. n100, and lines from n0 to n100 (99 points each) and to
  // one nearer for the rest: MAX_BENDS points.
  const lines = Array.from({ length: 100 }, (_, i) => "n" + i + " --> n" + (i + 1));
  const longest = Math.floor(D.MAX_BENDS / 99);
  for (let k = 0; k < longest; k++) lines.push("n0 --> n100");
  const rest = D.MAX_BENDS - longest * 99;
  if (rest) lines.push("n0 --> n" + (rest + 1));
  const points = (l, to) => l.edges.filter((e) => e.from === "n0" && e.to === to).map((e) => e.points.length);
  const all = plain(D.layout(parse("graph TD\n" + lines.join("\n")), measure, {}));
  assert.deepEqual(points(all, "n100"), Array(longest).fill(101), "every one through its points");
  // One more line needing a point: it gets it, and one of the longest goes straight.
  const over = plain(D.layout(parse("graph TD\n" + lines.join("\n") + "\nn0 --> n2"), measure, {}));
  assert.deepEqual(points(over, "n2"), [3]);
  assert.deepEqual(points(over, "n100"), Array(longest - 1).fill(101).concat([2]));
  for (let i = 0; i < 100; i++) assert.ok(over.nodes["n" + i].y < over.nodes["n" + (i + 1)].y, "still in order");
});

check("classes given: at most MAX_CLASSES all told; past that, left out", () => {
  const start = "graph TD\na[A] --> b\nclassDef warm fill:#ffedd5\nclassDef cool fill:#dbeafe\nclass b " + Array(D.MAX_CLASSES - 1).fill("x").join(",");
  assert.deepEqual(parse(start + "\nclass a warm").nodes[0].paint, { fill: "#ffedd5" }, "the last there can be");
  const over = parse(start + "\nclass a warm\nclass a cool");
  assert.deepEqual(over.nodes[0].paint, { fill: "#ffedd5" }, "one more: left out");
  assert.deepEqual(over.errors, []);
});

check("a line's words: at most MAX_LINE_WORDS characters, cut with an ellipsis", () => {
  const exact = "x".repeat(D.MAX_LINE_WORDS);
  assert.equal(parse("graph TD\na -->|" + exact + "| b").edges[0].label, exact);
  const cut = parse("graph TD\na -->|" + exact + "y| b").edges[0].label;
  assert.equal(cut, "x".repeat(D.MAX_LINE_WORDS - 1) + "\u2026");
  assert.equal(parse("graph TD\na -- " + exact + "y --> b").edges[0].label, cut, "written either way");
  // One long label on 400 lines (A & ... -->|words| B & ...): at once.
  const many = timed("graph TD\n" + Array.from({ length: 20 }, (_, i) => "a" + i).join(" & ") + " -->|" + "word ".repeat(3700) + "| " + Array.from({ length: 20 }, (_, i) => "b" + i).join(" & "));
  assert.equal(many.g.edges.length, D.MAX_EDGES);
  assert.ok(many.g.edges.every((e) => e.label.length <= D.MAX_LINE_WORDS));
  assert.ok(many.ms < 100, "quick: " + many.ms.toFixed(1) + " ms");
});

check("ids are names like any other: constructor, __proto__, toString", () => {
  const g = D.parse("graph TD\n__proto__[Proto] --> constructor[Maker]\nhasOwnProperty --> toString\nclassDef warm fill:#ffedd5\nclass constructor warm\nstyle __proto__ fill:#dbeafe");
  const p = plain(g);
  assert.deepEqual(p.nodes.map((n) => [n.id, n.label]), [["__proto__", "Proto"], ["constructor", "Maker"], ["hasOwnProperty", "hasOwnProperty"], ["toString", "toString"]]);
  assert.deepEqual(p.nodes.map((n) => n.paint), [{ fill: "#dbeafe" }, { fill: "#ffedd5" }, undefined, undefined]);
  assert.deepEqual(p.errors, []);
  // Nothing of theirs on every object.
  const object = Object.getPrototypeOf(g);
  for (const k of ["id", "label", "shape", "icon"]) assert.equal(object[k], undefined, k);
  const l = D.layout(g, measure, {});
  assert.deepEqual(Object.keys(l.nodes).sort(), ["__proto__", "constructor", "hasOwnProperty", "toString"]);
  assert.equal(l.edges.length, 2);
});

check("whatever's written, under the cap: read and laid out at once", () => {
  const R = (s, n) => s.repeat(n);
  const ids = (p, n) => Array.from({ length: n }, (_, i) => p + i);
  const chain = ids("n", 199).map((x, i) => x + "-->n" + (i + 1)).join("\n");
  let seed = 1;
  const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
  const tangle = Array.from({ length: 400 }, (_, i) => "n" + Math.floor(rnd() * 200) + " -->|" + i + "| n" + Math.floor(rnd() * 200)).join("\n");
  const inputs = {
    "a long line with words": "A -- x " + R("-", 18000) + "> B",
    "long lines down a long chain": chain + "\n" + R("n0-->|x|n199\n", 200),
    "a tangle of 200 boxes and 400 lines with words": tangle,
    "groups a thousand deep": ids("subgraph g", 1000).join("\n") + "\nx-->y\n",
    "a group begun again and again": R("subgraph a\nx-->y\nend\n", 800),
    "ids each given every class": "a-->b\nclass " + R("a,", 4500) + "a " + R("x,", 4500) + "x",
    "a class line nearly a list": "a-->b\nclass x " + R("a , ", 4900) + "a !",
    "a linkStyle naming lines over and over": chain + "\nlinkStyle " + Array.from({ length: 1700 }, (_, i) => i % 400).join(",") + " stroke:red",
    "every pair, many times over": R("a&", 4900) + "a-->" + R("a&", 4900) + "a",
    "one long word in @{ }": "a@{ " + R("a", 19000) + " }",
    "semicolons in a style": "a-->b\nclassDef x fill:(" + R(";", 19000) + "x",
    "brackets that never close": R("a(((x))-->", 1900),
    "ids of dashes and dots": R("a-.-", 4900) + "b",
    "the same line, many times": R("a-->b;", 3300),
  };
  for (const name of Object.keys(inputs)) {
    const text = "graph TD\n" + inputs[name];
    assert.ok(text.length <= D.MAX_TEXT, name + " is under the cap");
    timed(text);
    const r = timed(text);
    assert.ok(r.ms < 100, name + ": " + r.ms.toFixed(1) + " ms");
  }
});

console.log(`diagram: ${passed} checks passed`);
