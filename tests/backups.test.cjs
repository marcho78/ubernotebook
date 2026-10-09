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

// The archive helper (bin/uber-notebook-files).
function helper(args) {
  const r = spawnSync("/usr/bin/python3", ["-I", "-S", path.join(__dirname, "..", "bin", "uber-notebook-files")].concat(args), { encoding: "utf8" });
  return { code: r.status, out: r.stdout, err: r.stderr };
}
const sha256 = (file) => require("node:crypto").createHash("sha256").update(fs.readFileSync(file)).digest("hex");
const MAXB = String(1024 * 1024 * 1024);
const MAXF = "100000";

function run(script, args, input) {
  const r = spawnSync("/usr/bin/bash", ["-c", script, "uber-notebook-test"].concat(args), { encoding: "utf8", input: input === undefined ? "" : input });
  return { code: r.status, out: r.stdout, err: r.stderr };
}

check("names: made by you, or automatic", () => {
  const d = new Date(2026, 9, 3, 1, 30);
  assert.deepEqual(plain(B.fileName("Personal", d, false)), { stem: "Uber Notebook Personal 2026-10-03 0130", suffix: ".tar.gz" });
  assert.deepEqual(plain(B.fileName("a/b:c", d, false)), { stem: "Uber Notebook a b c 2026-10-03 0130", suffix: ".tar.gz" }, "no slashes");
  assert.deepEqual(plain(B.fileName("", d, false)).stem, "Uber Notebook backup 2026-10-03 0130");
  assert.deepEqual(plain(B.fileName("x", d, true)), { stem: "Uber Notebook 2026-10-03 0130", suffix: " (automatic).tar.gz" });
  assert.ok(B.isAutomatic("Uber Notebook 2026-10-03 0130 (automatic).tar.gz"));
  assert.ok(B.isAutomatic("Uber Notebook 2026-10-03 0130 2 (automatic).tar.gz"), "two in a minute");
  assert.ok(!B.isAutomatic("Uber Notebook automatic 2026-10-03 0130.tar.gz"), "a profile called automatic: yours");
  assert.ok(!B.isAutomatic("Uber Notebook Personal 2026-10-03 0130.tar.gz"));
  assert.ok(!B.isAutomatic("Uber Notebook (automatic) 2026-10-03 0130 (automatic).tar.gz"), "a name like one: yours");
});

check("what a backup says it holds", () => {
  const m = plain(B.manifest([{ name: "Personal", saved: { inbox: "abc-1", lastPage: "NOT OK", mirror: true } }, { name: "Demo", demo: true }], "1.0.0", new Date("2026-10-03T01:30:00Z")));
  assert.deepEqual(m, { app: "uber-notebook", format: 1, version: "1.0.0", created: "2026-10-03T01:30:00.000Z", profiles: [
    { dir: "p1", name: "Personal", demo: false, saved: { inbox: "abc-1" } },
    { dir: "p2", name: "Demo", demo: true, saved: {} }
  ] });
  assert.deepEqual(plain(B.readManifest(JSON.stringify(m))).profiles.map((p) => p.dir + ":" + p.name), ["p1:Personal", "p2:Demo"]);
  assert.equal(B.readManifest("nope"), null);
  assert.equal(B.readManifest(JSON.stringify({ ...m, app: "other" })), null, "another app's");
  assert.equal(B.readManifest(JSON.stringify({ ...m, format: 9 })), null, "a newer kind than this Uber Notebook reads");
  assert.equal(B.readManifest(JSON.stringify({ ...m, profiles: [{ dir: "../x", name: "x" }] })), null, "a folder that isn't one of its own");
  assert.equal(B.readManifest(JSON.stringify({ ...m, profiles: [{ dir: "p1", name: "a" }, { dir: "p1", name: "b" }] })), null, "twice");
  assert.equal(B.readManifest(JSON.stringify({ ...m, profiles: [] })), null);
  assert.equal(plain(B.readManifest(JSON.stringify({ ...m, profiles: [{ dir: "p1", name: " \n " }] }))).profiles[0].name, "Restored");
});

