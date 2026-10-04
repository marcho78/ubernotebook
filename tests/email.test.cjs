// Emails on pages (Email.js): an .eml read (headers with encoded words,
// folded lines; plain and HTML bodies in base64 and quoted-printable,
// UTF-8, Latin-1, Windows-1252; attachments with RFC 2231 names; nested
// multiparts; inline pictures not listed), its HTML made safe to show, a
// preview, what a block keeps, and its Markdown.
const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const E = load("Email.js");

let passed = 0;
function check(name, fn) { fn(); passed++; }

const b64 = (s) => Buffer.from(s, "utf8").toString("base64");

const multi = [
  "Return-Path: <sam@acme.com>",
  "From: =?UTF-8?Q?Sam_Rivera?= <Sam@Acme.com>",
  "To: \"Doe, Jane\" <jane@contoso.com>, team@acme.com",
  "Cc: =?UTF-8?B?" + b64("Zoë Ng") + "?= <zoe@acme.com>",
  "Subject: =?UTF-8?B?" + b64("Launch plan 🚀") + "?=",
  " =?UTF-8?Q?_=E2=80=94_final?=",
  "Date: Fri, 02 Oct 2026 09:30:00 +0200",
  "MIME-Version: 1.0",
  "Content-Type: multipart/mixed; boundary=\"outer\"",
  "",
  "This is a multi-part message.",
  "--outer",
  "Content-Type: multipart/related; boundary=rel",
  "",
  "--rel",
  "Content-Type: multipart/alternative; boundary=\"alt\"",
  "",
  "--alt",
  "Content-Type: text/plain; charset=utf-8",
  "Content-Transfer-Encoding: quoted-printable",
  "",
  "Hi team, the launch moves to Fri=C3=A9 =E2=80=94 see https://acme.com/plan.",
  "> old quoted line",
  "Thanks, Sam=",
  "",
  "--alt",
  "Content-Type: text/html; charset=utf-8",
  "Content-Transfer-Encoding: base64",
  "",
  b64("<html><head><style>p{color:red}</style><script>alert(1)</script></head><body><p onclick=\"x()\" style=\"color:red\">Hi <b>team</b>, see <a href=\"https://acme.com/plan\" target=\"_blank\">the plan</a> and <a href=\"javascript:evil()\">this</a>.</p><img src=\"https://tracker.example/pixel.gif\"><img src=\"cid:logo1\" alt=\"Acme logo\"><form><input></form><p>Caf&eacute; &amp; more&hellip;</p></body></html>"),
  "--alt--",
  "--rel",
  "Content-Type: image/png",
  "Content-ID: <logo1>",
  "Content-Disposition: inline",
  "Content-Transfer-Encoding: base64",
  "",
  "iVBORw0KGgo=",
  "--rel--",
  "--outer",
  "Content-Type: application/pdf; name=\"plan.pdf\"",
  "Content-Disposition: attachment; filename*=UTF-8''%E2%82%AC%20rates.pdf",
  "Content-Transfer-Encoding: base64",
  "",
  b64("%PDF-1.4 hello"),
  "--outer",
  "Content-Type: text/plain; charset=iso-8859-1; name=notes.txt",
  "Content-Disposition: attachment; filename=\"notes.txt\"",
  "Content-Transfer-Encoding: quoted-printable",
  "",
  "caf=E9",
  "--outer--",
  ""
].join("\r\n");

