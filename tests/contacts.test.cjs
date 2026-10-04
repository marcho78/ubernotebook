// People in Pages (Contacts.js): kept and cleaned; vCard (2.1 with
// quoted-printable, 3.0 folded, 4.0 with tel: uris; one card or many) and
// Google's and Outlook's CSV read; an import matching people already there;
// vCard written back and read again; found by name, company, email or number.
const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const K = load("Contacts.js");

let passed = 0;
function check(name, fn) { fn(); passed++; }

check("kept, cleaned", () => {
  const book = plain(K.clean({ contacts: [
    { id: "a1", name: "  Sam   Rivera ", phones: [{ label: "CELL", value: "+1 (555) 123-4567" }, { value: "555 123 4567" }, { value: "call me" }], emails: [{ label: "WORK", value: "Sam@Acme.COM" }, { value: "nope" }], birthday: "1990-04-12", website: "www.sam.dev" },
    { id: "a1", name: "Twice" },
    { id: "bad id!", name: "New id" },
    { name: "" },
    "junk"
  ] }));
  assert.equal(book.contacts.length, 2);
  const sam = book.contacts[0];
  assert.deepEqual([sam.name, sam.phones, sam.emails, sam.birthday, sam.website], ["Sam Rivera", [{ label: "mobile", value: "+1 (555) 123-4567" }], [{ label: "work", value: "sam@acme.com" }], "1990-04-12", "https://www.sam.dev"]);
  assert.notEqual(book.contacts[1].id, "bad id!");
  assert.equal(K.cleanPhone("0161 496 0000 ext. 204"), "0161 496 0000 ext. 204");
  assert.equal(K.cleanPhone("2026-10-02"), "2026-10-02", "(a number's shape: kept if typed as one)");
  assert.equal(K.cleanEmail("a@b"), "");
  assert.equal(K.cleanBirthday("--04-12"), "--04-12", "a birthday without a year");
  assert.deepEqual([K.initials({ name: "Sam Rivera", emails: [], phones: [] }), K.initials({ name: "", emails: [{ value: "ana@x.org" }], phones: [] })], ["SR", "A"]);
  assert.equal(K.subtitle(sam), "+1 (555) 123-4567");
});

check("vCard read: 3.0 folded, 2.1 quoted-printable, 4.0 uris, many in one file", () => {
  const v3 = "BEGIN:VCARD\r\nVERSION:3.0\r\nN:Rivera;Sam;;;\r\nFN:Sam Rivera\r\nORG:Acme Inc.;Design\r\nTITLE:Designer\r\nTEL;TYPE=CELL,VOICE:+1 555 123 4567\r\nTEL;TYPE=WORK:+1 555 000 1111\r\nEMAIL;TYPE=INTERNET,HOME:sam@home.org\r\nitem1.EMAIL;TYPE=INTERNET:sam@acme.com\r\nADR;TYPE=HOME:;;1 Main St;Springfield;IL;62701;USA\r\nBDAY:1990-04-12\r\nNOTE:Met at the launch\\, loves maps\\nSecond line\r\nPHOTO;ENCODING=b;TYPE=JPEG:/9j/4AAQSkZJRg\r\n AAQSkZJRgABAQAAAQABAAD\r\nEND:VCARD\r\n"
    + "BEGIN:VCARD\nVERSION:2.1\nN;CHARSET=UTF-8;ENCODING=QUOTED-PRINTABLE:M=C3=BCller;J=C3=BCrgen;;;\nTEL;CELL:+49 30 1234567\nEND:VCARD\n"
    + "BEGIN:VCARD\nVERSION:4.0\nFN:Ana Lopez\nTEL;VALUE=uri;TYPE=\"voice,home\":tel:+34-91-555-0101\nEMAIL:ana@x.org\nURL:https://ana.example.com\nEND:VCARD\n"
    + "BEGIN:VCARD\nVERSION:3.0\nFN:\nEND:VCARD\n";
  const people = plain(K.fromVcard(v3));
  assert.equal(people.length, 3, "the empty card left out");
  const [sam, jurgen, ana] = people;
  assert.deepEqual([sam.name, sam.company, sam.title, sam.birthday, sam.address], ["Sam Rivera", "Acme Inc.", "Designer", "1990-04-12", "1 Main St, Springfield, IL, 62701, USA"]);
  assert.deepEqual(sam.phones, [{ label: "mobile", value: "+1 555 123 4567" }, { label: "work", value: "+1 555 000 1111" }]);
  assert.deepEqual(sam.emails.map((e) => [e.label, e.value]), [["home", "sam@home.org"], ["other", "sam@acme.com"]]);
  assert.equal(sam.notes, "Met at the launch, loves maps\nSecond line");
  assert.deepEqual([jurgen.name, jurgen.phones[0].label], ["Jürgen Müller", "mobile"]);
  assert.deepEqual([ana.name, ana.phones[0].value, ana.phones[0].label, ana.website], ["Ana Lopez", "+34-91-555-0101", "home", "https://ana.example.com"]);
});

