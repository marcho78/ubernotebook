// Checks tags: names, links, "#words" turned into tags, renaming and
// taking a tag away.
// Usage (from the plugin directory): node tests/tags.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const T = load("Tags.js");
const Html = load("Html.js");
const W = load("Workspace.js");
const Markdown = load("Markdown.js");
const Import = load("Import.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("names", () => {
  assert.equal(T.clean("#Idea"), "idea");
  assert.equal(T.clean("project/uber-notebook"), "project/uber-notebook", "nested");
  assert.equal(T.clean("to-do_list"), "to-do_list");
  assert.equal(T.clean("caf\u00e9"), "caf\u00e9", "any letters");
  assert.equal(T.clean("2026"), "", "only digits is a number");
  assert.equal(T.clean("y2026"), "y2026");
  assert.equal(T.clean("a b"), "", "no spaces");
  assert.equal(T.clean("a,b"), "", "no punctuation");
  assert.equal(T.clean("/x"), "");
  assert.equal(T.clean("idea-"), "idea", "a dash at the end isn't part of it");
  assert.equal(T.clean("x".repeat(61)), "");
  assert.equal(T.label("Idea"), "#Idea");
  assert.equal(T.href("Caf\u00e9 Ideas"), "", "no spaces");
  assert.equal(T.href("Caf\u00e9"), "uber-notebook://tag/caf%C3%A9");
  assert.equal(T.of("uber-notebook://tag/caf%C3%A9"), "caf\u00e9");
  assert.equal(T.of("uber-notebook://tag/Idea"), "", "only names as Uber Notebook writes them");
  assert.equal(T.of("uber-notebook://page/x"), "");
  assert.ok(Html.isInternal(T.href("idea")), "a link Uber Notebook keeps");
  assert.ok(Html.isInternal(T.href("caf\u00e9/x")));
});

check("in a block", () => {
  const inner = "Buy milk " + T.html("Errand") + " and " + T.html("home") + " " + T.html("errand");
  assert.equal(T.html("Errand"), '<a href="uber-notebook://tag/errand">#Errand</a>');
  assert.deepEqual(plain(T.inHtml(inner)), [{ name: "errand", label: "#Errand" }, { name: "home", label: "#home" }], "each once");
  assert.equal(Html.sanitize(inner, true), inner, "kept as it is");
});

check("#words as tags", () => {
  const l = (s) => T.linkify(s);
  assert.equal(l("Call mum #family #home"), 'Call mum <a href="uber-notebook://tag/family">#family</a> <a href="uber-notebook://tag/home">#home</a>');
  assert.equal(l("#idea at the start"), '<a href="uber-notebook://tag/idea">#idea</a> at the start');
  assert.equal(l("C# and issue#4 and #1 and # heading"), "C# and issue#4 and #1 and # heading", "not in words, not numbers, not alone");
  assert.equal(l("(#later)"), '(<a href="uber-notebook://tag/later">#later</a>)');
  assert.equal(l("end #done."), 'end <a href="uber-notebook://tag/done">#done</a>.', "a full stop isn't part of it");
  const code = '<span style="font-family:\'iA Writer Mono S\';">#include</span> x';
  assert.equal(l(code), code, "not in code");
  const link = '<a href="https://x.org/#top">#top</a>';
  assert.equal(l(link), link, "not in a link");
  assert.equal(l('<span style="font-weight:700;">#bold</span>'), '<a href="uber-notebook://tag/bold"><span style="font-weight:700;">#bold</span></a>', "keeping its look");
});

check("renamed and taken away", () => {
  const inner = "a " + T.html("Old") + " b " + T.html("keep");
  assert.equal(T.rename(inner, "old", "New/Thing"), 'a <a href="uber-notebook://tag/new%2Fthing">#New/Thing</a> b <a href="uber-notebook://tag/keep">#keep</a>');
  assert.equal(T.remove(inner, "old"), 'a b <a href="uber-notebook://tag/keep">#keep</a>');
  assert.equal(T.remove(T.html("x") + " first", "x"), "first", "a space goes with it");
  assert.equal(T.remove("last " + T.html("x"), "x"), "last");
  assert.deepEqual(plain(T.matching(["home", "homework", "work", "art"], "wo")), ["work", "homework"], "starting with it first");
  assert.deepEqual(plain(T.matching(["b", "a"], "")), ["b", "a"]);
});