check("an .eml read: headers, bodies, attachments", () => {
  const m = E.parse(multi);
  assert.equal(m.subject, "Launch plan 🚀 — final");
  assert.deepEqual(plain(m.from), [{ name: "Sam Rivera", address: "sam@acme.com" }]);
  assert.deepEqual(plain(m.to), [{ name: "Doe, Jane", address: "jane@contoso.com" }, { name: "", address: "team@acme.com" }]);
  assert.deepEqual(plain(m.cc), [{ name: "Zoë Ng", address: "zoe@acme.com" }]);
  assert.equal(m.date, "2026-10-02T07:30:00.000Z");
  assert.equal(m.text, "Hi team, the launch moves to Frié — see https://acme.com/plan.\n> old quoted line\nThanks, Sam");
  assert.ok(m.html.indexOf("<b>team</b>") > 0);
  assert.deepEqual(plain(m.attachments.map((a) => [a.name, a.type, a.size])), [["€ rates.pdf", "application/pdf", 14], ["notes.txt", "text/plain", 4]], "the inline logo isn't one");
  // An attachment's bytes, as base64 again.
  assert.equal(Buffer.from(E.attachmentBase64(m, m.attachments[0].index), "base64").toString(), "%PDF-1.4 hello");
  assert.equal(Buffer.from(E.attachmentBase64(m, m.attachments[1].index), "base64").toString("latin1"), "café", "quoted-printable, as its bytes");
});

check("its HTML, made safe", () => {
  const safe = E.safeHtml(E.parse(multi).html);
  for (const bad of ["<script", "alert(", "<style", "color:red", "onclick", "javascript:", "tracker.example", "<img", "<form", "<input", "target="]) assert.ok(safe.indexOf(bad) < 0, bad + " in " + safe);
  assert.ok(safe.indexOf("<a href=\"https://acme.com/plan\">the plan</a>") > 0, safe);
  assert.ok(safe.indexOf("<a>this</a>") > 0, "a bad link: its words only");
  assert.ok(safe.indexOf("[Acme logo]") > 0, "a picture: its words");
  assert.ok(safe.indexOf("Caf&eacute; &amp; more&hellip;") > 0, "entities left for Qt");
  // Text: lines, links, quoted replies.
  const t = E.textHtml("See https://x.org/a.\n> quoted <b>\nmail bo@y.net", "#999999");
  assert.equal(t, "See <a href=\"https://x.org/a\">https://x.org/a</a>.<br /><span style=\"color:#999999;\">&gt; quoted &lt;b&gt;</span><br />mail <a href=\"mailto:bo@y.net\">bo@y.net</a>");
  assert.equal(E.htmlText("<p>One</p><p>Two &amp; three</p><style>x{}</style>"), "One\nTwo & three");
});

check("a plain one: Latin-1, Windows-1252, no MIME at all", () => {
  const latin = "From: bo@y.net\nSubject: =?iso-8859-1?Q?Caf=E9?=\nContent-Type: text/plain; charset=windows-1252\nContent-Transfer-Encoding: quoted-printable\n\n=93Quoted=94 =80 price\n";
  const m = E.parse(latin);
  assert.deepEqual([m.subject, m.text.trim()], ["Café", "“Quoted” € price"]);
  const bare = E.parse("From: a@b.co\nTo: c@d.co\nSubject: Hi\n\nJust text.\n");
  assert.deepEqual([bare.subject, bare.text.trim(), bare.attachments.length], ["Hi", "Just text.", 0]);
  const raw8 = E.parse("From: a@b.co\nSubject: Ünïcode\nContent-Type: text/plain; charset=utf-8\n\nÜber café\n");
  assert.deepEqual([raw8.subject, raw8.text.trim()], ["Ünïcode", "Über café"], "8-bit UTF-8 read as text");
  assert.equal(E.parse("just some words"), null, "not an email");
  assert.equal(E.date("Thu, 1 Oct 26 23:05 PDT"), "2026-10-02T06:05:00.000Z");
  assert.equal(E.date("nonsense"), "");
});

