// Checks backups (Backups.js): names, what a backup says it holds, telling
// automatic ones apart, when one's due, which are cleared out, and the
// scripts themselves, run with the real tar on folders in a temporary
// place: a backup made (and the backup folder left out of it), checked,
// put back in a new folder (never over one that's there), and files that
// aren't backups, or reach outside, refused.
// Usage (from the plugin directory): node tests/backups.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawnSync } = require("node:child_process");
const { load, plain } = require("./load.cjs");

const B = load("Backups.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

function run(script, args) {
  const r = spawnSync("/usr/bin/bash", ["-c", script, "omanote-test"].concat(args), { encoding: "utf8" });
  return { code: r.status, out: r.stdout, err: r.stderr };
}

check("names: made by you, or automatic", () => {
  const d = new Date(2026, 9, 3, 1, 30);
  assert.deepEqual(plain(B.fileName("Personal", d, false)), { stem: "Omanote Personal 2026-10-03 0130", suffix: ".tar.gz" });
  assert.deepEqual(plain(B.fileName("a/b:c", d, false)), { stem: "Omanote a b c 2026-10-03 0130", suffix: ".tar.gz" }, "no slashes");
  assert.deepEqual(plain(B.fileName("", d, false)).stem, "Omanote backup 2026-10-03 0130");
  assert.deepEqual(plain(B.fileName("x", d, true)), { stem: "Omanote 2026-10-03 0130", suffix: " (automatic).tar.gz" });
  assert.ok(B.isAutomatic("Omanote 2026-10-03 0130 (automatic).tar.gz"));
  assert.ok(B.isAutomatic("Omanote 2026-10-03 0130 2 (automatic).tar.gz"), "two in a minute");
  assert.ok(!B.isAutomatic("Omanote automatic 2026-10-03 0130.tar.gz"), "a profile called automatic: yours");
  assert.ok(!B.isAutomatic("Omanote Personal 2026-10-03 0130.tar.gz"));
  assert.ok(!B.isAutomatic("Omanote (automatic) 2026-10-03 0130 (automatic).tar.gz"), "a name like one: yours");
});

check("what a backup says it holds", () => {
  const m = plain(B.manifest([{ name: "Personal", saved: { inbox: "abc-1", lastPage: "NOT OK", mirror: true } }, { name: "Demo", demo: true }], "1.0.0", new Date("2026-10-03T01:30:00Z")));
  assert.deepEqual(m, { app: "omanote", format: 1, version: "1.0.0", created: "2026-10-03T01:30:00.000Z", profiles: [
    { dir: "p1", name: "Personal", demo: false, saved: { inbox: "abc-1" } },
    { dir: "p2", name: "Demo", demo: true, saved: {} }
  ] });
  assert.deepEqual(plain(B.readManifest(JSON.stringify(m))).profiles.map((p) => p.dir + ":" + p.name), ["p1:Personal", "p2:Demo"]);
  assert.equal(B.readManifest("nope"), null);
  assert.equal(B.readManifest(JSON.stringify({ ...m, app: "other" })), null, "another app's");
  assert.equal(B.readManifest(JSON.stringify({ ...m, format: 9 })), null, "a newer kind than this Omanote reads");
  assert.equal(B.readManifest(JSON.stringify({ ...m, profiles: [{ dir: "../x", name: "x" }] })), null, "a folder that isn't one of its own");
  assert.equal(B.readManifest(JSON.stringify({ ...m, profiles: [{ dir: "p1", name: "a" }, { dir: "p1", name: "b" }] })), null, "twice");
  assert.equal(B.readManifest(JSON.stringify({ ...m, profiles: [] })), null);
  assert.equal(plain(B.readManifest(JSON.stringify({ ...m, profiles: [{ dir: "p1", name: " \n " }] }))).profiles[0].name, "Restored");
});

check("the list, when one's due, which are cleared out", () => {
  const out = "1759455000.5\t2048\tOmanote 2026-10-03 0130 (automatic).tar.gz\n1759368600\t1024\tOmanote 2026-10-02 0130 (automatic).tar.gz\n1759460000\t99\tOmanote Personal 2026-10-03 0300.tar.gz\nnot a line\n1759282200\t5\tOmanote 2026-10-01 0130 (automatic).tar.gz\n";
  const list = plain(B.listed(out, "/b/"));
  assert.deepEqual(list.map((b) => b.name), ["Omanote Personal 2026-10-03 0300.tar.gz", "Omanote 2026-10-03 0130 (automatic).tar.gz", "Omanote 2026-10-02 0130 (automatic).tar.gz", "Omanote 2026-10-01 0130 (automatic).tar.gz"], "newest first");
  assert.equal(list[0].path, "/b/Omanote Personal 2026-10-03 0300.tar.gz");
  assert.equal(list[1].time, 1759455000500);
  assert.equal(list[0].automatic, false);
  const at = list[1].time;
  assert.equal(B.due(list, "off", at + 1e10), false, "off: never");
  assert.equal(B.due(list, "daily", at + 3600e3), false, "an hour on");
  assert.equal(B.due(list, "daily", at + 24 * 3600e3), true, "a day on");
  assert.equal(B.due(list, "daily", at + 24 * 3600e3 - 5 * 60e3), true, "give or take a few minutes");
  assert.equal(B.due(list, "weekly", at + 3 * 24 * 3600e3), false);
  assert.equal(B.due([], "weekly", at), true, "none yet");
  assert.equal(B.due(list.filter((b) => !b.automatic), "daily", at), true, "only yours: one's due");
  assert.deepEqual(plain(B.toPrune(list, 2)).map((b) => b.name), ["Omanote 2026-10-01 0130 (automatic).tar.gz"], "only automatic ones, the oldest");
  assert.deepEqual(plain(B.toPrune(list, 10)), []);
  assert.equal(B.toPrune(list, 0).length, 2, "keeps one at least");
});

check("names and folders for what's put back", () => {
  assert.equal(B.restoredName(["Work"], "Personal"), "Personal");
  assert.equal(B.restoredName(["Personal"], "personal"), "personal (restored)");
  assert.equal(B.restoredName(["Personal", "Personal (restored)"], "Personal"), "Personal (restored 2)");
  assert.equal(B.restoredName([], ""), "Restored");
  assert.equal(B.restoreFolder("Work/Clients"), "~/Documents/Omanote Work Clients (restored)");
  assert.equal(B.inside("/n/Backups", "/n"), "Backups");
  assert.equal(B.inside("/n", "/n/"), ".");
  assert.equal(B.inside("/notes-backups", "/notes"), "", "beside it, not in it");
  assert.equal(B.inside("/b", "/n"), "");
  assert.equal(B.sizeLabel(512), "512 B");
  assert.equal(B.sizeLabel(3 * 1024 * 1024 + 300000), "3.3 MB");
  assert.equal(B.sizeLabel(49 * 1024 * 1024), "49 MB");
});

// ---- the scripts, with the real tar ----

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "omanote-backups-"));
try {
  const write = (p, text) => { fs.mkdirSync(path.dirname(p), { recursive: true }); fs.writeFileSync(p, text); };
  const personal = path.join(tmp, "Notes Personal");
  const work = path.join(tmp, "Work");
  write(path.join(personal, "library.json"), "{\"notebooks\":[]}");
  write(path.join(personal, "Pages", "index.json"), "{\"pages\":{}}");
  write(path.join(personal, "Pages", "assets", "a b.png"), "PNG");
  write(path.join(personal, ".trash", "old", "notebook.json"), "{}");
  write(path.join(personal, "Backups", "older.tar.gz"), "an older backup, inside the notes folder");
  write(path.join(work, "Pages", "index.json"), "{\"work\":true}");
  const backups = path.join(personal, "Backups");

  check("which folders are there", () => {
    assert.equal(run(B.EXISTS_SCRIPT, [personal, path.join(tmp, "nope"), work]).out, "1\n0\n1\n");
  });

  let file = "";
  check("a backup made", () => {
    const m = JSON.stringify(B.manifest([{ name: "Personal" }, { name: "Work" }], "1.0.0", new Date()));
    const n = B.fileName("All profiles", new Date(2026, 9, 3, 1, 30), false);
    const r = run(B.BACKUP_SCRIPT, [backups, n.stem, n.suffix, m, personal, "p1", B.inside(backups, personal), work, "p2", ""]);
    assert.equal(r.code, 0, r.err);
    const [size, at] = r.out.trim().split("\n");
    file = at;
    assert.equal(path.basename(file), "Omanote All profiles 2026-10-03 0130.tar.gz");
    assert.equal(Number(size), fs.statSync(file).size);
    const names = execFileSync("/usr/bin/tar", ["-tzf", file], { encoding: "utf8" }).split("\n").filter(Boolean).sort();
    assert.ok(names.includes("omanote-backup.json"));
    assert.ok(names.includes("p1/Pages/assets/a b.png"), names.join("\n"));
    assert.ok(names.includes("p1/.trash/old/notebook.json"), "the trash too");
    assert.ok(names.includes("p2/Pages/index.json"));
    assert.ok(!names.some((x) => x.includes("older.tar.gz")), "the backup folder, left out");
    assert.ok(names.every((x) => x === "omanote-backup.json" || /^p[12](\/|$)/.test(x)), names.join("\n"));
    // Twice in a minute: a second file, not the first written over.
    const again = run(B.BACKUP_SCRIPT, [backups, n.stem, n.suffix, m, work, "p1", ""]);
    assert.equal(path.basename(again.out.trim().split("\n")[1]), "Omanote All profiles 2026-10-03 0130 2.tar.gz");
    assert.ok(!fs.readdirSync(backups).some((x) => x.includes(".part")), "nothing half-made left");
  });

  check("listed", () => {
    const list = plain(B.listed(run(B.LIST_SCRIPT, [backups]).out, backups));
    assert.deepEqual(list.map((b) => b.name).sort(), ["Omanote All profiles 2026-10-03 0130 2.tar.gz", "Omanote All profiles 2026-10-03 0130.tar.gz", "older.tar.gz"]);
    assert.equal(run(B.LIST_SCRIPT, [path.join(tmp, "none")]).out, "", "no folder yet: none");
  });

  check("checked, then put back in a new folder", () => {
    const c = plain(B.checked(run(B.CHECK_SCRIPT, [file]).out));
    assert.ok(c.ok, c.problem);
    assert.deepEqual(c.manifest.profiles.map((p) => p.name), ["Personal", "Work"]);
    // Where it goes is taken: beside it, never into it.
    const base = path.join(tmp, "Restored Personal");
    write(path.join(base, "keep.txt"), "mine");
    const r = run(B.RESTORE_SCRIPT, [file, "p1", base]);
    assert.equal(r.code, 0, r.err);
    const into = r.out.trim();
    assert.equal(into, base + " 2");
    assert.equal(fs.readFileSync(path.join(base, "keep.txt"), "utf8"), "mine", "what was there, as it was");
    assert.equal(fs.readFileSync(path.join(into, "Pages", "assets", "a b.png"), "utf8"), "PNG");
    assert.equal(fs.readFileSync(path.join(into, "library.json"), "utf8"), "{\"notebooks\":[]}");
    assert.ok(fs.existsSync(path.join(into, ".trash", "old", "notebook.json")));
    assert.ok(!fs.existsSync(path.join(into, "omanote-backup.json")), "only the profile's own files");
    const w = run(B.RESTORE_SCRIPT, [file, "p2", path.join(tmp, "Restored Work")]);
    assert.equal(fs.readFileSync(path.join(w.out.trim(), "Pages", "index.json"), "utf8"), "{\"work\":true}");
    // Not in it: nothing made.
    const bad = run(B.RESTORE_SCRIPT, [file, "p7", path.join(tmp, "Nothing")]);
    assert.notEqual(bad.code, 0);
    assert.ok(!fs.existsSync(path.join(tmp, "Nothing")), "the folder it made, taken away again");
  });

  check("files that aren't backups, or reach outside, refused", () => {
    write(path.join(tmp, "plain.txt"), "not an archive");
    assert.equal(plain(B.checked(run(B.CHECK_SCRIPT, [path.join(tmp, "plain.txt")]).out)).ok, false);
    assert.equal(plain(B.checked(run(B.CHECK_SCRIPT, [path.join(tmp, "missing.tar.gz")]).out)).ok, false);
    // Another archive: no omanote-backup.json.
    const other = path.join(tmp, "other.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", other, "-C", work, "."]);
    const o = plain(B.checked(run(B.CHECK_SCRIPT, [other]).out));
    assert.equal(o.ok, false);
    assert.ok(/more than/.test(o.problem), o.problem);
    // One with a link in it.
    const linky = path.join(tmp, "linky");
    write(path.join(linky, "omanote-backup.json"), JSON.stringify(B.manifest([{ name: "x" }], "1", new Date())));
    fs.mkdirSync(path.join(linky, "p1"));
    fs.symlinkSync("/etc/passwd", path.join(linky, "p1", "passwd"));
    const lf = path.join(tmp, "linky.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", lf, "-C", linky, "omanote-backup.json", "p1"]);
    const l = plain(B.checked(run(B.CHECK_SCRIPT, [lf]).out));
    assert.equal(l.ok, false);
    assert.ok(/links/.test(l.problem), l.problem);
    // One with a name that reaches up (made with Python's tarfile, which writes what it's told).
    const up = path.join(tmp, "up.tar.gz");
    execFileSync("/usr/bin/python3", ["-c", "import tarfile,sys,io\nwith tarfile.open(sys.argv[1], 'w:gz') as t:\n  t.add(sys.argv[2], 'omanote-backup.json')\n  d=b'escaped'\n  i=tarfile.TarInfo('p1/../../escape.txt'); i.size=len(d); t.addfile(i, io.BytesIO(d))", up, path.join(linky, "omanote-backup.json")]);
    assert.ok(execFileSync("/usr/bin/tar", ["-tzf", up], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).includes("../escape.txt"));
    const u = plain(B.checked(run(B.CHECK_SCRIPT, [up]).out));
    assert.equal(u.ok, false, "reaching up: refused");
    // A good one with something extra beside the profiles.
    const extra = path.join(tmp, "extra.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", extra, "-C", linky, "omanote-backup.json", "-C", tmp, "plain.txt"]);
    assert.equal(plain(B.checked(run(B.CHECK_SCRIPT, [extra]).out)).ok, false, "something else in it: refused");
  });
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}

console.log(`backups: ${passed} checks passed`);
