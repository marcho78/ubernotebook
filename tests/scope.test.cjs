// Checks what an agent working in the panel may do through Uber Notebook's
// commands while it works (Scope.js).
// Usage (from the plugin directory): node tests/scope.test.cjs

const assert = require("node:assert/strict");
const { load } = require("./load.cjs");

const Scope = load("Scope.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const A = "11111111-1111-4111-8111-111111111111"; // the page it was asked about
const Other = "44444444-4444-4444-8444-444444444444"; // any other page
const dir = "/run/user/1000/uber-notebook-agent";
const scope = () => ({ agent: "Claude Code", dir: dir, frozen: false });
const ok = (cmd, args, s) => Scope.check(s || scope(), cmd, args) === "";

check("no agent working: everything as always", () => {
  assert.equal(Scope.check(null, "set", ["paper", "grid"]), "");
  assert.equal(Scope.check(null, "restoreBackup", ["/x.tar.gz", "true"]), "");
});

check("reading: anything", () => {
  for (const cmd of ["list", "find", "read", "blocks", "contacts", "events", "templates", "history", "readNotebook"]) assert.ok(ok(cmd, [Other]), cmd);
});

check("your notes: read and changed, whichever page", () => {
  assert.ok(ok("append", [Other, dir + "/more.md"]));
  assert.ok(ok("trash", [Other]));
  assert.ok(ok("rename", [Other, "New title"]));
  assert.ok(ok("move", [Other, A]));
  assert.ok(ok("add", ["Plan", dir + "/plan.md"]));
  assert.ok(ok("addTo", [Other, "Plan", dir + "/plan.md"]));
  assert.ok(ok("bookmark", [Other, "https://e.org"]));
  // People, the calendar, templates, tags, notebooks' pages.
  assert.ok(ok("addContact", ["Sam", "", "sam@e.org"]));
  assert.ok(ok("removeContact", ["c1"]));
  assert.ok(ok("addEvent", ["Lunch tomorrow", ""]));
  assert.ok(ok("removeTag", ["work"]));
  assert.ok(ok("addTemplate", ["T", dir + "/t.md", ""]));
  assert.ok(ok("addToNotebook", ["nb", dir + "/x.md"]));
  assert.ok(ok("importContacts", [dir + "/people.vcf"]));
});

check("files: only from its own folder", () => {
  assert.match(Scope.check(scope(), "append", [A, "/tmp/x.md"]), /only from its own folder \(\/run\/user\/1000\/uber-notebook-agent\)/);
  assert.ok(!ok("append", [A, dir + "/../../../home/me/.ssh/id_rsa"]), "nothing that leaves it");
  assert.ok(!ok("append", [A, dir + "x/a.md"]), "not a folder whose name starts the same");
  assert.ok(!ok("importCalendar", ["/home/me/cal.ics"]));
  assert.ok(!ok("addGallery", [A, dir + "/a.png|/home/me/b.png", "2"]), "every one of a list");
  assert.ok(ok("addGallery", [A, dir + "/a.png\n" + dir + "/b.png", "2"]));
  assert.ok(ok("gallery", [A, "b1", "remove", "/anything", ""]), "a gallery's files only when it adds them");
  assert.ok(!ok("gallery", [A, "b1", "add", "/home/me/c.png", ""]));
});

check("Uber Notebook itself: not while it works", () => {
  for (const [cmd, args] of [["set", ["paper", "grid"]], ["mirror", []], ["profile", ["Work"]], ["addProfile", ["Work", ""]],
    ["renameProfile", ["Work", "Job"]], ["profileFolder", ["Work", "/x"]], ["removeProfile", ["Work"]], ["demo", []], ["restartDemo", []],
    ["backup", ["all"]], ["restoreBackup", ["/x.tar.gz", "true"]], ["installUpdate", []], ["someNewCommand", [A]]]) {
    assert.match(Scope.check(scope(), cmd, args), /^not while Claude Code is working.*not Uber Notebook's settings, profiles or backups/, cmd);
  }
});

check("by who calls: yours as always, the panel's agent's by its rules, and none when no agent works there", () => {
  const s = scope();
  assert.equal(Scope.forCaller(false, s, "set", ["paper", "grid"]), "", "yours (a script, a terminal's agent): as always, an agent working or not");
  assert.equal(Scope.forCaller(false, s, "append", [A, "/tmp/x.md"]), "", "files from anywhere");
  assert.match(Scope.forCaller(true, s, "set", ["paper", "grid"]), /not Uber Notebook's settings/);
  assert.equal(Scope.forCaller(true, s, "append", [A, dir + "/a.md"]), "");
  assert.match(Scope.forCaller(true, null, "read", [A]), /no agent is working in Uber Notebook's panel/, "the panel's name, none working: nothing");
  assert.ok(!/omarchy-shell uber-notebook\b(?!-)/.test(Scope.forCaller(true, null, "read", [A])), "and it doesn't point an agent at yours");
});

check("stopping: nothing changes, reading goes on", () => {
  const s = scope();
  s.frozen = true;
  assert.match(Scope.check(s, "append", [A, dir + "/a.md"]), /being stopped/);
  assert.match(Scope.check(s, "add", ["Plan", dir + "/plan.md"]), /being stopped/);
  assert.ok(ok("read", [A], s));
});

console.log(`scope: ${passed} checks passed`);
