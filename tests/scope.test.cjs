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

check("a picture Grok made: from its own pictures for this conversation, and only a picture", () => {
  const pics = "/home/me/.grok/sessions/%2Frun%2Fuser%2F1000%2Fuber-notebook-agent%2Fc-1";
  const g = () => ({ agent: "Grok", dir: dir, pictures: [pics], frozen: false });
  const img = pics + "/01a1/images/1.jpg";
  assert.ok(ok("attach", [A, img], g()), "attached");
  assert.ok(ok("addGallery", [A, img + "|" + dir + "/b.png", "2"], g()), "in a gallery, with one of its folder's");
  assert.ok(ok("gallery", [A, "b1", "add", img, ""], g()));
  assert.equal(Scope.within(g(), img), pics, "copied from there, through no link");
  assert.equal(Scope.within(g(), dir + "/b.png"), dir);
  assert.equal(Scope.within(g(), "/home/me/b.png"), "");
  // Only a picture; only that folder; only for the commands that take pictures.
  assert.ok(!ok("attach", [A, pics + "/01a1/notes.pdf"], g()), "not another kind of file");
  assert.ok(!ok("attach", [A, pics + "/01a1/x.eml"], g()));
  assert.ok(!ok("append", [A, pics + "/01a1/a.md"], g()), "not Markdown from there");
  assert.ok(!ok("attach", [A, pics + "/../c-2/x/images/1.jpg"], g()), "not another conversation's");
  assert.ok(!ok("attach", [A, "/home/me/.grok/sessions/%2Frun%2Fuser%2F1000%2Fuber-notebook-agent%2Fc-2/s/images/1.jpg"], g()));
  assert.ok(!ok("attach", [A, pics + "x/s/images/1.jpg"], g()), "not a folder whose name starts the same");
  assert.ok(!ok("attach", [A, img], scope()), "an agent with no folder of pictures: its own folder only");
  // Refused: what to do instead.
  assert.match(Scope.check(g(), "attach", [A, "/home/me/x.png"]), /save or copy the file there and give that path; a picture you made yourself is taken from .*c-1 too/);
  assert.match(Scope.check(scope(), "attach", [A, "/home/me/x.png"]), /save or copy the file there and give that path$/);
});

check("a file from outside its folders: asked about, then taken once you've said yes", () => {
  const s = scope();
  assert.equal(JSON.stringify(Scope.outsideFiles(s, "attach", [A, "/usr/share/pixmaps/a.png"])), JSON.stringify(["/usr/share/pixmaps/a.png"]));
  assert.equal(JSON.stringify(Scope.outsideFiles(s, "addGallery", [A, dir + "/a.png|/home/me/b.png|/home/me/b.png", "2"])), JSON.stringify(["/home/me/b.png"]), "only those outside, each once");
  assert.equal(Scope.outsideFiles(s, "attach", [A, dir + "/a.png"]).length, 0, "none outside");
  assert.equal(Scope.outsideFiles(s, "attach", [A, "relative.png"]), null, "one that can't be asked about: refused");
  assert.equal(Scope.outsideFiles(s, "attach", [A, "/home/me/../x.png"]), null);
  assert.equal(Scope.outsideFiles(s, "read", [A]).length, 0, "a command that takes no file");
  const yes = Scope.withApproved(s, ["/usr/share/pixmaps/a.png"]);
  assert.equal(s.approved, undefined, "the scope itself as it was");
  assert.equal(Scope.check(yes, "attach", [A, "/usr/share/pixmaps/a.png"]), "", "said yes to: taken");
  assert.equal(Scope.within(yes, "/usr/share/pixmaps/a.png"), "/usr/share/pixmaps", "from its folder, the file through no link");
  assert.ok(Scope.check(yes, "attach", [A, "/usr/share/pixmaps/b.png"]) !== "", "not another file there");
  assert.equal(Scope.check(yes, "append", [A, "/usr/share/pixmaps/a.png"]), "", "any command that takes it");
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
