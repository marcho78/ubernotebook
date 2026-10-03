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

console.log("email: " + passed + " checks passed");