check("the list, when one's due, which are cleared out", () => {
  const out = "1759455000.5\t2048\tUber Notebook 2026-10-03 0130 (automatic).tar.gz\n1759368600\t1024\tUber Notebook 2026-10-02 0130 (automatic).tar.gz\n1759460000\t99\tUber Notebook Personal 2026-10-03 0300.tar.gz\nnot a line\n1759282200\t5\tUber Notebook 2026-10-01 0130 (automatic).tar.gz\n";
  const list = plain(B.listed(out, "/b/"));
  assert.deepEqual(list.map((b) => b.name), ["Uber Notebook Personal 2026-10-03 0300.tar.gz", "Uber Notebook 2026-10-03 0130 (automatic).tar.gz", "Uber Notebook 2026-10-02 0130 (automatic).tar.gz", "Uber Notebook 2026-10-01 0130 (automatic).tar.gz"], "newest first");
  assert.equal(list[0].path, "/b/Uber Notebook Personal 2026-10-03 0300.tar.gz");
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
  assert.deepEqual(plain(B.toPrune(list, 2)).map((b) => b.name), ["Uber Notebook 2026-10-01 0130 (automatic).tar.gz"], "only automatic ones, the oldest");
  assert.deepEqual(plain(B.toPrune(list, 10)), []);
  assert.equal(B.toPrune(list, 0).length, 2, "keeps one at least");
});

check("names and folders for what's put back", () => {
  assert.equal(B.restoredName(["Work"], "Personal"), "Personal");
  assert.equal(B.restoredName(["Personal"], "personal"), "personal (restored)");
  assert.equal(B.restoredName(["Personal", "Personal (restored)"], "Personal"), "Personal (restored 2)");
  assert.equal(B.restoredName([], ""), "Restored");
  assert.equal(B.restoreFolder("Work/Clients"), "~/Documents/Uber Notebook Work Clients (restored)");
  assert.equal(B.inside("/n/Backups", "/n"), "Backups");
  assert.equal(B.inside("/n", "/n/"), ".");
  assert.equal(B.inside("/notes-backups", "/notes"), "", "beside it, not in it");
  assert.equal(B.inside("/b", "/n"), "");
  assert.equal(B.sizeLabel(512), "512 B");
  assert.equal(B.sizeLabel(3 * 1024 * 1024 + 300000), "3.3 MB");
  assert.equal(B.sizeLabel(49 * 1024 * 1024), "49 MB");
});

// ---- the scripts, with the real tar ----

