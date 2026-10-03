// Checks how a block's rich text is read, changed and written back.
// Usage (from the plugin directory): node tests/html.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Html = load("Html.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

// What Qt writes for a block (getFormattedText, between the fragment markers).
const qt = 'Hello <span style=" font-weight:700;">bold</span> <span style=" color:#cc0000;">red</span> '
  + '<a href="https://e.org"><span style=" text-decoration: underline; color:#0000ff;">link</span></a><br />second &amp; &lt;line&gt;';

check("reads Qt's html into runs", () => {
  const runs = plain(Html.parse(qt));
  assert.equal(runs[0].text, "Hello ");
  assert.deepEqual(runs[1], { text: "bold", style: { "font-weight": "700" }, href: "" });
  assert.equal(runs[5].href, "https://e.org");
  assert.deepEqual(runs[6], { br: true });
  assert.equal(runs[7].text, "second & <line>");
  assert.equal(Html.plainText(qt), "Hello bold red link\nsecond & <line>");
});

check("writes runs back, flat and escaped", () => {
  assert.equal(Html.serialize(Html.parse("a <b>b <i>c</i></b> d")),
    'a <span style="font-weight:700;">b </span><span style="font-style:italic; font-weight:700;">c</span> d');
  assert.equal(Html.serialize(Html.parse("x &lt;script&gt; &amp; y")), "x &lt;script&gt; &amp; y");
  const again = Html.serialize(Html.parse(qt));
  assert.equal(Html.serialize(Html.parse(again)), again, "stable");
});

check("toggles like a word processor", () => {
  const mixed = 'plain <span style=" font-weight:700;">bold</span>';
  const bolded = Html.toggle(mixed, "bold");
  assert.equal(Html.summarize(bolded).bold, "all", "some bold -> all bold");
  assert.equal(Html.summarize(Html.toggle(bolded, "bold")).bold, "none", "all bold -> none");
  assert.equal(Html.wouldApply(mixed, "bold"), true);
  assert.equal(Html.wouldApply(bolded, "bold"), false);

  const both = Html.toggle(Html.toggle("x", "underline"), "strike");
  assert.match(both, /text-decoration:underline line-through/);
  const noUnder = Html.toggle(both, "underline");
  assert.match(noUnder, /text-decoration:line-through;/);
  assert.doesNotMatch(noUnder, /underline/);
  assert.equal(Html.toggle(noUnder, "strike"), "x", "nothing left");
});