check("vCard written and read back", () => {
  let book = K.make();
  book = K.withContact(book, { id: "p1", name: "Sam Rivera", company: "Acme; Inc", title: "Designer", phones: [{ label: "mobile", value: "+1 555 123 4567" }], emails: [{ label: "work", value: "sam@acme.com" }], birthday: "--04-12", address: "1 Main St, Springfield", notes: "Line one\nline two, with a comma; and a very long note that goes on past seventy-five characters so it folds" }, new Date("2026-10-02T12:00:00Z"));
  const vcf = K.toVcard(book);
  assert.ok(vcf.split("\r\n").every((l) => l.length <= 75), "folded at 75");
  const back = plain(K.fromVcard(vcf))[0];
  const orig = plain(book.contacts[0]);
  for (const f of ["name", "company", "title", "phones", "emails", "birthday", "notes"]) assert.deepEqual(back[f], orig[f], f);
  assert.equal(orig.created, "2026-10-02T12:00:00.000Z");
});

check("CSV: Google's and Outlook's", () => {
  const google = "Name,Given Name,Family Name,Birthday,Notes,Organization 1 - Name,Organization 1 - Title,E-mail 1 - Type,E-mail 1 - Value,Phone 1 - Type,Phone 1 - Value,Phone 2 - Type,Phone 2 - Value\n"
    + "Sam Rivera,Sam,Rivera,1990-04-12,\"Met at the launch, \"\"the\"\" one\",Acme,Designer,* Work,sam@acme.com ::: sam@home.org,Mobile,+1 555 123 4567,Work,+1 555 000 1111\n";
  const g = plain(K.fromCsv(google));
  assert.equal(g.length, 1);
  assert.deepEqual([g[0].name, g[0].company, g[0].title, g[0].notes, g[0].emails.length, g[0].phones.map((p) => p.label)], ["Sam Rivera", "Acme", "Designer", "Met at the launch, \"the\" one", 2, ["mobile", "work"]]);
  const newer = "First Name,Last Name,Organization Name,Organization Title,E-mail 1 - Label,E-mail 1 - Value,Phone 1 - Label,Phone 1 - Value\nAna,Lopez,Mapas,CTO,Home,ana@x.org,Mobile,+34 91 555 0101\n";
  const n = plain(K.fromCsv(newer))[0];
  assert.deepEqual([n.name, n.company, n.title, n.emails[0].label, n.phones[0].label], ["Ana Lopez", "Mapas", "CTO", "home", "mobile"]);
  const outlook = "First Name,Middle Name,Last Name,Title,Company,Job Title,E-mail Address,E-mail 2 Address,Mobile Phone,Business Phone,Business Fax,Home Address\r\nJane,Q,Doe,Ms.,Contoso,Manager,jane@contoso.com,,555-0100,555-0101,555-0199,\"2 Oak Ave\r\nSeattle\"\r\n";
  const o = plain(K.fromCsv(outlook))[0];
  assert.deepEqual([o.name, o.company, o.title, o.emails.map((e) => e.value), o.phones.map((p) => p.label + " " + p.value)], ["Jane Q Doe", "Contoso", "Manager", ["jane@contoso.com"], ["mobile 555-0100", "work 555-0101"]], "not the fax");
  assert.equal(o.address, "2 Oak Ave Seattle");
  assert.deepEqual(plain(K.fromFile("x.txt", "hello")), []);
  assert.equal(plain(K.fromFile("contacts.csv", "Name,Email\nBo,bo@x.org\n"))[0].emails[0].value, "bo@x.org");
});