check("what a block keeps, and Markdown", () => {
  const s = plain(E.summary(E.parse(multi)));
  assert.equal(s.from, "Sam Rivera <sam@acme.com>");
  assert.equal(s.to, "Doe, Jane <jane@contoso.com>, team@acme.com");
  assert.ok(s.preview.indexOf("Hi team, the launch moves") === 0 && s.preview.indexOf("old quoted") < 0, s.preview);
  const d = plain(E.clean(Object.assign({ src: "assets/mail-20261002-093000-k3f-launch.eml", name: "Launch.eml", size: 5000 }, s, { attachments: s.attachments.concat([{ name: "x", src: "../../etc/passwd" }]) })));
  assert.equal(d.attachments[2].src, "", "an attachment's file: in assets only");
  assert.equal(E.clean({ src: "/etc/passwd" }).src, "");
  assert.equal(E.shortName(d.from), "Sam Rivera");
  assert.equal(E.shortNames("a@b.co, Bo <bo@y.net>, c@d.co", 2), "a@b.co, Bo +1");
  assert.ok(E.toMarkdown(d, "../").indexOf("> ✉ **Launch plan 🚀 — final**\n> From Sam Rivera <sam@acme.com> · to Doe, Jane") === 0);
  assert.ok(E.toMarkdown(d, "../").endsWith("[Launch.eml](../assets/mail-20261002-093000-k3f-launch.eml)"));
  assert.ok(/^mail-\d{8}-\d{6}-k3f-launch-plan\.eml$/.test(E.assetName("Launch plan.eml", new Date(), "k3f")));
});

// ---- however one's made, it's read at once -------------------------------------------------
// (An email is read on the shell's own thread. Each of these took from
// seconds to minutes, or gigabytes, or crashed the shell, or never ended.)

// What fn gives, if it took under `ms` of this process's own time on the
// processor (other work on the machine, and swapping, don't count; these
// take tens of milliseconds, and took seconds to forever).
function quick(what, fn, ms = 2000) {
  const time = () => process.cpuUsage().user / 1000;
  const t = time();
  const out = fn();
  assert.ok(time() - t < ms, what + ": " + Math.round(time() - t) + "ms");
  return out;
}
// The same "random" numbers each time.
function numbers(seed) {
  return (n) => (seed = (seed * 1103515245 + 12345) & 0x7fffffff) % n;
}

check("RFC 2231 pieces: put together in order, and a piece's number can't make it hang", () => {
  // name*4294967294= made a list four billion long, then went through it.
  const m = quick("a huge piece number", () => E.parse("Subject: probe\nContent-Type: text/plain; name*4294967294=x\n\nx"), 250);
  assert.deepEqual([m.subject, m.text, m.attachments.length, m.parts[0].name], ["probe", "x", 0, ""]);
  const name = (header) => E.params(header).params.name;
  assert.equal(name("application/pdf; name*0=\"A long \"; name*1=\"name.pdf\""), "A long name.pdf");
  assert.equal(name("a/b; name*1=\"b.pdf\"; name*0=\"a\""), "ab.pdf", "in order, however they come");
  assert.equal(name("a/b; name*0*=utf-8''%E2%82%AC%20; name*1*=rates.pdf"), "€ rates.pdf");
  assert.equal(name("a/b; name*0*=UTF-8''%E2%82%AC; name*1=\" rates.pdf\""), "€ rates.pdf", "encoded and not");
  const eml = ["From: a@b.co", "Content-Type: multipart/mixed; boundary=b", "", "--b", "Content-Type: application/pdf",
    "Content-Disposition: attachment; filename*0*=utf-8''%E2%82%AC%20a%20; filename*1*=long%20name.pdf", "", "x", "--b--"].join("\n");
  assert.equal(E.parse(eml).attachments[0].name, "€ a long name.pdf");
  // name*0= to name*63= read; one after, left out.
  const late = (n) => name("a/b; name*0=a; name*" + n + "=z");
  assert.equal(late(E.MAX_PIECES - 1), "az");
  assert.equal(late(E.MAX_PIECES), "a");
  assert.equal(E.params("a/b; constructor*0=x").params.constructor, "x", "any name is just a name");
});

