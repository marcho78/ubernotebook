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

check("text from a page file can't become anything but text: no pictures, no odd styles, no odd links", () => {
  const Workspace = load("Workspace.js");
  const Blocks = load("Blocks.js");
  // A style whose value, decoded, closes its attribute and starts a picture;
  // through the page's checks and the editor's (and once more), still text.
  const evil = '<span style="font-family:&quot;&gt;&lt;span style=\'font-family:&quot;&gt;&lt;img src=&quot;https://example.invalid/track.png&quot;&gt;\'&gt;">hello</span>';
  const pageId = "6f1c2b9e-0d3a-4f6e-9b1c-2e8a7d5f4c3b";
  const blockId = "7a2d3c4b-1e5f-4a6b-8c7d-9e0f1a2b3c4d";
  const page = Workspace.cleanPage({ title: "t", content: [blockId], blocks: { [blockId]: { type: "p", html: evil } } }, pageId);
  let html = page.blocks[blockId].html;
  for (let pass = 0; pass < 3; pass++) {
    assert.ok(!/<img|<span[^>]*<|style="[^"]*"[^>]*"/i.test(html), "pass " + pass + ": " + html);
    html = plain(Blocks.cleanList(Workspace.flatten({ content: [blockId], blocks: { [blockId]: { id: blockId, type: "p", html: html } } }), { nest: true }))[0].html;
  }
  assert.equal(Html.plainText(html), "hello");
  // Every kept look is one Uber Notebook could have written; anything else goes.
  const looks = [
    ['<span style="color: red&quot; onclick=&quot;x">a</span>', ""],
    ['<span style="color:#C00">a</span>', "color:#cc0000;"],
    ['<span style="background-color: url(https://x.invalid/a.png)">a</span>', ""],
    ['<span style="color: expression(alert(1))">a</span>', ""],
    ['<span style="font-family:\'iA Writer Mono S\'">a</span>', "font-family:'iA Writer Mono S';"],
    ['<span style="font-family: x&quot;&gt;&lt;img src=y&gt;">a</span>', ""],
    ['<span style="font-size:24px">a</span>', "font-size:24px;"],
    ['<span style="font-size:18pt">a</span>', "font-size:24px;"],
    ['<span style="font-size:99999px">a</span>', ""],
    ['<span style="font-size:calc(1px*9e9)">a</span>', ""],
    ['<span style="x&quot;y:1; font-weight:bold">a</span>', "font-weight:700;"]
  ];
  for (const [input, css] of looks) {
    const out = Html.sanitize(input, true);
    assert.equal(out, css ? '<span style="' + css + '">a</span>' : "a", input);
    assert.equal(Html.sanitize(out, true), out, "the same the second time: " + input);
  }
  // Links: the web, email, Uber Notebook's own; nothing else.
  for (const [href, kept] of [["https://e.org", true], ["mailto:a@b.org", true], ["uber-notebook://page/" + pageId, true],
    ["file:///etc/passwd", false], ["javascript:alert(1)", false], ["data:text/html,x", false], ["FILE:///x", false], ["vbscript:x", false]]) {
    const out = Html.sanitize('<a href="' + href + '">a</a>', true);
    assert.equal(out, kept ? '<a href="' + href + '">a</a>' : "a", href);
  }
  assert.equal(Html.cleanUrl("file:///home/me/secret.txt"), "", "a typed link to a file isn't one");
  assert.equal(Html.cleanUrl("https://e.org/a"), "https://e.org/a");
  // Whatever a run's style says, it's written as one attribute.
  assert.equal(Html.serialize([{ text: "a", style: { "font-family": '"x"><img src=y>' }, href: "" }]),
    '<span style="font-family:&quot;x&quot;&gt;&lt;img src=y&gt;;">a</span>');
});