check("an import matches who's there; found by what's typed", () => {
  let book = K.withContact(K.make(), { id: "p1", name: "Sam Rivera", phones: [{ label: "mobile", value: "+1 (555) 123-4567" }], emails: [] });
  const r = K.merge(book, [
    { name: "Samuel R.", company: "Acme", phones: [{ value: "555.123.4567" }], emails: [{ value: "sam@acme.com" }] },
    { name: "Ana Lopez", emails: [{ value: "ana@x.org" }] },
    { name: "Ana Lopez", emails: [{ value: "ana@x.org" }], phones: [{ value: "+34 91 555 0101" }] }
  ]);
  assert.deepEqual([r.added, r.updated], [1, 2]);
  const sam = plain(K.byId(r.book, "p1"));
  assert.deepEqual([sam.name, sam.company, sam.phones.length, sam.emails[0].value], ["Sam Rivera", "Acme", 1, "sam@acme.com"], "the same number written another way: one");
  assert.equal(r.book.contacts.length, 2);
  assert.equal(K.merge(r.book, [{ name: "Ana Lopez", emails: [{ value: "ANA@x.org" }] }]).updated, 0, "nothing new: unchanged");
  const book2 = r.book;
  assert.deepEqual(plain(K.find(book2, "ana")).map((c) => c.name), ["Ana Lopez"]);
  assert.deepEqual(plain(K.find(book2, "acme")).map((c) => c.name), ["Sam Rivera"]);
  assert.deepEqual(plain(K.find(book2, "5551234")).map((c) => c.name), ["Sam Rivera"], "by digits");
  assert.deepEqual(plain(K.find(book2, "")).map((c) => c.name), ["Ana Lopez", "Sam Rivera"], "A to Z");
  assert.equal(K.byEmail(book2, "Sam@Acme.com").id, "p1");
  assert.equal(K.idOf(K.href("p1")), "p1");
  assert.equal(K.idOf("uber-notebook://page/x"), "");
  assert.equal(K.without(book2, "p1").contacts.length, 1);
  assert.equal(K.toMarkdown(sam), "**Sam Rivera** · Acme\n- ☎ +1 (555) 123-4567 (mobile)\n- ✉ [sam@acme.com](mailto:sam@acme.com)");
});

check("a birthday as it's said", () => {
  const now = new Date(2026, 9, 2, 15, 0);
  assert.deepEqual(plain(K.birthdayInfo({ birthday: "1990-04-12" }, now)), { date: "12 April 1990", next: "in 192 days", turns: 37 });
  assert.deepEqual(plain(K.birthdayInfo({ birthday: "--10-02" }, now)), { date: "2 October", next: "today", turns: 0 });
  assert.equal(K.birthdayInfo({ birthday: "1990-10-03" }, now).next, "tomorrow");
  assert.equal(K.birthdayInfo({ birthday: "" }, now), null);
});


check("a big import: matched by lookup, in time", () => {
  const people = Array.from({ length: 20000 }, (_, i) => ({ name: "P" + i, emails: [{ value: "p" + i + "@x.org" }], phones: [{ value: "+1 555 " + String(1000000 + i) }] }));
  const t = Date.now();
  const r = K.merge(K.make(), people, new Date());
  const again = K.merge(r.book, people.map((p) => ({ name: p.name, phones: p.phones })), new Date());
  const ms = Date.now() - t;
  assert.equal(r.added, 20000);
  assert.equal(again.added, 0, "each found again by number");
  assert.equal(again.updated, 0);
  assert.ok(ms < 8000, ms + " ms");
  // Notes kept, however many cards bring one: as long as a person's notes can be.
  const notes = K.merge(K.make(), Array.from({ length: 50 }, (_, i) => ({ name: "Sam", emails: [{ value: "sam@x.org" }], notes: "note " + i + " " + "x".repeat(200) })), new Date());
  assert.equal(notes.book.contacts.length, 1);
  assert.ok(notes.book.contacts[0].notes.length <= 4000);
});
console.log("contacts: " + passed + " checks passed");