check("keeps each run's size when bolding a mix", () => {
  const mix = 'small <span style=" font-size:30px;">BIG</span> small';
  const out = Html.toggle(mix, "bold");
  assert.match(out, /font-size:30px; font-weight:700;">BIG/);
  assert.equal(Html.parse(out).filter((r) => r.style["font-size"]).length, 1, "only BIG is big");
});

check("colors, highlights, fonts and sizes", () => {
  assert.equal(Html.setColor("a", "#ABC"), '<span style="color:#aabbcc;">a</span>');
  assert.equal(Html.setColor('<span style=" color:#aabbcc;">a</span>', ""), "a");
  assert.equal(Html.setHighlight("a", "#fff176"), '<span style="background-color:#fff176;">a</span>');
  assert.equal(Html.setFamily("a", "Caveat"), "<span style=\"font-family:'Caveat';\">a</span>");
  assert.equal(Html.setSize("a", 22.4), '<span style="font-size:22px;">a</span>');
  const s = plain(Html.summarize('<span style=" color:#aabbcc;">a</span><span style=" color:#AABBCC; font-size:12pt;">b</span>'));
  assert.equal(s.color, "#aabbcc");
  assert.equal(s.size, null, "mixed sizes");
  assert.equal(plain(Html.summarize("plain")).color, "");
  assert.equal(Html.normalColor("rgba(255, 0, 16, 0.5)"), "#ff0010");
});

check("colors swap for dark paper and back", () => {
  const table = { "#1e4fa3": "#8ab4f8", "#fff27a": "#5e5316" };
  const back = { "#8ab4f8": "#1e4fa3", "#5e5316": "#fff27a" };
  const inner = '<span style=" color:#1E4FA3; background-color:#fff27a;">x</span><span style=" color:#123456;">y</span>';
  const dark = Html.mapColors(inner, table);
  assert.match(dark, /color:#8ab4f8/);
  assert.match(dark, /background-color:#5e5316/);
  assert.match(dark, /color:#123456/, "colors not in the table stay");
  assert.equal(Html.mapColors(dark, back), Html.serialize(Html.parse(inner)).replace("#1E4FA3", "#1e4fa3"));
  assert.equal(Html.mapColors("plain", table), "plain");
});

check("the biggest text in a block", () => {
  assert.equal(Html.maxSize("plain"), 0);
  assert.equal(Html.maxSize('a <span style=" font-size:24px;">big</span> <span style=" font-size:18pt;">pt</span>'), 24);
  assert.equal(Html.maxSize('<span style=" font-size:40px;"> </span>x'), 0, "a big space draws nothing");
});

check("links", () => {
  const linked = Html.setLink("go <b>here</b>", "https://x.org/?a=1&b=2");
  assert.equal(linked, '<a href="https://x.org/?a=1&amp;b=2">go <span style="font-weight:700;">here</span></a>');
  assert.equal(plain(Html.summarize(linked)).link, "https://x.org/?a=1&b=2");
  assert.equal(Html.setLink(linked, ""), 'go <span style="font-weight:700;">here</span>');
  assert.equal(Html.cleanUrl("example.com/x"), "https://example.com/x");
  assert.equal(Html.cleanUrl("javascript:alert(1)"), "");
  assert.equal(Html.cleanUrl("https://a.b/c d"), "");
  assert.equal(Html.cleanUrl("mailto:a@b.c"), "mailto:a@b.c");
});

check("Qt's link colors are dropped on the way in and drawn on the way out", () => {
  const inner = Html.extractInner('<html><body><p><!--StartFragment--><a href="https://e.org"><span style=" text-decoration: underline; color:#0000ff;">link</span></a><!--EndFragment--></p></body></html>');
  assert.equal(inner, '<a href="https://e.org">link</a>');
  const wrapped = Html.wrapBlock(inner, 30, "#3366cc");
  assert.match(wrapped, /<a href="https:\/\/e.org"><span style="color:#3366cc; text-decoration:underline;">link<\/span><\/a>/);
});

check("clearing formatting keeps links and breaks", () => {
  assert.equal(Html.clearFormatting('<a href="https://e.org"><span style=" font-weight:700;">x</span></a><br /><span style=" color:#ff0000;">y</span>'),
    '<a href="https://e.org">x</a><br />y');
});

check("pasted text keeps what it says, not how it looked", () => {
  const web = '<span style=" font-family:\'Comic Sans\'; font-size:40px; color:#123456; background-color:#000; font-weight:600;">Hi</span>'
    + ' <a href="javascript:evil()">bad</a> <a href="https://ok.org">ok</a><img src="x.png" /> t\u0007x';
  assert.equal(Html.sanitize(web), '<span style="font-weight:700;">Hi</span> bad <a href="https://ok.org">ok</a> tx');
  assert.match(Html.sanitize(web, true), /color:#123456/, "unless it's Uber Notebook's own");
});

check("the paragraph around a block", () => {
  const empty = Html.wrapBlock("", 32);
  assert.match(empty, /-qt-paragraph-type:empty/);
  assert.match(empty, /line-height:32px; -qt-line-height-type: fixed;/);
  assert.match(empty, /<br \/><\/p>$/);
  assert.match(Html.wrapBlock("x", 64), /^<p style="[^"]*line-height:64px[^"]*">x<\/p>$/);
  assert.equal(Html.extractInner("<html><body>\n<p style=\"x\">only <b>this</b></p></body></html>"), "only <b>this</b>");
  // Qt leaves out the start marker when a range starts a list item.
  const listItem = '<body>\n<p style="-qt-paragraph-type:empty;"><br /></p>\n<ul style="x">\n<li style="margin-top:12px;">item <b>b</b><!--EndFragment--></li></ul></body></html>';
  assert.equal(Html.extractInner(listItem), "item <b>b</b>");
});

check("plain text in and out", () => {
  assert.equal(Html.fromPlainText("a < b\nc"), "a &lt; b<br />c");
  assert.equal(Html.plainText(Html.fromPlainText("a < b\nc")), "a < b\nc");
  assert.equal(Html.plainText("a&nbsp;b"), "a b");
  assert.equal(Html.decodeEntities("&#x1F600;&#169;&bogus;&#0;"), "\u{1F600}\u00a9&bogus;&#0;");
});

check("odd html doesn't break it", () => {
  assert.equal(Html.plainText("a < b"), "a < b");
  assert.equal(Html.plainText("<span>unclosed <b>bold"), "unclosed bold");
  assert.equal(Html.plainText("</b>stray close"), "stray close");
  assert.equal(Html.plainText('<span title="a > b">x</span>'), "x");
  assert.equal(Html.serialize(Html.parse('<img src="a&quot;b.png" onerror="x" />')), '<img onerror="x" src="a&quot;b.png" />');
  assert.equal(Html.sanitize('<img src="x" onerror="alert(1)" />'), "", "pictures never come in with a paste");
});

check("links inside Uber Notebook", () => {
  const page = "uber-notebook://page/6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b";
  const kept = Html.sanitize('<a href="' + page + '">Plans</a> <a href="uber-notebook://remind/2026-10-01T09:30">Thu 1 Oct 9:30</a> <a href="uber-notebook://page/../../x">bad</a> <a href="uber-notebook://run/rm">no</a>', true);
  assert.ok(kept.includes('href="' + page + '"'), "a page link is kept");
  assert.ok(kept.includes('href="uber-notebook://remind/2026-10-01T09:30"'), "and a reminder");
  assert.ok(!kept.includes("../"), "not an odd one");
  assert.ok(!kept.includes("uber-notebook://run"));
  assert.equal(Html.pageOf(page), "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b");
  assert.equal(Html.pageOf("uber-notebook://date/2026-10-01"), "");
  const decorated = Html.decorateLinks('<a href="uber-notebook://date/2026-10-01">Thu 1 Oct</a> <a href="' + page + '">Plans</a>', "#2456b3");
  assert.ok(/<a href="uber-notebook:\/\/date[^"]*"><span style="[^"]*text-decoration:none;/.test(decorated), "a date isn't underlined: " + decorated);
  assert.ok(/<a href="uber-notebook:\/\/page[^"]*"><span style="[^"]*text-decoration:underline;/.test(decorated), "a page link is");
  assert.ok(!/text-decoration/.test(Html.normalizeLinks(decorated)), "and neither is kept in what's saved");
  assert.deepEqual(JSON.parse(JSON.stringify(Html.links('a <a href="' + page + '">Pl<b>an</b>s</a> b'))).map((l) => [l.href, l.text]), [[page, "Plans"]], "a link split into runs is one");
  assert.equal(Html.plainText(Html.refreshPageLinks('see <a href="' + page + '">Old <b>name</b></a>!', () => "New name")), "see New name!");
  assert.equal(Html.plainText(Html.refreshPageLinks('<a href="' + page + '">Old <b>name</b></a>', () => "")), "Old name", "unknown pages keep their text");
});

console.log(`html: ${passed} checks passed`);
