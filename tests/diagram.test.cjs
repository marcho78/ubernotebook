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

console.log(`diagram: ${passed} checks passed`);