check("a parameter: MAX_PARAM characters, its pieces put together", () => {
  const name = (value) => E.params("a/b; name=\"" + value + "\"").params.name;
  assert.equal(name("x".repeat(E.MAX_PARAM)).length, E.MAX_PARAM);
  assert.equal(name("x".repeat(E.MAX_PARAM + 1)).length, E.MAX_PARAM);
  const pieces = (n) => E.params("a/b" + Array.from({ length: n }, (_, i) => "; name*" + i + "=" + "y".repeat(50)).join("")).params.name;
  assert.equal(pieces(E.MAX_PARAM / 50), "y".repeat(E.MAX_PARAM));
  assert.equal(pieces(E.MAX_PARAM / 50 + 1), "y".repeat(E.MAX_PARAM));
});

check("a header: its first MAX_PARAMS parameters read", () => {
  const header = (n) => "a/b" + Array.from({ length: n }, (_, i) => "; p" + (i + 1) + "=" + (i + 1)).join("");
  assert.equal(E.params(header(E.MAX_PARAMS)).params["p" + E.MAX_PARAMS], String(E.MAX_PARAMS));
  const over = E.params(header(E.MAX_PARAMS + 1)).params;
  assert.deepEqual([over["p" + E.MAX_PARAMS], over["p" + (E.MAX_PARAMS + 1)]], [String(E.MAX_PARAMS), undefined]);
});

check("a header: MAX_LINE characters of it", () => {
  const subject = (value) => E.fields("Subject: " + value).subject.length;
  assert.equal(subject("a".repeat(E.MAX_LINE)), E.MAX_LINE);
  assert.equal(subject("a".repeat(E.MAX_LINE + 1)), E.MAX_LINE);
  assert.equal(subject("a".repeat(E.MAX_LINE / 2) + "\r\n " + "b".repeat(E.MAX_LINE)), E.MAX_LINE, "its folded lines, one");
  const eml = "From: a@b.co\nTo: " + "Sam <sam@acme.com>, ".repeat(200000) + "\n\nx";
  assert.equal(quick("4 MB of To:", () => E.parse(eml)).to.length, 100);
});

check("a header block: its first MAX_FIELDS lines read", () => {
  const head = (junk) => "From: a@b.co\n" + "X-Junk: 1\n".repeat(junk) + "Subject: s\n\nbody";
  assert.equal(E.parse(head(E.MAX_FIELDS - 2)).subject, "s", "the last line read");
  assert.equal(E.parse(head(E.MAX_FIELDS - 1)).subject, "");
  // (Over half a million crashed the shell: its split() can't make that many.)
  const eml = "From: a@b.co\n" + "X-Y: z\n".repeat(600000) + "\nbody";
  assert.equal(quick("600,000 header lines", () => E.parse(eml)).from[0].address, "a@b.co");
});

check("a header block: MAX_HEAD characters, or it's all header", () => {
  const block = (n) => { const s = "Subject: s\nX-Pad: "; return s + "a".repeat(n - s.length); };
  const at = E.parse(block(E.MAX_HEAD) + "\n\nbody");
  assert.deepEqual([at.subject, at.text], ["s", "body"]);
  const over = E.parse(block(E.MAX_HEAD + 1) + "\n\nbody");
  assert.deepEqual([over.subject, over.text], ["s", ""]);
  const eml = "From: a@b.co\n" + "a".repeat(16 << 20);
  quick("16 MB with no blank line", () => E.parse(eml));
});

check("parts: MAX_PARTS read, the message counted", () => {
  const many = (n) => E.parse("From: a@b.co\nContent-Type: multipart/mixed; boundary=b\n\n" + "--b\nContent-Type: text/plain\n\nx\n".repeat(n) + "--b--\n");
  assert.equal(many(E.MAX_PARTS - 1).parts.length, E.MAX_PARTS - 1);
  assert.equal(many(E.MAX_PARTS).parts.length, E.MAX_PARTS - 1);
  const eml = "Content-Type: multipart/mixed; boundary=b\n\n" + "--b\n\n".repeat(1e6);
  assert.equal(quick("a million parts (5 MB)", () => E.parse(eml)).parts.length, E.MAX_PARTS - 1);
});