check("a page's tags, and every tag", () => {
  const a = W.uuid4(), b = W.uuid4(), c = W.uuid4(), t = W.uuid4();
  const page = { id: "p", content: [a, b, c, t], blocks: {
    [a]: { type: "check", html: "milk " + T.html("Errand"), checked: true },
    [b]: { type: "p", html: T.html("errand") + " and " + T.html("home") },
    [c]: { type: "code", html: "#errand in code" },
    [t]: { type: "table", table: { rows: [["x", T.html("home")], [T.html("home"), "y"]] } } } };
  assert.deepEqual(plain(W.pageTags(page)), [{ name: "errand", label: "#Errand", n: 2 }, { name: "home", label: "#home", n: 2 }], "blocks with it, a table once");
  const tagged = plain(W.taggedBlocks(page, "home"));
  assert.deepEqual(tagged.map((x) => x.type), ["p", "table"]);
  assert.ok(tagged[1].html.includes(" \u00b7 "), "a table's cells with it, side by side");
  assert.equal(plain(W.taggedBlocks(page, "errand"))[0].checked, true);
  // The index keeps them, and the list counts them (not the trash's).
  const p1 = W.uuid4(), p2 = W.uuid4(), p3 = W.uuid4();
  const ix = plain(W.cleanIndex({ top: [p1, p2, p3], pages: {
    [p1]: { title: "A", tags: [{ name: "errand", label: "#Errand", n: 2 }, { name: "BAD", label: "x", n: 1 }] },
    [p2]: { title: "B", tags: [{ name: "errand", label: "#errand", n: 1 }] },
    [p3]: { title: "C", trashed: true, tags: [{ name: "gone", label: "#gone", n: 1 }] } }, tagColors: { errand: "blue", "Not a tag": "red", home: "javascript:" } }));
  assert.deepEqual(ix.pages[p1].tags, [{ name: "errand", label: "#Errand", n: 2 }], "only names it writes");
  assert.deepEqual(ix.tagColors, { errand: "blue" });
  assert.deepEqual(plain(W.tagList(ix)), [{ name: "errand", label: "#Errand", pages: 2, blocks: 3 }]);
  assert.deepEqual(plain(W.pagesTagged(ix, "errand")).sort(), [p1, p2].sort());
  assert.ok(JSON.parse(W.indexJson(ix)).tagColors.errand === "blue", "colors kept");
  assert.equal(W.cleanIndex({ pages: { [p1]: { title: "Old" } } }).pages[p1].tags, null, "not worked out yet");
  // Renamed in a page.
  const n = W.changeTags(page, (inner) => T.rename(inner, "home", "house"));
  assert.equal(n, 2);
  assert.deepEqual(plain(W.pageTags(page)).map((x) => x.name), ["errand", "house"]);
});

check("colors: their own, or the tag they're in's; sorted by them", () => {
  const colors = { work: "blue", "work/acme": "#ff8800", home: "green" };
  assert.deepEqual(plain(W.tagColorOf(colors, "work/acme")), { color: "#ff8800", from: "work/acme" }, "its own");
  assert.deepEqual(plain(W.tagColorOf(colors, "work/beta/x")), { color: "blue", from: "work" }, "the nearest tag it's in's");
  assert.deepEqual(plain(W.tagColorOf(colors, "misc")), { color: "", from: "" });
  const list = ["zeta", "work", "work/acme", "work/beta", "home", "art", "lone/child"].map((n) => ({ name: n, label: "#" + n, pages: 1, blocks: 1 }));
  const byName = plain(W.sortTags(list, colors, "name"));
  assert.deepEqual(byName.map((t) => t.name + ":" + t.depth), ["art:0", "home:0", "lone/child:0", "work:0", "work/acme:1", "work/beta:1", "zeta:0"], "nested under the tag they're in, when it's there");
  assert.equal(byName.find((t) => t.name === "work/beta").color, "blue", "inherited");
  const byColor = plain(W.sortTags(list, colors, "color")).map((t) => t.name);
  assert.deepEqual(byColor, ["home", "work", "work/beta", "work/acme", "art", "lone/child", "zeta"], "Pages' colors in order, then yours, then gray");
});

check("in and out as Markdown", () => {
  const md = plain(Import.fromMarkdown("Plan #trip/lisbon and `#code` and [#link](https://x.org)\n\n- [ ] book #Errand")).blocks;
  assert.deepEqual(plain(T.inHtml(md[0].html)).map((t) => t.name), ["trip/lisbon"], "Obsidian's tags are tags; code and links aren't");
  assert.deepEqual(plain(T.inHtml(md[1].html)), [{ name: "errand", label: "#Errand" }]);
  assert.equal(Markdown.inline("buy " + T.html("Errand") + " now"), "buy #Errand now", "out as its words");
  assert.equal(Markdown.inline(md[0].html).indexOf("#trip/lisbon"), 5);
});

console.log(`tags: ${passed} checks passed`);