check("HTML from the clipboard: nothing in it Qt would load, its writing kept", () => {
  const w = Html.withoutResources;
  // Pictures, stylesheets, scripts, frames, media: gone (what's inside them too).
  assert.equal(w('<p>Hi <img src="http://t.example/p.png"> there</p>'), "<p>Hi  there</p>");
  assert.equal(w('<link rel="stylesheet" href="http://t.example/s.css"><style>p { background: url(x) }</style><p>a</p>'), "<p>a</p>");
  assert.equal(w('<script>alert(1)</script><SCRIPT type="x">b</SCRIPT>c<svg><image href="http://t.example/i.png"/></svg>'), "c");
  assert.equal(w('<iframe src="http://t.example/"></iframe><video src="v.mp4"></video><object data="o"></object>d'), "d");
  assert.equal(w("<script>never closed <p>text</p>"), "", "an element that isn't closed: the rest goes");
  assert.equal(w("<img/src=http://t.example/x.png>e"), "e");
  // Attributes: only a few, and nothing that would load.
  assert.equal(w('<table background="http://t.example/b.png" border="1"><tr><td bgcolor="#fff" onclick="x()">c</td></tr></table>'),
    '<table border="1"><tr><td bgcolor="#fff">c</td></tr></table>');
  assert.equal(w('<p style="color:#c00; background-image:url(http://t.example/b.png); font-weight:700">x</p>'), '<p style="color:#c00; font-weight:700">x</p>');
  assert.equal(w('<p style="background: URL(http://t.example/b.png)">x</p>'), '<p style="">x</p>');
  assert.equal(w('<p style="background:u\\72l(http://t.example/b.png)">x</p>'), '<p style="">x</p>', "nor written with escapes");
  assert.equal(w('<a href="https://e.org/?a=1&amp;b=2">w</a><a href="javascript:alert(1)">j</a><a href="file:///etc/passwd">f</a>'),
    '<a href="https://e.org/?a=1&amp;b=2">w</a><a>j</a><a>f</a>');
  // Comments and declarations go; a "<" that isn't a tag is text.
  assert.equal(w('<!DOCTYPE html><!-- <img src="http://t.example/c.png"> --><?xml x?>1 < 2 <3'), "1 &lt; 2 &lt;3");
  assert.equal(w('<!-- never closed <img src="x">'), "");
  // Quoted ">" inside a tag doesn't end it.
  assert.equal(w('<a href="https://e.org/?q=>" title="x">t</a>'), '<a href="https://e.org/?q=&gt;">t</a>');
  // Where the copied part starts and ends, and Qt's mark on HTML it wrote
  // (Qt reads its spaces by it): kept, as Qt's own paste reads them.
  assert.equal(w('<html><head><meta name="qrichtext" content="1" /><style>p { white-space: pre-wrap }</style></head><body><!--StartFragment-->a  b<!--EndFragment--></body></html>'),
    '<meta name="qrichtext" content="1" /><!--StartFragment-->a  b<!--EndFragment-->');
  // Its text as paragraphs when there's no HTML, spaces and "<" as typed, an
  // empty line as Qt writes one (an empty <p> isn't a paragraph to Qt).
  assert.equal(Html.plainParagraphs("a  b\r\n<c>\u2028\nd"),
    '<p style="white-space:pre-wrap;">a  b</p><p style="white-space:pre-wrap;">&lt;c&gt;</p><p style="-qt-paragraph-type:empty;"><br /></p><p style="white-space:pre-wrap;">d</p>');
});

check("HTML from the clipboard: a lot of it, read in time", () => {
  const cases = {
    "many dropped elements": "<style>a</style>x".repeat(250000),
    "many opened, one closed": "<script>".repeat(500000) + "</script>",
    "a quote never closed": '<p title="' + "a b=c ".repeat(600000),
    "many stray <": "< ".repeat(1500000),
    "many tags with attributes": '<span style="color:#c00" class="a">x</span>'.repeat(90000)
  };
  for (const [name, html] of Object.entries(cases)) {
    const t = Date.now();
    Html.withoutResources(html);
    const ms = Date.now() - t;
    assert.ok(ms < 3000, name + ": " + ms + " ms for " + html.length + " characters");
  }
});

console.log(`html: ${passed} checks passed`);