check("multiparts in multiparts: MAX_DEPTH of them, each read where it is", () => {
  // n multiparts, one in the next (the message is the first), a text in the last.
  const nest = (n, leaf) => {
    let s = leaf;
    for (let i = n - 1; i >= 0; i--) s = "Content-Type: multipart/mixed; boundary=\"=_" + i + "_=\"\n\n--=_" + i + "_=\n" + s + "\n--=_" + i + "_=--\n";
    return "From: a@b.co\n" + s;
  };
  assert.equal(E.parse(nest(E.MAX_DEPTH, "Content-Type: text/plain\n\ndeep")).text, "deep");
  const over = E.parse(nest(E.MAX_DEPTH + 1, "Content-Type: text/plain\n\ndeep"));
  assert.deepEqual([over.text, over.attachments.length, over.attachments[0].type], ["", 1, "multipart/mixed"]);
  // (Copied out again for each one, 8 MB was 12 copies at once in the shell.)
  const eml = nest(E.MAX_DEPTH, "Content-Type: text/plain\n\n" + "y".repeat(8 << 20));
  assert.equal(quick("8 MB, 12 deep", () => E.parse(eml)).text.length, E.MAX_TEXT);
});

check("boundaries: MAX_DASHES lines starting \"--\" looked at, in all", () => {
  const eml = (n) => "From: a@b.co\nContent-Type: multipart/mixed; boundary=b\n\n--b\nContent-Type: application/sql; name=a.sql\n\nx" + "\n--x".repeat(n) + "\n--b--\n";
  // (Its two boundary lines are two of them.)
  const at = eml(E.MAX_DASHES - 2), over = eml(E.MAX_DASHES - 1);
  assert.equal(quick("as many as are looked at", () => E.parse(at)).attachments[0].size, 1 + 4 * (E.MAX_DASHES - 2));
  assert.equal(quick("one more", () => E.parse(over)).parts.length, 0);
  // A boundary, however long, is found by its line.
  const long = "From: a@b.co\nContent-Type: multipart/mixed; boundary=\"" + "a".repeat(E.MAX_PARAM) + "\"\n\n" + ("\n--" + "a".repeat(E.MAX_PARAM - 1) + "b").repeat(2000);
  quick("a long boundary, nearly there on every line", () => E.parse(long));
  // One with a line break in it (RFC 2231 can spell one) isn't found.
  const lines = "From: a@b.co\nContent-Type: multipart/mixed; boundary*=utf-8''" + "%0A--".repeat(400) + "x\n\n" + "\n--".repeat(1e6);
  assert.equal(quick("a boundary of line breaks", () => E.parse(lines)).parts.length, 0);
});

check("a body: MAX_TEXT characters of text and MAX_HTML of HTML, decoded no further", () => {
  const one = (type, enc, body) => E.parse("From: a@b.co\nContent-Type: " + type + "; charset=utf-8" + (enc ? "\nContent-Transfer-Encoding: " + enc : "") + "\n\n" + body);
  assert.equal(one("text/plain", "", "a".repeat(E.MAX_TEXT)).text.length, E.MAX_TEXT);
  assert.equal(one("text/plain", "", "a".repeat(E.MAX_TEXT + 1)).text.length, E.MAX_TEXT);
  // Three bytes a character, in base64: all of them read, and cut where one starts.
  const euros = (n, lead) => Buffer.from((lead || "") + "€".repeat(n)).toString("base64");
  assert.equal(one("text/plain", "base64", euros(E.MAX_TEXT)).text, "€".repeat(E.MAX_TEXT));
  assert.equal(one("text/plain", "base64", euros(E.MAX_TEXT + 1)).text, "€".repeat(E.MAX_TEXT));
  assert.equal(one("text/plain", "base64", euros(E.MAX_TEXT, "a")).text, "a" + "€".repeat(E.MAX_TEXT - 1), "half a character left out (not all of it read as Windows-1252)");
  // Nine characters a character, in quoted-printable HTML.
  assert.equal(one("text/html", "quoted-printable", "=E2=82=AC".repeat(E.MAX_HTML)).html, "€".repeat(E.MAX_HTML));
  assert.equal(one("text/html", "quoted-printable", "=E2=82=AC".repeat(E.MAX_HTML + 1)).html, "€".repeat(E.MAX_HTML));
  const big = "QUFB\r\n".repeat(2 << 20);
  assert.equal(quick("12 MB of text", () => one("text/plain", "base64", big)).text, "A".repeat(E.MAX_TEXT));
});