const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "uber-notebook-backups-"));
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
    // (A backups folder from before, open to others: made yours alone.)
    fs.mkdirSync(backups, { recursive: true });
    fs.chmodSync(backups, 0o755);
    const r = run(B.BACKUP_SCRIPT, [backups, n.stem, n.suffix, personal, "p1", B.inside(backups, personal), work, "p2", ""], m);
    assert.equal(r.code, 0, r.err);
    const [size, at] = r.out.trim().split("\n");
    file = at;
    assert.equal(fs.statSync(backups).mode & 0o777, 0o700, "the backups' folder, yours alone");
    assert.equal(fs.statSync(file).mode & 0o777, 0o600, "the backup, yours alone");
    assert.equal(execFileSync("/usr/bin/tar", ["-xOzf", file, "uber-notebook-backup.json"], { encoding: "utf8" }), m, "its list, from its input");
    assert.equal(path.basename(file), "Uber Notebook All profiles 2026-10-03 0130.tar.gz");
    assert.equal(Number(size), fs.statSync(file).size);
    const names = execFileSync("/usr/bin/tar", ["-tzf", file], { encoding: "utf8" }).split("\n").filter(Boolean).sort();
    assert.ok(names.includes("uber-notebook-backup.json"));
    assert.ok(names.includes("p1/Pages/assets/a b.png"), names.join("\n"));
    assert.ok(names.includes("p1/.trash/old/notebook.json"), "the trash too");
    assert.ok(names.includes("p2/Pages/index.json"));
    assert.ok(!names.some((x) => x.includes("older.tar.gz")), "the backup folder, left out");
    assert.ok(names.every((x) => x === "uber-notebook-backup.json" || /^p[12](\/|$)/.test(x)), names.join("\n"));
    // Twice in a minute: a second file, not the first written over.
    const again = run(B.BACKUP_SCRIPT, [backups, n.stem, n.suffix, work, "p1", ""], m);
    assert.equal(path.basename(again.out.trim().split("\n")[1]), "Uber Notebook All profiles 2026-10-03 0130 2.tar.gz");
    assert.ok(!fs.readdirSync(backups).some((x) => x.includes(".part")), "nothing half-made left");
  });

  check("listed: the folder made yours alone; one that can't be, said", () => {
    const old = fs.mkdtempSync(path.join(tmp, "old-backups-"));
    fs.chmodSync(old, 0o755);
    const r = run(B.LIST_SCRIPT, [old]);
    assert.equal(r.code, 0, r.err);
    assert.ok(!/^open$/m.test(r.out), r.out);
    assert.equal(fs.statSync(old).mode & 0o777, 0o700);
    // (A folder that isn't yours can't be: "open".)
    assert.match(run(B.LIST_SCRIPT, ["/usr/share"]).out, /^open$/m);
  });

  check("listed", () => {
    const list = plain(B.listed(run(B.LIST_SCRIPT, [backups]).out, backups));
    assert.deepEqual(list.map((b) => b.name).sort(), ["Uber Notebook All profiles 2026-10-03 0130 2.tar.gz", "Uber Notebook All profiles 2026-10-03 0130.tar.gz", "older.tar.gz"]);
    assert.equal(run(B.LIST_SCRIPT, [path.join(tmp, "none")]).out, "", "no folder yet: none");
  });

  check("checked, then put back in a new folder", () => {
    const c = plain(B.checked(helper(["inspect-backup", file]).out));
    assert.ok(c.ok, c.problem);
    assert.deepEqual(c.manifest.profiles.map((p) => p.name), ["Personal", "Work"]);
    assert.equal(c.hash, sha256(file), "what it is, to check it's still that when it's put back");
    // Where it goes is taken: beside it, never into it.
    const base = path.join(tmp, "Restored Personal");
    write(path.join(base, "keep.txt"), "mine");
    const r = helper(["restore-backup", file, "p1", base, c.hash, MAXB, MAXF]);
    assert.equal(r.code, 0, r.err);
    const lines = r.out.trim().split("\n");
    const into = lines.pop();
    assert.equal(into, base + " 2");
    assert.deepEqual(lines, ["left-out:0"]);
    assert.equal(fs.readFileSync(path.join(base, "keep.txt"), "utf8"), "mine", "what was there, as it was");
    assert.equal(fs.readFileSync(path.join(into, "Pages", "assets", "a b.png"), "utf8"), "PNG");
    assert.equal(fs.readFileSync(path.join(into, "library.json"), "utf8"), "{\"notebooks\":[]}");
    assert.ok(fs.existsSync(path.join(into, ".trash", "old", "notebook.json")));
    assert.ok(!fs.existsSync(path.join(into, "uber-notebook-backup.json")), "only the profile's own files");
    const w = helper(["restore-backup", file, "p2", path.join(tmp, "Restored Work"), c.hash, MAXB, MAXF]);
    assert.equal(fs.readFileSync(path.join(w.out.trim().split("\n").pop(), "Pages", "index.json"), "utf8"), "{\"work\":true}");
    // Not in it: nothing made.
    const bad = helper(["restore-backup", file, "p7", path.join(tmp, "Nothing"), c.hash, MAXB, MAXF]);
    assert.notEqual(bad.code, 0);
    assert.ok(!fs.existsSync(path.join(tmp, "Nothing")), "the folder it made, taken away again");
    // Changed since it was looked into: nothing put back.
    const copy = path.join(tmp, "changed.tar.gz");
    fs.copyFileSync(file, copy);
    fs.appendFileSync(copy, "x");
    const changed = helper(["restore-backup", copy, "p1", path.join(tmp, "Changed"), c.hash, MAXB, MAXF]);
    assert.notEqual(changed.code, 0);
    assert.match(changed.err, /changed after it was looked at/);
    assert.ok(!fs.existsSync(path.join(tmp, "Changed")));
    // More than its room: stopped, and what it made taken away.
    const small = helper(["restore-backup", file, "p1", path.join(tmp, "Small"), c.hash, "4", MAXF]);
    assert.notEqual(small.code, 0);
    assert.match(small.err, /more than 4 bytes/);
    assert.ok(!fs.existsSync(path.join(tmp, "Small")));
    // What it unpacks to, all of it (the other profiles too), bounded: a
    // backup whose other profile unpacks to megabytes, refused for a small one.
    const big = path.join(tmp, "big");
    write(path.join(big, "uber-notebook-backup.json"), JSON.stringify(B.manifest([{ name: "a" }, { name: "b" }], "1", new Date())));
    write(path.join(big, "p1", "a.json"), "{}");
    write(path.join(big, "p2", "huge.bin"), "x".repeat(3 * 1024 * 1024));
    const bf = path.join(tmp, "big.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", bf, "-C", big, "uber-notebook-backup.json", "p2", "p1"]);
    const bc = plain(B.checked(helper(["inspect-backup", bf]).out));
    const unpacked = helper(["restore-backup", bf, "p1", path.join(tmp, "Unpacked"), bc.hash, "100", "10"]);
    assert.notEqual(unpacked.code, 0);
    assert.match(unpacked.err, /unpacks to more than it may/);
    assert.ok(!fs.existsSync(path.join(tmp, "Unpacked")));
    // Folders count: a file six folders down is seven of its room.
    const deep = path.join(tmp, "deep");
    write(path.join(deep, "uber-notebook-backup.json"), JSON.stringify(B.manifest([{ name: "a" }], "1", new Date())));
    write(path.join(deep, "p1", "a", "b", "c", "d", "e", "f", "x.json"), "{}");
    const df = path.join(tmp, "deep.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", df, "-C", deep, "uber-notebook-backup.json", "p1"]);
    const dc = plain(B.checked(helper(["inspect-backup", df]).out));
    const deepR = helper(["restore-backup", df, "p1", path.join(tmp, "Deep"), dc.hash, MAXB, "5"]);
    assert.notEqual(deepR.code, 0);
    assert.match(deepR.err, /more than 5 files/);
    assert.ok(!fs.existsSync(path.join(tmp, "Deep")));
  });

  check("files that aren't backups, or reach outside, refused", () => {
    write(path.join(tmp, "plain.txt"), "not an archive");
    assert.equal(plain(B.checked(helper(["inspect-backup", path.join(tmp, "plain.txt")]).out)).ok, false);
    assert.equal(plain(B.checked(helper(["inspect-backup", path.join(tmp, "missing.tar.gz")]).out)).ok, false);
    // Another archive: no uber-notebook-backup.json.
    const other = path.join(tmp, "other.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", other, "-C", work, "."]);
    const o = plain(B.checked(helper(["inspect-backup", other]).out));
    assert.equal(o.ok, false);
    assert.ok(/more than/.test(o.problem), o.problem);
    // One with a link in it.
    const linky = path.join(tmp, "linky");
    write(path.join(linky, "uber-notebook-backup.json"), JSON.stringify(B.manifest([{ name: "x" }], "1", new Date())));
    fs.mkdirSync(path.join(linky, "p1"));
    fs.symlinkSync("/etc/passwd", path.join(linky, "p1", "passwd"));
    write(path.join(linky, "p1", "kept.json"), "{}");
    const lf = path.join(tmp, "linky.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", lf, "-C", linky, "uber-notebook-backup.json", "p1"]);
    const l = plain(B.checked(helper(["inspect-backup", lf]).out));
    assert.equal(l.ok, true, "put back, without the link: " + l.problem);
    assert.equal(l.leftOut, true);
    const linked = helper(["restore-backup", lf, "p1", path.join(tmp, "Linky"), l.hash, MAXB, MAXF]);
    assert.equal(linked.code, 0, linked.err);
    assert.deepEqual(linked.out.trim().split("\n"), ["left-out:1", path.join(tmp, "Linky")]);
    assert.deepEqual(fs.readdirSync(path.join(tmp, "Linky")), ["kept.json"], "the link left out, the rest put back");
    // One with a sparse file (its holes would be written out whole): refused.
    const sparse = path.join(tmp, "sparse");
    write(path.join(sparse, "uber-notebook-backup.json"), JSON.stringify(B.manifest([{ name: "x" }], "1", new Date())));
    fs.mkdirSync(path.join(sparse, "p1"));
    execFileSync("/usr/bin/truncate", ["-s", "64M", path.join(sparse, "p1", "holes.bin")]);
    const sf = path.join(tmp, "sparse.tar.gz");
    execFileSync("/usr/bin/tar", ["-S", "-czf", sf, "-C", sparse, "uber-notebook-backup.json", "p1"]);
    assert.ok(fs.statSync(sf).size < 100000, "a small file");
    const sc = plain(B.checked(helper(["inspect-backup", sf]).out));
    assert.equal(sc.ok, false);
    assert.match(sc.problem, /sparse/);
    const forced = helper(["restore-backup", sf, "p1", path.join(tmp, "Sparse"), sha256(sf), MAXB, MAXF]);
    assert.notEqual(forced.code, 0);
    assert.match(forced.err, /a sparse file/);
    assert.ok(!fs.existsSync(path.join(tmp, "Sparse")), "what it made, taken away");
    // One with a name that reaches up (made with Python's tarfile, which writes what it's told).
    const up = path.join(tmp, "up.tar.gz");
    execFileSync("/usr/bin/python3", ["-c", "import tarfile,sys,io\nwith tarfile.open(sys.argv[1], 'w:gz') as t:\n  t.add(sys.argv[2], 'uber-notebook-backup.json')\n  d=b'escaped'\n  i=tarfile.TarInfo('p1/../../escape.txt'); i.size=len(d); t.addfile(i, io.BytesIO(d))", up, path.join(linky, "uber-notebook-backup.json")]);
    assert.ok(execFileSync("/usr/bin/tar", ["-tzf", up], { encoding: "utf8", stdio: ["ignore", "pipe", "ignore"] }).includes("../escape.txt"));
    const u = plain(B.checked(helper(["inspect-backup", up]).out));
    assert.equal(u.ok, false, "reaching up: refused");
    const upRestored = helper(["restore-backup", up, "p1", path.join(tmp, "Up"), sha256(up), MAXB, MAXF]);
    assert.ok(!fs.existsSync(path.join(tmp, "escape.txt")) && !fs.existsSync(path.join(path.dirname(tmp), "escape.txt")), "never out of its folder");
    // A good one with something extra beside the profiles.
    const extra = path.join(tmp, "extra.tar.gz");
    execFileSync("/usr/bin/tar", ["-czf", extra, "-C", linky, "uber-notebook-backup.json", "-C", tmp, "plain.txt"]);
    assert.equal(plain(B.checked(helper(["inspect-backup", extra]).out)).ok, false, "something else in it: refused");
  });
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}

console.log(`backups: ${passed} checks passed`);
