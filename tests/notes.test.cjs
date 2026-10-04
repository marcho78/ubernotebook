// Checks footnotes: kept as links that hold their words, shown as their
// numbers (images that say which footnote they are), numbered down the
// page, found in a block's text, and read from Markdown's [^1] and ^[…].
// Usage (from the plugin directory): node tests/notes.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const N = load("Notes.js");
const E = load("Equations.js");
const Html = load("Html.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("a footnote is a link that keeps its words", () => {
  const l = N.link("  Smith, 2021:\n page 4 & more ");
  assert.equal(N.textOf(plain(Html.links(l))[0].href), "Smith, 2021: page 4 & more");
  assert.equal(Html.plainText(l), "Smith, 2021: page 4 & more", "its words, for search");
  assert.ok(Html.isInternal(plain(Html.links(l))[0].href), "pasting keeps it");
  assert.equal(N.link(""), "");
  assert.equal(N.textOf("uber-notebook://math/x"), "");
  assert.deepEqual(plain(N.inText("A " + N.link("one") + " b " + N.link("two"))), ["one", "two"]);
  assert.deepEqual(plain(N.order(["a " + N.link("one"), N.link("two") + N.link("one"), "c " + N.link("three")])), ["one", "two", "three"], "numbered down the page, the same words once");
});

check("shown as its number; kept as its link", () => {
  const inner = "A claim" + N.link("The source") + " and another" + N.link("Second") + ".";
  const shown = N.toImages(inner, (t) => (t === "The source" ? 1 : 2), 16, "#2456b3");
  const imgs = shown.match(/<img [^>]+>/g);
  assert.equal(imgs.length, 2);
  assert.equal(N.textOfImage(/src="([^"]+)"/.exec(imgs[1])[1]), "Second");
  assert.ok(decodeURIComponent(/,([^"]+)"/.exec(imgs[0])[1]).includes(">1</text>"), "its number");
  assert.equal(N.toLinks(shown), inner, "and back");
  assert.equal(N.toLinks(E.toImages(E.link("x^2"), () => null, 16, "#000")), E.toImages(E.link("x^2"), () => null, 16, "#000"), "an equation's image isn't a footnote");
});

check("where a footnote is in a block's shown text", () => {
  const inner = "ab" + E.link("x^2") + "cd" + N.link("n1") + "e<br />f" + N.link("n2") + N.link("n1");
  assert.equal(N.positionIn(inner, "n1", 0), 5, "a, b, the equation (one), c, d");
  assert.equal(N.positionIn(inner, "n2", 0), 9);
  assert.equal(N.positionIn(inner, "n1", 1), 10, "the second time");
  assert.equal(N.positionIn(inner, "none", 0), -1);
});

check("Markdown's footnotes: their words at the end, taken out", () => {
  const d = plain(N.definitions(["Text[^1] and[^a].", "", "[^1]: The source.", "[^a]: A longer note", "    that goes on.", "After.", "```", "[^x]: in code", "```"]));
  assert.deepEqual(d.notes, { 1: "The source.", a: "A longer note that goes on." });
  assert.deepEqual(d.lines, ["Text[^1] and[^a].", "", "After.", "```", "[^x]: in code", "```"]);
});

check("a footnote's words from Markdown read without the marks", () => {
  assert.equal(N.fromMarkdown("Euclid, *Elements*, Book I"), "Euclid, Elements, Book I");
  assert.equal(N.fromMarkdown("**Heath** (1908), _trans._ `p. 4` ~~old~~"), "Heath (1908), trans. p. 4 old");
  assert.equal(N.fromMarkdown("See [the paper](https://x.org/a) and <https://y.org>"), "See the paper (https://x.org/a) and <https://y.org>");
  assert.equal(N.fromMarkdown("snake_case and 2*3*4 stay"), "snake_case and 2*3*4 stay");
});

console.log(`notes: ${passed} checks passed`);