check("an attachment's size: its bytes counted, not decoded", () => {
  const rnd = numbers(7);
  const bits = ["=", "=4", "=41", "=E2=82=AC", "=\n", "=\r\n", "aZ+/", "\n", "\r\n", " ", "é", "€", "😀", "\ud800", "_", "%"];
  for (let i = 0; i < 300; i++) {
    let body = "";
    for (let k = rnd(40); k > 0; k--) body += bits[rnd(bits.length)];
    for (const enc of ["base64", "quoted-printable", "8bit"]) {
      const part = E.split("Content-Transfer-Encoding: " + enc + "\n\n" + body);
      assert.equal(E.partSize(part), E.partBytes(part).length, enc + ": " + JSON.stringify(body));
    }
  }
  // Quoted-printable of megabytes: counted a line at a time.
  const qp = E.split("Content-Transfer-Encoding: quoted-printable\n\n" + ("caf=C3=A9 =E2=82=AC, and a long line of words=\r\n" + "x".repeat(70) + "\r\n").repeat(30000));
  assert.equal(E.partSize(qp), E.partBytes(qp).length);
  const eml = "From: a@b.co\nContent-Type: application/pdf; name=a.pdf\nContent-Transfer-Encoding: base64\n\n" + "QUFB\r\n".repeat(2 << 20);
  assert.equal(quick("a 12 MB attachment", () => E.parse(eml)).attachments[0].size, 6 << 20);
});

check("whatever's in one: read at once, and nothing thrown", () => {
  // UTF-8 past U+10FFFF isn't UTF-8 (it threw), so it's Windows-1252.
  const past = E.parse("From: a@b.co\nContent-Type: text/plain; charset=utf-8\nContent-Transfer-Encoding: base64\n\n" + Buffer.from([0x68, 0x69, 0xf4, 0x90, 0x80, 0x80]).toString("base64"));
  assert.equal(past.text, "hi\u00f4\ufffd\u20ac\u20ac");
  // An email, mangled.
  const rnd = numbers(3);
  const bits = ["\n", "\r\n", "--", "--outer", "--alt--", ";", "=", "\"", "*0=", "*1*=", "<", ">", "<!--", "=?utf-8?B?", "?=", "%E2%82", "é", "\ud83d", ":", "boundary=", "\n\n"];
  for (let i = 0; i < 1500; i++) {
    let eml = multi;
    for (let k = 1 + rnd(4); k > 0; k--) {
      const at = rnd(eml.length + 1);
      eml = rnd(2) ? eml.slice(0, at) + bits[rnd(bits.length)] + eml.slice(at) : eml.slice(0, at) + eml.slice(at + 1 + rnd(30));
    }
    quick("mangled " + JSON.stringify(eml), () => {
      const m = E.parse(eml);
      if (!m) return;
      E.summary(m);
      E.displayHtml(m, "#999999");
      m.attachments.forEach((a) => { E.attachmentBase64(m, a.index); E.attachmentText(m, a.index); });
    });
  }
});

check("its HTML made safe as a browser reads it: no \"<\" but the tags it makes", () => {
  const cases = [
    // (Qt reads "< img" and "<\nimg" as pictures, and fetches them.)
    ["< img src=https://t.example/p.png>", "&lt; img src=https://t.example/p.png&gt;"],
    ["<\nimg src=https://t.example/p.png>", "&lt;\nimg src=https://t.example/p.png&gt;"],
    ["<img/src=https://t.example/p.png>", ""],
    ["<IMG SRC=https://t.example/p.png>", ""],
    ["<img src=https://t.example/p.png alt=\"A &amp; B\">", "[A &amp; B]"],
    ["<svg><image href=https://t.example/p.png /></svg>after", "after"],
    ["<svg><image href=https://t.example/p.png>after", "after"],
    ["<a href=\"javascript:alert(1)\">click", "<a>click"],
    ["<a href=\"&#106;avascript:alert(1)\">x</a>", "<a>x</a>"],
    ["<a href=\"javascript:alert(1)\"", ""],
    ["<b>x</b><a href=\"https://t.example/p.png", "<b>x</b>"],
    ["<a href=\"https://x.org/?q=a>b\" onclick=\"go()\" style=\"color:red\">x</a>", "<a href=\"https://x.org/?q=a&gt;b\">x</a>"],
    ["<A HREF=https://x.org/a?b=1&amp;c=2>x</A>", "<a href=\"https://x.org/a?b=1&amp;c=2\">x</a>"],
    ["&lt;img src=https://t.example/p.png&gt;", "&lt;img src=https://t.example/p.png&gt;"],
    ["a < b && c > d", "a &lt; b &amp;&amp; c &gt; d"],
    ["<scr<script>ipt>alert(1)</script>", "ipt&gt;alert(1)"],
    ["<p style=\"background:url(https://t.example/p.png)\">One<br>Two</p><!-- x --><!doctype html><?xml x?><![CDATA[ y ]]>", "<p>One<br />Two</p>"],
    ["<base href=https://t.example/><link rel=stylesheet href=https://t.example/s.css><meta http-equiv=refresh content=\"0;url=https://t.example\">x", "x"],
    ["<iframe src=https://t.example></iframe><object data=https://t.example/x>y", "y"],
    ["<b>b</b><foo>x</foo><__proto__>y<constructor>z", "<b>b</b>x&lt;__proto__&gt;yz"],
  ];
  for (const [html, want] of cases) {
    const safe = E.safeHtml(html);
    assert.equal(safe, want, JSON.stringify(html));
    assert.equal(E.safeHtml(safe), safe, "made safe again, the same: " + JSON.stringify(html));
  }
  // HTML mangled: no "<" but the tags it makes, and made safe again, the same.
  const ours = /<(\/?(a|b|strong|i|em|u|s|strike|del|br|p|div|span|ul|ol|li|h[1-6]|blockquote|pre|code|table|thead|tbody|tr|td|th|hr|sub|sup)|a href="[^"<>]*"|br \/|hr \/)>/g;
  const rnd = numbers(5);
  const bits = ["<", ">", "</", "<a href=\"", "https://x.org/", "javascript:", "\"", "'", "=", " ", "\n", "/", "img", "src=", "alt=", "a", "b", "p", "br", "svg", "script", "<!--", "-->", "&", "&amp;", "&lt;", "&#", "x;", "<![CDATA[", "]]>", "<!", "<?", "é"];
  const html = E.parse(multi).html;
  for (let i = 0; i < 3000; i++) {
    let h = rnd(3) ? "" : html;
    for (let k = rnd(30); k > 0; k--) { const at = rnd(h.length + 1); h = h.slice(0, at) + bits[rnd(bits.length)] + h.slice(at); }
    const safe = E.safeHtml(h);
    assert.ok(safe.replace(ours, "").indexOf("<") < 0, JSON.stringify(h) + " -> " + safe);
    assert.equal(E.safeHtml(safe), safe, JSON.stringify(h));
  }
  // As words: any <br> a line break, a "<" that's no tag kept.
  assert.equal(E.htmlText("a<br class=\"x\">b < c"), "a\nb < c");
  // Each of these, 400 KB (the most kept), took from seconds to minutes.
  for (const bomb of ["<!--", "<form", "<a", "<![CDATA[", "<html", "<!doctype", "<", "<style", "<a href=\"x\" "]) {
    const h = bomb.repeat(E.MAX_HTML / bomb.length);
    quick(bomb + " over and over", () => { E.safeHtml(h); E.htmlText(h); });
  }
});

console.log("email: " + passed + " checks passed");
