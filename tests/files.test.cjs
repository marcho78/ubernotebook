// Checks bin/uber-notebook-files, the helper that opens archives (a zip of
// notes to import, a backup to look into and put back), with real files in a
// folder of its own under the system's temp folder.
// Usage (from the plugin directory): node tests/files.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { execFileSync, spawnSync } = require("node:child_process");

const helper = path.join(__dirname, "..", "bin", "uber-notebook-files");
const tmp = fs.mkdtempSync(path.join(os.tmpdir(), "uber-notebook-files-test-"));
let passed = 0;
function check(name, fn) { fn(); passed++; }

function helperRun(args) {
  const r = spawnSync("/usr/bin/python3", ["-I", "-S", helper].concat(args), { encoding: "utf8" });
  return { code: r.status, out: r.stdout, err: r.stderr };
}
// A zip made by Python's zipfile from [{ name, data, link, dir, size }] (`size`:
// that many zero bytes, compressed).
function zip(file, members) {
  execFileSync("/usr/bin/python3", ["-c", `
import json, sys, zipfile
spec = json.loads(sys.argv[2])
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
    for m in spec:
        if m.get("link"):
            i = zipfile.ZipInfo(m["name"]); i.external_attr = (0o120777 << 16); z.writestr(i, m["link"])
        elif m.get("file"):
            z.write(m["file"], m["name"])
        elif m.get("size"):
            with z.open(m["name"], "w", force_zip64=True) as w:
                for _ in range(m["size"] // 1048576): w.write(bytes(1048576))
        else:
            z.writestr(m["name"], m.get("data", ""))
`, file, JSON.stringify(members)]);
  return file;
}
function folder(name) { const d = path.join(tmp, name); fs.mkdirSync(d); return d; }
function tree(dir) {
  const out = [];
  (function walk(d, rel) {
    for (const n of fs.readdirSync(d).sort()) {
      const p = path.join(d, n);
      const st = fs.lstatSync(p);
      if (st.isSymbolicLink()) out.push(rel + n + " -> link");
      else if (st.isDirectory()) { out.push(rel + n + "/"); walk(p, rel + n + "/"); }
      else out.push(rel + n);
    }
  })(dir, "");
  return out;
}

try {
  check("a zip of notes: its folders and files, nothing else", () => {
    const z = zip(path.join(tmp, "notes.zip"), [{ name: "Notes/" , dir: true }, { name: "Notes/Plans.md", data: "# Plans" }, { name: "Notes/img/a.png", data: "PNG" }]);
    const d = folder("out1");
    const r = helperRun(["unzip", z, d, "1000000", "100"]);
    assert.equal(r.code, 0, r.err);
    const j = JSON.parse(r.out);
    assert.equal(j.ok, true);
    assert.equal(j.files, 2);
    assert.deepEqual(tree(d), ["Notes/", "Notes/Plans.md", "Notes/img/", "Notes/img/a.png"]);
    assert.equal(fs.readFileSync(path.join(d, "Notes/Plans.md"), "utf8"), "# Plans");
  });

  check("names that would land elsewhere, links, odd characters: left out", () => {
    const z = zip(path.join(tmp, "evil.zip"), [
      { name: "../escape.md", data: "x" }, { name: "/abs.md", data: "x" }, { name: "a/../../b.md", data: "x" },
      { name: "ok.md", data: "fine" }, { name: "link", link: "/etc" }, { name: "line\n/home/me/private.md", data: "x" }
    ]);
    const d = folder("out2");
    const r = helperRun(["unzip", z, d, "1000000", "100"]);
    const j = JSON.parse(r.out);
    assert.equal(j.ok, true);
    assert.deepEqual(tree(d), ["ok.md"]);
    assert.equal(j.skipped.names, 4);
    assert.equal(j.skipped.links, 1);
    assert.ok(!fs.existsSync(path.join(tmp, "escape.md")) && !fs.existsSync(path.join(tmp, "b.md")));
  });

  check("a link in one part, and a file through it in the next: never outside", () => {
    // The export in parts: the first makes notes/link (to a folder elsewhere),
    // the zip in it writes notes/link/evil.txt.
    const target = folder("target");
    const inner = zip(path.join(tmp, "part2.zip"), [{ name: "notes/link/evil.txt", data: "pwned" }]);
    const outer = zip(path.join(tmp, "export.zip"), [{ name: "notes/link", link: target }, { name: "part2.zip", file: inner }]);
    const d = folder("out3");
    const j = JSON.parse(helperRun(["unzip", outer, d, "1000000", "100"]).out);
    assert.equal(j.ok, true);
    assert.deepEqual(fs.readdirSync(target), [], "nothing written where the link pointed");
    assert.deepEqual(tree(d), ["notes/", "notes/link/", "notes/link/evil.txt"], "a folder of its own, the part gone");
  });

  check("more than its room: stopped, and said", () => {
    const bomb = zip(path.join(tmp, "bomb.zip"), [{ name: "big.bin", size: 8 * 1048576 }]);
    assert.ok(fs.statSync(bomb).size < 100000, "small, but big inside");
    const d = folder("out4");
    const r = helperRun(["unzip", bomb, d, String(4 * 1048576), "100"]);
    const j = JSON.parse(r.out);
    assert.equal(j.ok, false);
    assert.match(j.error, /more than 4194304 bytes/);
    assert.deepEqual(tree(d), [], "the part written taken away");
    const many = zip(path.join(tmp, "many.zip"), Array.from({ length: 30 }, (_, i) => ({ name: "n" + i + ".md", data: "x" })));
    const j2 = JSON.parse(helperRun(["unzip", many, folder("out5"), "1000000", "20"]).out);
    assert.equal(j2.ok, false);
    assert.match(j2.error, /more than 20 files/);
  });

  check("not a zip, a link to one, a folder: refused", () => {
    fs.writeFileSync(path.join(tmp, "plain.zip"), "not a zip");
    assert.equal(JSON.parse(helperRun(["unzip", path.join(tmp, "plain.zip"), folder("out6"), "1000", "10"]).out).ok, false);
    fs.symlinkSync(path.join(tmp, "notes.zip"), path.join(tmp, "linked.zip"));
    assert.equal(JSON.parse(helperRun(["unzip", path.join(tmp, "linked.zip"), folder("out7"), "1000000", "10"]).out).ok, false, "a link isn't opened");
    assert.equal(JSON.parse(helperRun(["unzip", tmp, folder("out8"), "1000000", "10"]).out).ok, false);
    fs.symlinkSync(folder("elsewhere"), path.join(tmp, "out9"));
    assert.equal(JSON.parse(helperRun(["unzip", path.join(tmp, "notes.zip"), path.join(tmp, "out9"), "1000000", "10"]).out).ok, false, "nor a linked folder to write in");
  });
  check("a file of its own: made only where nothing is, taken out only as it was made", () => {
    const d = folder("owned");
    const text = "[Desktop Entry]\nName=Uber Notebook\n";
    const at = path.join(d, "entry.desktop");
    assert.equal(helperRun(["create-owned", at, text]).out.trim(), "made");
    assert.equal(fs.readFileSync(at, "utf8"), text);
    assert.equal(helperRun(["create-owned", at, text]).out.trim(), "same");
    // Yours, at that name: never written over, never taken out.
    const yours = path.join(d, "yours.desktop");
    fs.writeFileSync(yours, "mine");
    assert.equal(helperRun(["create-owned", yours, text]).out.trim(), "taken");
    assert.equal(fs.readFileSync(yours, "utf8"), "mine");
    assert.equal(helperRun(["remove-owned", yours, text]).out.trim(), "kept");
    assert.ok(fs.existsSync(yours));
    // Changed since: kept. As it was made: taken out.
    fs.writeFileSync(at, text + "Edited=1\n");
    assert.equal(helperRun(["remove-owned", at, text]).out.trim(), "kept");
    fs.writeFileSync(at, text);
    assert.equal(helperRun(["remove-owned", at, text]).out.trim(), "removed");
    // As Uber Notebook stops, run from its text (kept as it started), its
    // file gone already: the same.
    assert.equal(helperRun(["create-owned", at, text]).out.trim(), "made");
    const fromText = spawnSync("/usr/bin/python3", ["-I", "-S", "-c", fs.readFileSync(helper, "utf8"), "remove-owned", at, text], { encoding: "utf8" });
    assert.equal(fromText.stdout.trim(), "removed", fromText.stderr);
    assert.ok(!fs.existsSync(at));
    assert.ok(!fs.existsSync(at));
    // A link at the name: never followed, never taken out.
    const target = path.join(d, "target.txt");
    fs.writeFileSync(target, "precious");
    fs.symlinkSync(target, path.join(d, "link.desktop"));
    assert.equal(helperRun(["create-owned", path.join(d, "link.desktop"), text]).out.trim(), "taken");
    assert.equal(fs.readFileSync(target, "utf8"), "precious");
    assert.equal(helperRun(["remove-owned", path.join(d, "link.desktop"), "precious"]).out.trim(), "kept", "a link isn't the file");
    assert.ok(fs.lstatSync(path.join(d, "link.desktop")).isSymbolicLink());
    assert.equal(helperRun(["remove-owned", path.join(d, "none.desktop"), text]).out.trim(), "kept", "nothing there: nothing done");
    // (What's checked is what was moved aside: nothing's left aside after.)
    assert.deepEqual(fs.readdirSync(d).filter((n) => n.startsWith(".uber-notebook")), []);
  });

  check("its skill's link: taken out only if it's its own", () => {
    const d = folder("skills");
    fs.symlinkSync("/plugin/skills/uber-notebook", path.join(d, "uber-notebook"));
    assert.equal(helperRun(["unlink-link", path.join(d, "uber-notebook"), "/elsewhere"]).out.trim(), "kept");
    assert.equal(helperRun(["unlink-link", path.join(d, "uber-notebook"), "/plugin/skills/uber-notebook"]).out.trim(), "removed");
    fs.mkdirSync(path.join(d, "mine"));
    assert.equal(helperRun(["unlink-link", path.join(d, "mine"), "/plugin/skills/uber-notebook"]).out.trim(), "kept", "a folder isn't a link");
    assert.ok(fs.statSync(path.join(d, "mine")).isDirectory(), "put back as it was");
    fs.writeFileSync(path.join(d, "file"), "x");
    assert.equal(helperRun(["unlink-link", path.join(d, "file"), "/plugin/skills/uber-notebook"]).out.trim(), "kept", "nor a file");
    assert.equal(fs.readFileSync(path.join(d, "file"), "utf8"), "x");
    // Its skill in another place (an install before): its own too.
    const here = "/home/x/.config/omarchy/plugins/marcho78.uber-notebook/skills/uber-notebook";
    fs.symlinkSync("/old/place/marcho78.uber-notebook/skills/uber-notebook", path.join(d, "older"));
    assert.equal(helperRun(["unlink-link", path.join(d, "older"), "/plugin/skills/uber-notebook"]).out.trim(), "kept", "only for its skill");
    assert.equal(helperRun(["unlink-link", path.join(d, "older"), here]).out.trim(), "removed", "an install before");
    fs.symlinkSync("/old/place/other-plugin/skills/uber-notebook", path.join(d, "other"));
    assert.equal(helperRun(["unlink-link", path.join(d, "other"), here]).out.trim(), "kept", "anyone else's");
    // Its run, stopping: marked beside the lock (only a plain run id).
    const lock = path.join(d, "skills.lock");
    assert.equal(helperRun(["unlink-link", path.join(d, "none"), here, lock, "abc123run"]).out.trim(), "kept");
    assert.equal(fs.readFileSync(lock + ".stopped", "utf8"), "abc123run\n");
    assert.equal((fs.statSync(lock + ".stopped").mode & 0o777), 0o600);
    helperRun(["unlink-link", path.join(d, "none"), here, lock, "../x; rm"]);
    assert.equal(fs.readFileSync(lock + ".stopped", "utf8"), "abc123run\n", "nothing else written");
    fs.unlinkSync(lock); fs.unlinkSync(lock + ".stopped");
    assert.deepEqual(fs.readdirSync(d).filter((n) => n.startsWith(".uber-notebook")), [], "nothing left aside");
  });

  check("a text file read for an agent: only a plain file, never one that doesn't end", () => {
    const d = folder("reads");
    fs.writeFileSync(path.join(d, "a.md"), "# Hi \u2713");
    assert.deepEqual(JSON.parse(helperRun(["read", "1000", path.join(d, "a.md")]).out), { ok: true, text: "# Hi \u2713" });
    execFileSync("/usr/bin/mkfifo", [path.join(d, "f.md")]);
    const fifo = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "read", "1000", path.join(d, "f.md")], { encoding: "utf8", timeout: 5000 });
    assert.equal(fifo.error, undefined, "it doesn't wait for a writer");
    assert.equal(JSON.parse(fifo.stdout).ok, false);
    for (const dev of ["/dev/zero", "//dev/zero", "/tmp/../dev/zero", "/./dev/zero", "/proc/self/environ"]) {
      assert.equal(JSON.parse(helperRun(["read", "1000", dev]).out).ok, false, dev);
    }
    fs.writeFileSync(path.join(d, "big.md"), "x".repeat(2000));
    assert.match(JSON.parse(helperRun(["read", "1000", path.join(d, "big.md")]).out).error, /more than 1000 bytes/);
    fs.symlinkSync(path.join(d, "a.md"), path.join(d, "l.md"));
    assert.match(JSON.parse(helperRun(["read", "1000", path.join(d, "l.md")]).out).error, /link/);
  });
  check("your notes, served: read and written below their folder only, never through a link, never a file that isn't one", () => {
    const root = folder("notes");
    fs.mkdirSync(path.join(root, "Pages"));
    fs.writeFileSync(path.join(root, "Pages", "a.json"), '{"a":"\u00e9t\u00e9"}');
    fs.writeFileSync(path.join(root, "index.json"), "{}");
    const outside = folder("outside-notes");
    fs.writeFileSync(path.join(outside, "secret.json"), "SECRET");
    fs.symlinkSync(outside, path.join(root, "Linked"));
    fs.symlinkSync(path.join(outside, "secret.json"), path.join(root, "Pages", "link.json"));
    execFileSync("/usr/bin/mkfifo", [path.join(root, "Pages", "pipe.json")]);
    fs.writeFileSync(path.join(root, "Pages", "big.json"), "x".repeat(5000));
    const ask = (reqs) => {
      const r = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "serve", root], { input: reqs.map((q) => typeof q === "string" ? q : JSON.stringify(q)).join("\n") + "\n", encoding: "utf8", timeout: 10000 });
      assert.equal(r.error, undefined, "it answers, and ends with its input");
      return r.stdout.trim().split("\n").map((l) => JSON.parse(l));
    };
    const [read, wrote, back, found, foundIn, made] = ask([
      { id: 1, op: "read", paths: ["Pages/a.json", "Pages/none.json", "Linked/secret.json", "Pages/link.json", "Pages/pipe.json", "Pages/big.json", "../outside-notes/secret.json"], max: 1000 },
      { id: 2, op: "write", path: "Pages/b.json", text: "{\"b\":\"\u2713\"}" },
      { id: 3, op: "read", paths: ["Pages/b.json"], max: 1000 },
      { id: 4, op: "find", dir: "Pages", pattern: "*.json", max: 1000 },
      { id: 5, op: "find", dir: "", pattern: "*/notebook.json", max: 1000 },
      { id: 6, op: "mkdir", path: "Pages/assets/x" }
    ]);
    assert.equal(read.id, 1);
    assert.deepEqual(read.files, { "Pages/a.json": '{"a":"\u00e9t\u00e9"}' });
    assert.deepEqual(read.missing, ["Pages/none.json"]);
    assert.match(read.errors["Linked/secret.json"], /link/, "not through a link to a folder elsewhere");
    assert.match(read.errors["Pages/link.json"], /link/, "nor a link as the file");
    assert.match(read.errors["Pages/pipe.json"], /not a plain file/, "nor a pipe (and it doesn't wait on one)");
    assert.match(read.errors["Pages/big.json"], /more than 1000 bytes/);
    assert.match(read.errors["../outside-notes/secret.json"], /not a path in the notes folder/);
    assert.ok(!JSON.stringify(read).includes("SECRET"), "nothing outside read");
    assert.deepEqual([wrote.ok, back.files["Pages/b.json"]], [true, '{"b":"\u2713"}']);
    assert.deepEqual(Object.keys(found.files).sort(), ["Pages/a.json", "Pages/b.json"], "found: its plain files read, nothing it left behind");
    assert.deepEqual(Object.keys(found.errors).sort(), ["Pages/big.json", "Pages/link.json", "Pages/pipe.json"], "a link or a pipe it finds: said, not left out as if not there");
    assert.match(found.errors["Pages/link.json"], /link/);
    assert.match(foundIn.errors["Linked/notebook.json"], /link/, "a linked folder too");
    assert.deepEqual(foundIn.files, {});
    assert.ok(!JSON.stringify([found, foundIn]).includes("SECRET"), "nothing outside read");
    assert.ok(made.ok && fs.statSync(path.join(root, "Pages", "assets", "x")).isDirectory());
    // Never over a link or a folder, never through a linked folder.
    const [overLink, throughLink, overFolder, odd, unknown] = ask([
      { id: 8, op: "write", path: "Pages/link.json", text: "x" },
      { id: 9, op: "write", path: "Linked/new.json", text: "x" },
      { id: 10, op: "write", path: "Pages/assets", text: "x" },
      "not json", { id: 12, op: "remove", path: "Pages/a.json" }
    ]);
    assert.deepEqual([overLink.ok, overLink.error], [false, "something that isn't a plain file is there"]);
    assert.equal(fs.readFileSync(path.join(outside, "secret.json"), "utf8"), "SECRET", "what the link points to: untouched");
    assert.deepEqual([throughLink.ok, throughLink.error], [false, "a link, not a folder"]);
    assert.ok(!fs.existsSync(path.join(outside, "new.json")));
    assert.equal(overFolder.ok, false);
    assert.deepEqual([odd.id, odd.ok], [null, false]);
    assert.deepEqual([unknown.ok, unknown.error], [false, "no such request"], "only what Uber Notebook asks for");
    assert.ok(fs.existsSync(path.join(root, "Pages", "a.json")));
    assert.deepEqual(fs.readdirSync(path.join(root, "Pages")).filter((n) => n.endsWith(".tmp")), [], "no half-written file left");
    // A page written survives a power cut: the file on disk, then its
    // folder (the rename in it).
    const synced = spawnSync("/usr/bin/python3", ["-I", "-S", "-c",
      "import os, runpy, stat, sys\nseen = []\nreal = os.fsync\n"
      + "def fsync(fd):\n    seen.append('dir' if stat.S_ISDIR(os.fstat(fd).st_mode) else 'file')\n    return real(fd)\n"
      + "os.fsync = fsync\nsys.argv = sys.argv[1:]\ntry:\n    runpy.run_path(sys.argv[0], run_name='__main__')\nfinally:\n    sys.stderr.write('FSYNC ' + ','.join(seen) + '\\n')\n",
      helper, "serve", root], { input: JSON.stringify({ id: 1, op: "write", path: "Pages/c.json", text: "{}" }) + "\n", encoding: "utf8", timeout: 10000 });
    assert.equal(JSON.parse(synced.stdout.trim()).ok, true);
    assert.match(synced.stderr, /FSYNC file,dir\n/, synced.stderr);
    // Only a folder of yours.
    const notYours = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "serve", "/"], { input: JSON.stringify({ id: 1, op: "read", paths: ["etc/hostname"] }) + "\n", encoding: "utf8", timeout: 10000 });
    assert.notEqual(notYours.status, 0);
    assert.match(notYours.stderr, /isn't yours/);
    assert.equal(notYours.stdout, "");
  });
  check("a page made a document: its pictures put in, sized; nothing that loads from elsewhere gets past", () => {
    const zlib = require("node:zlib");
    // A real PNG, w x h.
    function png(w, h) {
      const crc = (buf) => { let c = ~0; for (const b of buf) { c ^= b; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1)); } return ~c >>> 0; };
      const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const t = Buffer.from(type); const c = Buffer.alloc(4); c.writeUInt32BE(crc(Buffer.concat([t, data]))); return Buffer.concat([len, t, data, c]); };
      const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
      const raw = Buffer.alloc((w * 3 + 1) * h);
      return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(raw)), chunk("IEND", Buffer.alloc(0))]);
    }
    const assets = folder("export-assets");
    const outside = folder("export-outside");
    fs.writeFileSync(path.join(assets, "wide.png"), png(40, 20));
    fs.writeFileSync(path.join(assets, "tall.png"), png(20, 400));
    fs.writeFileSync(path.join(assets, "fake.png"), "not a picture");
    fs.writeFileSync(path.join(outside, "secret.png"), png(10, 10));
    fs.symlinkSync(path.join(outside, "secret.png"), path.join(assets, "link.png"));
    fs.writeFileSync(path.join(assets, "closed.svg"), '<svg xmlns="http://www.w3.org/2000/svg" width="100" height="50"><use href="#a"/></svg>');
    fs.writeFileSync(path.join(assets, "open.svg"), '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"><image href="https://evil.example/x.png"/></svg>');
    const head = `<!doctype html>\n<html><head><meta charset="utf-8" />\n<meta http-equiv="Content-Security-Policy" content="default-src 'none'; img-src data:; style-src 'unsafe-inline'" />\n<title>T</title><style>p { color: #111; }</style></head><body>`;
    let n = 0;
    function run(body, max) {
      const work = folder("export-work-" + (n++));
      fs.mkdirSync(path.join(work, "drawings"));
      fs.writeFileSync(path.join(work, "drawings", "d1.png"), png(800, 200));
      fs.writeFileSync(path.join(work, "page.src.html"), head + body + "</body></html>");
      const r = helperRun(["export-html", assets, work, String(max || 1048576)]);
      const out = fs.existsSync(path.join(work, "page.html")) ? fs.readFileSync(path.join(work, "page.html"), "utf8") : null;
      return { r: JSON.parse(r.out.trim().split("\n").pop() || "{}"), out };
    }
    const img = (name, style) => `<img src="uber-notebook-asset:${name}" alt="x" style="${style || ""}" />`;
    // Put in, sized to the share of the page asked for, their proportions kept.
    const ok = run(`<p>${img("wide.png", "width:50%;")}</p><p>${img("tall.png", "width:100%;")}</p><p><img src="uber-notebook-drawing:d1.png" alt="A diagram" style="max-width:100%;" /></p><p>${img("closed.svg", "width:100%;")}</p><p>Text: url(http://x) @import y; &lt;script&gt;</p>`);
    assert.deepEqual([ok.r.ok, ok.r.pictures, ok.r.missing], [true, 4, 0], JSON.stringify(ok.r));
    assert.match(ok.out, /<img src="data:image\/png;base64,[^"]+" alt="x" width="330" height="165" \/>/, "half the page across");
    assert.match(ok.out, /width="22" height="450"/, "no taller than half a sheet");
    assert.match(ok.out, /alt="A diagram" width="400" height="100"/, "a drawing at half the pixels it was drawn at");
    assert.match(ok.out, /data:image\/svg\+xml;base64,[^"]+" alt="x" width="660" height="330"/);
    assert.ok(ok.out.includes("Text: url(http://x) @import y; &lt;script&gt;"), "words are words");
    // What can't be put in: said in its place.
    const miss = run(`${img("link.png")}${img("fake.png")}${img("none.png")}${img("open.svg")}<img src="uber-notebook-asset:../export-outside/secret.png" alt="" />`);
    assert.deepEqual([miss.r.ok, miss.r.pictures], [false, undefined], "a name that isn't one isn't put in, and the document's refused");
    const miss2 = run(`${img("link.png")}${img("fake.png")}${img("none.png")}${img("open.svg")}`);
    assert.deepEqual([miss2.r.ok, miss2.r.pictures, miss2.r.missing], [true, 0, 4], "a link, not a picture, not there, an SVG naming the web");
    assert.ok(!miss2.out.includes("data:image") && !/secret|evil/.test(miss2.out));
    // Past the room: left out.
    assert.equal(run(img("tall.png", "width:100%;"), 100).r.missing, 1);
    // The same picture many times: each time charged, not once.
    const many = run(Array.from({ length: 50 }, () => img("wide.png", "width:10%;")).join(""), 1000);
    assert.equal(many.r.ok, true);
    assert.ok(many.r.pictures >= 1 && many.r.pictures < 50 && many.r.missing === 50 - many.r.pictures, JSON.stringify(many.r));
    assert.ok(many.out.length < 1000 + 50 * 200, "the document within its room: " + many.out.length);
    // Many different pictures, each within the room, all of them far past it:
    // only what fits is read and kept (run with little memory to show it).
    const lots = folder("export-lots");
    const wl = folder("export-work-lots");
    fs.mkdirSync(path.join(wl, "drawings"));
    const filler = Buffer.alloc(1024 * 1024, 7);
    let lotsBody = "";
    for (let i = 0; i < 90; i++) {
      fs.writeFileSync(path.join(lots, "p" + i + ".png"), Buffer.concat([png(10, 10), filler, Buffer.from(String(i))]));
      lotsBody += img("p" + i + ".png", "width:10%;");
    }
    fs.writeFileSync(path.join(wl, "page.src.html"), head + lotsBody + "</body></html>");
    const low = spawnSync("/usr/bin/prlimit", ["--as=140000000", "--", "/usr/bin/python3", "-I", "-S", helper, "export-html", lots, wl, String(4 * 1048576)], { encoding: "utf8", timeout: 60000 });
    const lr = JSON.parse(low.stdout.trim().split("\n").pop() || "{}");
    assert.deepEqual([low.status, lr.ok, lr.pictures + lr.missing], [0, true, 90], low.stdout + low.stderr);
    assert.ok(lr.pictures >= 1 && lr.pictures <= 3, JSON.stringify(lr));
    // Anything that loads from elsewhere: refused, nothing written.
    for (const bad of ['<script>x</script>', '<iframe src="https://e.org"></iframe>', '<img src="https://e.org/x.png" />', '<img src="file:///etc/passwd" />',
      '<link rel="stylesheet" href="https://e.org/a.css" />', '<p style="background:url(https://e.org/x)">x</p>', '<style>@import "https://e.org/a.css";</style>',
      '<a href="javascript:alert(1)">x</a>', '<meta http-equiv="refresh" content="0;url=https://e.org" />', '<object data="x"></object>', '<p onclick="x()">x</p>',
      '<svg><image href="https://e.org/x"/></svg>', '<img src="data:image/svg+xml;base64,' + Buffer.from('<svg xmlns="http://www.w3.org/2000/svg"><image href="https://e.org/x"/></svg>').toString("base64") + '" />',
      '<p style="background:\\75rl(https://e.org)">x</p>', '<base href="https://e.org/" />', '<img srcset="https://e.org/x.png 2x" src="data:image/png;base64,AA==" />']) {
      const r = run(bad);
      assert.equal(r.r.ok, false, bad);
      assert.equal(r.out, null, "nothing written: " + bad);
    }
    // The document itself only as a plain file of its own.
    const work = folder("export-link");
    fs.symlinkSync(path.join(outside, "secret.png"), path.join(work, "page.src.html"));
    assert.equal(JSON.parse(helperRun(["export-html", assets, work, "1000000"]).out).ok, false);
  });
  check("a picture copied in: only a plain file that's a picture Qt can show, within its size, as a new file; an agent's only from its folder, through no link", () => {
    const zlib = require("node:zlib");
    function png(w, h, body) {
      const crc = (buf) => { let c = ~0; for (const b of buf) { c ^= b; for (let k = 0; k < 8; k++) c = (c >>> 1) ^ (0xedb88320 & -(c & 1)); } return ~c >>> 0; };
      const chunk = (type, data) => { const len = Buffer.alloc(4); len.writeUInt32BE(data.length); const t = Buffer.from(type); const c = Buffer.alloc(4); c.writeUInt32BE(crc(Buffer.concat([t, data]))); return Buffer.concat([len, t, data, c]); };
      const ihdr = Buffer.alloc(13); ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4); ihdr[8] = 8; ihdr[9] = 2;
      return Buffer.concat([Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]), chunk("IHDR", ihdr), chunk("IDAT", zlib.deflateSync(body || Buffer.alloc(16))), chunk("IEND", Buffer.alloc(0))]);
    }
    const src = folder("pictures-src");
    const dest = folder("pictures-dest");
    const agent = folder("pictures-agent");
    const elsewhere = folder("pictures-elsewhere");
    fs.writeFileSync(path.join(src, "ok.png"), png(40, 20));
    fs.writeFileSync(path.join(src, "huge.png"), png(20000, 100));
    fs.writeFileSync(path.join(src, "many.png"), png(16000, 16000));
    fs.writeFileSync(path.join(src, "text.png"), "not a picture at all");
    fs.writeFileSync(path.join(src, "closed.svg"), '<svg xmlns="http://www.w3.org/2000/svg" width="10" height="10"/>');
    fs.writeFileSync(path.join(src, "open.svg"), '<svg xmlns="http://www.w3.org/2000/svg"><image href="file:///etc/passwd"/></svg>');
    execFileSync("/usr/bin/mkfifo", [path.join(src, "pipe.png")]);
    fs.symlinkSync(path.join(src, "ok.png"), path.join(src, "link.png"));
    fs.writeFileSync(path.join(agent, "mine.png"), png(10, 10));
    fs.writeFileSync(path.join(elsewhere, "private.png"), png(10, 10));
    fs.symlinkSync(elsewhere, path.join(agent, "linked"));
    fs.symlinkSync(path.join(elsewhere, "private.png"), path.join(agent, "alias.png"));
    let n = 0;
    const copy = (from, max, within, to) => {
      const name = to || "p" + (n++) + ".png";
      const r = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "copy-picture", from, dest, name, String(max || 1000000)].concat(within ? [within] : []), { encoding: "utf8", timeout: 10000 });
      assert.equal(r.error, undefined, "it doesn't wait on anything: " + from);
      const out = JSON.parse(r.stdout.trim().split("\n").pop());
      return Object.assign(out, { there: fs.existsSync(path.join(dest, name)), name });
    };
    const ok = copy(path.join(src, "ok.png"));
    assert.deepEqual([ok.ok, ok.width, ok.height, ok.there], [true, 40, 20, true]);
    assert.deepEqual(fs.readFileSync(path.join(dest, ok.name)), fs.readFileSync(path.join(src, ok.name.replace(/.*/, "ok.png"))), "the same bytes");
    assert.equal(copy(path.join(src, "link.png")).ok, true, "a link to a picture you picked: followed");
    assert.equal(copy(path.join(src, "closed.svg"), 0, "", "c.svg").ok, true);
    for (const [file, why, max] of [["pipe.png", /not a plain file/], ["text.png", /not a picture/], ["huge.png", /too big to show/], ["many.png", /too big to show/],
      ["open.svg", /names something outside/], ["ok.png", /more than 10 bytes/, 10]]) {
      const r = copy(path.join(src, file), max);
      assert.equal(r.ok, false, file);
      assert.match(r.error, why, file);
      assert.equal(r.there, false, "nothing left: " + file);
    }
    assert.equal(copy("/dev/zero").ok, false, "never a device");
    // Never over a file that's there; never into a folder that's a link.
    fs.writeFileSync(path.join(dest, "taken.png"), "MINE");
    assert.equal(copy(path.join(src, "ok.png"), 0, "", "taken.png").ok, false);
    assert.equal(fs.readFileSync(path.join(dest, "taken.png"), "utf8"), "MINE");
    fs.symlinkSync(elsewhere, path.join(src, "dest-link"));
    const intoLink = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "copy-picture", path.join(src, "ok.png"), path.join(src, "dest-link"), "x.png", "1000000"], { encoding: "utf8" });
    assert.equal(JSON.parse(intoLink.stdout).ok, false);
    assert.ok(!fs.existsSync(path.join(elsewhere, "x.png")));
    // An agent's: only from its folder, through no link.
    assert.equal(copy(path.join(agent, "mine.png"), 0, agent).ok, true);
    for (const p of [path.join(agent, "linked", "private.png"), path.join(agent, "alias.png"), path.join(elsewhere, "private.png"), path.join(agent, "..", "pictures-elsewhere", "private.png")]) {
      const r = copy(p, 0, agent);
      assert.equal(r.ok, false, p);
      assert.equal(r.there, false);
    }
    assert.equal(copy(path.join(src, "ok.png"), 0, "", "../escape.png").ok, false, "a name, not a path");
    // Grok's pictures for a conversation (its session folder, named with %
    // escapes): taken from there, through no link.
    const grok = path.join(folder("pictures-grok"), "%2Frun%2Fuser%2F1000%2Fc-1");
    fs.mkdirSync(path.join(grok, "01a1", "images"), { recursive: true });
    fs.writeFileSync(path.join(grok, "01a1", "images", "1.png"), png(12, 8));
    fs.symlinkSync(path.join(elsewhere, "private.png"), path.join(grok, "01a1", "images", "2.png"));
    // A folder you said Always to, with a link in it to a hidden folder
    // (Codex's case): a file through the link is refused, read from the
    // folder you approved, every step below it through no link; and "/" for
    // a yes to one file: every step of its path.
    const approved = folder("pictures-approved");
    const hidden = folder("pictures-hidden-config");
    fs.mkdirSync(path.join(hidden, "app"));
    fs.writeFileSync(path.join(hidden, "app", "token.png"), png(4, 4));
    fs.symlinkSync(hidden, path.join(approved, "link"));
    fs.writeFileSync(path.join(approved, "real.png"), png(4, 4));
    assert.equal(copy(path.join(approved, "link", "app", "token.png"), 0, approved).ok, false, "through a link below the folder you approved: refused");
    assert.equal(copy(path.join(approved, "real.png"), 0, approved).ok, true);
    assert.equal(copy(path.join(approved, "link", "app", "token.png"), 0, "/").ok, false, "from the root: refused too");
    assert.equal(copy(path.join(approved, "real.png"), 0, "/").ok, true, "a plain path from the root");
    const made = copy(path.join(grok, "01a1", "images", "1.png"), 0, grok);
    assert.deepEqual([made.ok, made.width, made.height], [true, 12, 8]);
    assert.equal(copy(path.join(grok, "01a1", "images", "2.png"), 0, grok).ok, false, "a link there: refused");
  });
  check("any other file of an agent's (an email, a video, a PDF): only from its folder, through no link, as a new file", () => {
    const dest = folder("files-dest");
    const agent = folder("files-agent");
    const elsewhere = folder("files-elsewhere");
    fs.writeFileSync(path.join(agent, "notes.pdf"), "%PDF-1.7 mine");
    fs.writeFileSync(path.join(elsewhere, "id_ed25519"), "PRIVATE KEY");
    fs.symlinkSync(path.join(elsewhere, "id_ed25519"), path.join(agent, "key.eml"));
    fs.symlinkSync(elsewhere, path.join(agent, "linked"));
    execFileSync("/usr/bin/mkfifo", [path.join(agent, "pipe.mp4")]);
    let n = 0;
    const copy = (from, max, to) => {
      const name = to || "f" + (n++) + ".bin";
      const r = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "copy-file", from, dest, name, String(max || 1000000), agent], { encoding: "utf8", timeout: 10000 });
      assert.equal(r.error, undefined, "it doesn't wait on anything: " + from);
      const out = JSON.parse(r.stdout.trim().split("\n").pop());
      return Object.assign(out, { there: fs.existsSync(path.join(dest, name)), name });
    };
    const ok = copy(path.join(agent, "notes.pdf"));
    assert.deepEqual([ok.ok, ok.size, ok.there], [true, 13, true]);
    assert.equal(fs.readFileSync(path.join(dest, ok.name), "utf8"), "%PDF-1.7 mine", "the same bytes");
    for (const [p, why] of [[path.join(agent, "key.eml"), /a link/], [path.join(agent, "linked", "id_ed25519"), /a link/],
      [path.join(elsewhere, "id_ed25519"), /not in that folder/], [path.join(agent, "..", "files-elsewhere", "id_ed25519"), /not in that folder/],
      [path.join(agent, "pipe.mp4"), /not a plain file/]]) {
      const r = copy(p);
      assert.equal(r.ok, false, p);
      assert.match(r.error, why, p);
      assert.equal(r.there, false, "nothing left: " + p);
    }
    const big = copy(path.join(agent, "notes.pdf"), 5);
    assert.deepEqual([big.ok, big.there], [false, false], "at most its size");
    fs.writeFileSync(path.join(dest, "taken.pdf"), "THEIRS");
    assert.equal(copy(path.join(agent, "notes.pdf"), 0, "taken.pdf").ok, false, "never over a file");
    assert.equal(fs.readFileSync(path.join(dest, "taken.pdf"), "utf8"), "THEIRS");
    assert.equal(copy(path.join(agent, "notes.pdf"), 0, "../escape.pdf").ok, false, "a name, not a path");
    // (Without the agent's folder, there's no copy-file.)
    const bare = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "copy-file", path.join(agent, "notes.pdf"), dest, "x.pdf", "1000"], { encoding: "utf8" });
    assert.notEqual(bare.status, 0);
    assert.ok(!fs.existsSync(path.join(dest, "x.pdf")));
  });
  check("a zip's folders count, every entry counts, and its directory's size is known before it's read", () => {
    const run = (zipFile, maxFiles) => {
      const to = folder("unzip-" + path.basename(zipFile));
      const r = helperRun(["unzip", zipFile, to, "1000000", String(maxFiles)]);
      return { r: JSON.parse(r.out.trim().split("\n").pop()), made: execFileSync("/usr/bin/find", [to, "-mindepth", "1"], { encoding: "utf8" }).split("\n").filter(Boolean).length };
    };
    // Thirty empty folders, room for ten: refused, at most ten made.
    const dirs = run(zip(path.join(tmp, "dirs.zip"), Array.from({ length: 30 }, (_, i) => ({ name: "d" + i + "/" }))), 10);
    assert.deepEqual([dirs.r.ok, dirs.r.error], [false, "more than 10 files"]);
    assert.ok(dirs.made <= 10, String(dirs.made));
    // A hundred: more entries than it may have, none made.
    const hundred = run(zip(path.join(tmp, "hundred.zip"), Array.from({ length: 100 }, (_, i) => ({ name: "d" + i + "/" }))), 10);
    assert.deepEqual([hundred.r.ok, hundred.r.error, hundred.made], [false, "more than 40 entries", 0]);
    // A file six folders down: the folders it takes count too.
    const deep = run(zip(path.join(tmp, "deep.zip"), [{ name: "a/b/c/d/e/f/x.md", data: "x" }]), 5);
    assert.deepEqual([deep.r.ok, deep.r.error], [false, "more than 5 files"]);
    // More entries than four for each file it may make: refused before its directory's read.
    const many = run(zip(path.join(tmp, "many.zip"), Array.from({ length: 30 }, (_, i) => ({ name: "f" + i + ".md", data: "" }))), 5);
    assert.deepEqual([many.r.ok, many.r.error, many.made], [false, "more than 20 entries", 0]);
    // Skipped entries count too, across the zips inside it: three inner zips
    // of fifteen names it won't make add up past forty.
    const inner = [0, 1, 2].map((k) => ({ name: "part" + k + ".zip", file: zip(path.join(tmp, "inner" + k + ".zip"), Array.from({ length: 15 }, (_, i) => ({ name: "../evil" + k + "-" + i, data: "x" }))) }));
    const nested = run(zip(path.join(tmp, "nested.zip"), inner), 10);
    assert.deepEqual([nested.r.ok, nested.r.error], [false, "more than 40 entries"]);
    // A zip whose end says it has one entry, and has thirty: each counted as it's read.
    const liar = zip(path.join(tmp, "liar.zip"), Array.from({ length: 30 }, (_, i) => ({ name: "../evil" + i, data: "x" })));
    const bytes = fs.readFileSync(liar);
    const end = bytes.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
    bytes.writeUInt16LE(1, end + 8);
    bytes.writeUInt16LE(1, end + 10);
    fs.writeFileSync(liar, bytes);
    const lied = run(liar, 5);
    assert.deepEqual([lied.r.ok, lied.r.error], [false, "more than 20 entries"]);
    // One whose end says one entry, with a zip64 record before it that says
    // thirty (zipfile reads that one): refused before its directory's read.
    const z64 = zip(path.join(tmp, "zip64-liar.zip"), Array.from({ length: 30 }, (_, i) => ({ name: "f" + i + ".md", data: "x" })));
    const zb = fs.readFileSync(z64);
    const ze = zb.lastIndexOf(Buffer.from([0x50, 0x4b, 0x05, 0x06]));
    const [count, cdSize, cdAt] = [zb.readUInt16LE(ze + 10), zb.readUInt32LE(ze + 12), zb.readUInt32LE(ze + 16)];
    const rec = Buffer.alloc(56);
    rec.writeUInt32LE(0x06064b50, 0); rec.writeBigUInt64LE(44n, 4); rec.writeUInt16LE(45, 12); rec.writeUInt16LE(45, 14);
    rec.writeBigUInt64LE(BigInt(count), 24); rec.writeBigUInt64LE(BigInt(count), 32); rec.writeBigUInt64LE(BigInt(cdSize), 40); rec.writeBigUInt64LE(BigInt(cdAt), 48);
    const locator = Buffer.alloc(20);
    locator.writeUInt32LE(0x07064b50, 0); locator.writeBigUInt64LE(BigInt(ze), 8); locator.writeUInt32LE(1, 16);
    const classic = Buffer.from(zb.subarray(ze, ze + 22));
    classic.writeUInt16LE(1, 8); classic.writeUInt16LE(1, 10); classic.writeUInt32LE(46, 12);
    fs.writeFileSync(z64, Buffer.concat([zb.subarray(0, ze), rec, locator, classic]));
    assert.equal(execFileSync("/usr/bin/python3", ["-c", "import zipfile,sys; print(len(zipfile.ZipFile(sys.argv[1]).infolist()))", z64], { encoding: "utf8" }).trim(), "30", "zipfile reads all thirty");
    const lied64 = run(z64, 5);
    assert.deepEqual([lied64.r.ok, lied64.r.error, lied64.made], [false, "more than 20 entries", 0]);
    // Within its room: as before.
    const fine = run(zip(path.join(tmp, "fine.zip"), [{ name: "a/b/x.md", data: "x" }, { name: "c/" }]), 5);
    assert.deepEqual([fine.r.ok, fine.r.files, fine.made], [true, 1, 4]);
  });
  check("the Markdown copy's changes: made only to files still as it wrote them; yours kept", () => {
    const crypto = require("node:crypto");
    const fp = (t) => "s256:" + crypto.createHash("sha256").update(Buffer.from(t, "utf8")).digest("hex");
    const m = folder("mirror");
    const outside = folder("mirror-outside");
    const put = (rel, text) => { fs.mkdirSync(path.dirname(path.join(m, rel)), { recursive: true }); fs.writeFileSync(path.join(m, rel), text); };
    put("Pages/A.md", "A1");            // the copy's: written over
    put("Pages/B.md", "B, as you edited it");  // yours now: kept
    put("Pages/C.md", "C1");            // the copy's: taken away
    put("Pages/D.md", "D, edited");     // yours: kept, not taken away
    put("Pages/Legacy.md", "L");        // an old fingerprint, exactly what it'd write: the copy's
    put("Pages/Legacy2.md", "old L2");  // an old fingerprint, not what it'd write: kept
    fs.mkdirSync(path.join(m, "Pages", "Dir.md"));  // a folder where a file was
    fs.writeFileSync(path.join(outside, "secret.md"), "SECRET");
    fs.symlinkSync(path.join(outside, "secret.md"), path.join(m, "Pages", "Link.md"));
    put("Pages/Taken.md", "someone's");  // a file where it means to write a new one
    put("Pages/sub/Deep.md", "deep");    // the copy's, alone in its folder
    const plan = path.join(tmp, "mirror-plan.json");
    fs.writeFileSync(plan, JSON.stringify({ ops: [
      { op: "write", path: "Pages/A.md", expect: fp("A1"), text: "A2 ✓" },
      { op: "write", path: "Pages/B.md", expect: fp("B1"), text: "B2" },
      { op: "remove", path: "Pages/C.md", expect: fp("C1") },
      { op: "remove", path: "Pages/D.md", expect: fp("D1") },
      { op: "write", path: "Pages/Legacy.md", expect: "0000abcd:1", text: "L" },
      { op: "write", path: "Pages/Legacy2.md", expect: "0000abcd:6", text: "new L2" },
      { op: "write", path: "Pages/Dir.md", expect: fp("x"), text: "y" },
      { op: "write", path: "Pages/Link.md", expect: fp("SECRET"), text: "OVER" },
      { op: "write", path: "Pages/New.md", expect: "absent", text: "new" },
      { op: "write", path: "Pages/Taken.md", expect: "absent", text: "mine" },
      { op: "remove", path: "Pages/sub/Deep.md", expect: fp("deep") },
      { op: "write", path: "../escape.md", expect: "absent", text: "x" },
      { op: "write", path: "Other/x.md", expect: "absent", text: "x" }
    ] }));
    const r = helperRun(["mirror-apply", m, plan]);
    const out = JSON.parse(r.out);
    const read = (rel) => fs.readFileSync(path.join(m, rel), "utf8");
    assert.equal(out.ok, true, r.err);
    assert.deepEqual(Object.keys(out.written).sort(), ["Pages/A.md", "Pages/Legacy.md", "Pages/New.md"]);
    assert.equal(out.written["Pages/A.md"], fp("A2 ✓"), "its fingerprint, of the bytes written");
    assert.equal(read("Pages/A.md"), "A2 ✓");
    assert.equal(read("Pages/New.md"), "new");
    assert.deepEqual(out.removed.sort(), ["Pages/C.md", "Pages/sub/Deep.md"]);
    assert.ok(!fs.existsSync(path.join(m, "Pages", "C.md")));
    assert.ok(!fs.existsSync(path.join(m, "Pages", "sub")), "a folder it emptied, gone");
    assert.deepEqual(out.kept.sort(), ["Pages/B.md", "Pages/D.md", "Pages/Dir.md", "Pages/Legacy2.md", "Pages/Link.md", "Pages/Taken.md"]);
    assert.equal(read("Pages/B.md"), "B, as you edited it");
    assert.equal(read("Pages/D.md"), "D, edited");
    assert.equal(read("Pages/Legacy2.md"), "old L2", "an old fingerprint is no proof");
    assert.ok(fs.statSync(path.join(m, "Pages", "Dir.md")).isDirectory(), "a folder, put back");
    assert.ok(fs.lstatSync(path.join(m, "Pages", "Link.md")).isSymbolicLink(), "a link, put back, not followed");
    assert.equal(fs.readFileSync(path.join(outside, "secret.md"), "utf8"), "SECRET");
    assert.equal(read("Pages/Taken.md"), "someone's");
    assert.deepEqual(Object.keys(out.failed).sort(), ["../escape.md", "Other/x.md"]);
    assert.ok(!fs.existsSync(path.join(tmp, "escape.md")));
    assert.ok(!fs.existsSync(plan), "the plan, taken away once read");
    assert.deepEqual(fs.readdirSync(path.join(m, "Pages")).filter((n) => n.startsWith(".uber-notebook")), [], "nothing left aside");
  });
  check("an agent's lines made ASCII: counted as it prints them, before they're escaped", () => {
    const run = (input, line, total) => spawnSync("/usr/bin/python3", ["-I", "-S", helper, "ascii-lines", String(line), String(total)], { input, encoding: "utf8", timeout: 10000 });
    const lines = (r) => r.stdout.split("\n").filter(Boolean).map((l) => JSON.parse(l));
    // CJK and control characters escape to several times their bytes: still
    // within a line's room, as they were printed.
    const cjk = JSON.stringify({ t: "\u4e2d".repeat(290) });
    const ctl = JSON.stringify({ t: "\u0001".repeat(140) });
    const a = run(cjk + "\n" + ctl + "\n", 1000, 100000);
    assert.equal(a.status, 0, a.stderr);
    assert.deepEqual(lines(a).map((o) => o.t.length), [290, 140]);
    assert.ok(a.stdout.split("\n")[0].length > 1000, "longer once escaped, and still let through");
    // Plain ASCII: no more room than before.
    const b = run("x".repeat(999) + "\n" + "y".repeat(1001) + "\n" + JSON.stringify({ ok: 1 }) + "\n", 1000, 100000);
    assert.equal(b.status, 0);
    assert.deepEqual(lines(b), ["x".repeat(999), { ok: 1 }], "the line past its room left out");
    assert.match(b.stderr, /left out a line longer than/);
    // A line too long that hasn't ended yet: left out up to its end, said once.
    const c = run("z".repeat(70000) + "\nafter\n", 1000, 1000000);
    assert.deepEqual(lines(c), ["after"]);
    assert.equal(c.stderr.split("left out").length - 1, 1);
    // Past all it may print: it stops, says so, ends 3.
    const d = run(("w".repeat(500) + "\n").repeat(200), 1000, 70000);
    assert.equal(d.status, 3);
    assert.match(d.stderr, /printed more than/);
    assert.ok(lines(d).length < 140, String(lines(d).length));
  });
  check("an agent's folder: its sandbox profile put without following a link; its files read only from it", () => {
    const f = folder("agent-conv");
    const out = folder("agent-outside");
    fs.writeFileSync(path.join(out, "target"), "SECRET");
    fs.mkdirSync(path.join(f, ".grok"));
    fs.symlinkSync(path.join(out, "target"), path.join(f, ".grok", "sandbox.toml"));
    const put = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "put", f, ".grok/sandbox.toml"], { input: "profile", encoding: "utf8" });
    assert.equal(put.stdout.trim(), "put", put.stderr);
    assert.equal(fs.readFileSync(path.join(out, "target"), "utf8"), "SECRET", "what the link pointed to: untouched");
    assert.ok(!fs.lstatSync(path.join(f, ".grok", "sandbox.toml")).isSymbolicLink());
    assert.equal(fs.readFileSync(path.join(f, ".grok", "sandbox.toml"), "utf8"), "profile");
    fs.symlinkSync(out, path.join(f, "linked"));
    assert.notEqual(spawnSync("/usr/bin/python3", ["-I", "-S", helper, "put", f, "linked/x"], { input: "x" }).status, 0, "never through a linked folder");
    assert.ok(!fs.existsSync(path.join(out, "x")));
    assert.notEqual(spawnSync("/usr/bin/python3", ["-I", "-S", helper, "put", path.join(f, "linked"), "x"], { input: "x" }).status, 0, "an agent's folder that's a link: refused");
    // The Markdown copy's folder, the one you chose, may be a link to where
    // you keep it (put-copy); nothing below it is followed.
    const vault = folder("copy-vault");
    const chosen = path.join(tmp, "copy-chosen");
    fs.symlinkSync(vault, chosen);
    const pc = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "put-copy", chosen, ".uber-notebook-mirror.json"], { input: "{}", encoding: "utf8" });
    assert.equal(pc.stdout.trim(), "put", pc.stderr);
    assert.equal(fs.readFileSync(path.join(vault, ".uber-notebook-mirror.json"), "utf8"), "{}");
    fs.symlinkSync(out, path.join(vault, "inner"));
    assert.notEqual(spawnSync("/usr/bin/python3", ["-I", "-S", helper, "put-copy", chosen, "inner/x"], { input: "x" }).status, 0, "a link below it: not followed");
    assert.ok(!fs.existsSync(path.join(out, "x")));
    fs.symlinkSync(path.join(out, "target"), path.join(vault, "list.json"));
    assert.equal(spawnSync("/usr/bin/python3", ["-I", "-S", helper, "put-copy", chosen, "list.json"], { input: "new", encoding: "utf8" }).stdout.trim(), "put");
    assert.equal(fs.readFileSync(path.join(out, "target"), "utf8"), "SECRET", "a link put there: replaced, not written through");
    // Read: from its folder only, through no link.
    fs.mkdirSync(path.join(f, "in"));
    fs.writeFileSync(path.join(f, "in", "a.md"), "hi");
    const read = (p) => JSON.parse(helperRun(["read", "1000", p, f]).out);
    assert.deepEqual(read(path.join(f, "in", "a.md")), { ok: true, text: "hi" });
    assert.equal(read(path.join(f, "linked", "target")).ok, false, "not through a linked folder");
    assert.equal(read(path.join(out, "target")).ok, false, "not outside it");
    assert.equal(read(path.join(f, "..", "agent-outside", "target")).ok, false);
  });

  // A notification: its words on the helper's input, sent over the session
  // bus by the helper itself (never on a command line). On a bus of its own
  // with no notification server, the call is seen by dbus-monitor, and the
  // bus's "nobody's there" comes back as the helper's error.
  check("notify: the notification on the bus, its words never on a command line", () => {
    if (!fs.existsSync("/usr/bin/dbus-daemon") || !fs.existsSync("/usr/bin/dbus-monitor")) { console.log("files: notify skipped (no dbus-daemon)"); return; }
    const bus = fs.mkdtempSync(path.join(tmp, "bus-"));
    const address = "unix:path=" + path.join(bus, "bus");
    const pid = execFileSync("/usr/bin/dbus-daemon", ["--session", "--fork", "--address=" + address, "--print-pid"], { encoding: "utf8" }).trim();
    const sleep = (ms) => Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
    const log = fs.openSync(path.join(bus, "monitor.txt"), "w");
    const monitor = require("node:child_process").spawn("/usr/bin/dbus-monitor", ["--address", address], { stdio: ["ignore", log, log] });
    try {
      sleep(400);
      const note = { summary: "-rf Call the dentist", body: "before Friday ✓", glyph: "\u{f009e}", exec: ["/usr/bin/omarchy-shell", "uber-notebook", "open", "0b6f8f9e-1111-4222-8333-944455556666"] };
      const r = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "notify"], { input: JSON.stringify(note), encoding: "utf8", env: { DBUS_SESSION_BUS_ADDRESS: address } });
      assert.equal(r.status, 3, r.stderr);
      assert.match(r.stderr, /ServiceUnknown/);
      sleep(300);
      const seen = fs.readFileSync(path.join(bus, "monitor.txt"), "utf8");
      const call = seen.slice(seen.indexOf("member=Notify"));
      assert.ok(seen.indexOf("member=Notify") >= 0, seen);
      for (const want of ['string "Uber Notebook"', 'string "-rf Call the dentist"', 'string "before Friday ✓"', 'string "urgency"', "byte 1",
        'string "omarchy-glyph"', 'string "omarchy-exec-argv"', 'string "["/usr/bin/omarchy-shell","uber-notebook","open","0b6f8f9e-1111-4222-8333-944455556666"]"', "int32 -1"]) {
        assert.ok(call.indexOf(want) >= 0, "the call has " + want + ":\n" + call.slice(0, 1500));
      }
      // Only words for the click command, a few of them.
      const bad = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "notify"], { input: JSON.stringify({ summary: "x", exec: "rm -rf ~" }), encoding: "utf8", env: { DBUS_SESSION_BUS_ADDRESS: address } });
      assert.equal(bad.status, 3);
      assert.match(bad.stderr, /exec: a list of words/);
    } finally {
      monitor.kill();
      fs.closeSync(log);
      try { process.kill(Number(pid)); } catch (e) {}
    }
  });

  // A file you chose to save, or a copy put there: a new file yours alone,
  // never one left readable by others with your words in it (as cp or a save
  // over a 644 file would leave it); a link there replaced, never followed.
  check("save and place: yours alone, over a file that was open to others too", () => {
    const d = fs.mkdtempSync(path.join(tmp, "save-"));
    const mode = (p) => fs.lstatSync(p).mode & 0o777;
    const pub = path.join(d, "public.ics");
    fs.writeFileSync(pub, "old"); fs.chmodSync(pub, 0o644);
    let r = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "save", pub], { input: "BEGIN:VCALENDAR secret", encoding: "utf8" });
    assert.equal(r.status, 0, r.stderr);
    assert.equal(fs.readFileSync(pub, "utf8"), "BEGIN:VCALENDAR secret");
    assert.equal(mode(pub), 0o600, "a 644 file replaced, now 600");
    const target = path.join(d, "target"); fs.writeFileSync(target, "T"); fs.chmodSync(target, 0o644);
    const link = path.join(d, "link"); fs.symlinkSync(target, link);
    r = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "save", link], { input: "x", encoding: "utf8" });
    assert.equal(r.status, 0, r.stderr);
    assert.ok(fs.lstatSync(link).isFile() && fs.readFileSync(target, "utf8") === "T", "the link replaced, never written through");
    const made = path.join(d, "made.pdf"); fs.writeFileSync(made, "PDF");
    const old = path.join(d, "old.pdf"); fs.writeFileSync(old, "was"); fs.chmodSync(old, 0o644);
    r = helperRun(["place", made, old, "keep"]);
    assert.equal(r.code, 3, "keep: never over a file that's there");
    assert.equal(fs.readFileSync(old, "utf8"), "was");
    r = helperRun(["place", made, old, "replace"]);
    assert.equal(r.code, 0, r.err);
    assert.equal(fs.readFileSync(old, "utf8"), "PDF");
    assert.equal(mode(old), 0o600);
    r = helperRun(["place", made, path.join(d, "new.pdf"), "keep"]);
    assert.equal(r.code, 0, r.err);
    assert.equal(mode(path.join(d, "new.pdf")), 0o600);
    assert.ok(!fs.readdirSync(d).some((n) => n.startsWith(".uber-notebook-new")), "nothing half-made left");
    assert.equal(helperRun(["place", d, path.join(d, "x"), "replace"]).code, 3, "only a plain file is copied");
  });

  // A file you chose to save on a drive that can't keep files private: saved
  // as you asked, and said ("open"), whether the drive takes the chmod and
  // keeps its modes (exFAT) or refuses it (a phone, through gvfs). Your
  // notes' own (the Markdown copy, looked at with probe) still aren't kept
  // there.
  check("save and place on a drive that can't keep files private: saved, said", () => {
    const { helperOn } = require("./drive.cjs");
    for (const drive of ["exfat", "refuses"]) {
      const d = fs.mkdtempSync(path.join(tmp, "open-drive-"));
      const out = path.join(d, "Calendar.ics");
      let r = helperOn(drive, ["save", out], "BEGIN:VCALENDAR");
      assert.equal(r.code, 0, drive + ": " + r.err);
      assert.deepEqual(r.out.split("\n"), [out, "open", ""], drive);
      assert.equal(fs.readFileSync(out, "utf8"), "BEGIN:VCALENDAR", drive);
      const made = path.join(tmp, "made-" + drive + ".png"); fs.writeFileSync(made, "PNG");
      const copy = path.join(d, "Picture.png"); fs.writeFileSync(copy, "old");
      r = helperOn(drive, ["place", made, copy, "replace"]);
      assert.equal(r.code, 0, drive + ": " + r.err);
      assert.deepEqual(r.out.split("\n"), [copy, "open", ""], drive);
      assert.equal(fs.readFileSync(copy, "utf8"), "PNG", drive);
      r = helperOn(drive, ["place", made, path.join(d, "New.png"), "keep"]);
      assert.equal(r.code, 0, drive + ": " + r.err);
      assert.deepEqual(r.out.split("\n"), [path.join(d, "New.png"), "open", ""], drive);
      assert.ok(!fs.readdirSync(d).some((n) => n.startsWith(".uber-notebook-")), drive + ": nothing half-made left");
      // (The Markdown copy's check: never "keeps" there.)
      // (A drive that refuses the change too: it's said not to keep them,
      // not that the check failed.)
      const p = helperOn(drive, ["probe", d]);
      assert.equal(p.code, 0, drive + ": " + p.err);
      assert.equal(JSON.parse(p.out).keeps, false, drive);
      assert.ok(!fs.readdirSync(d).some((n) => n.startsWith(".uber-notebook-probe")), drive + ": its probe taken away");
      // (Nor does making a copy's own files private say they are.)
      const mp = helperOn(drive, ["make-private", d], JSON.stringify(["Picture.png"]));
      assert.equal(mp.code, 0, drive + ": " + mp.err);
      assert.equal(JSON.parse(mp.out).keeps, false, drive);
      assert.ok(!fs.readdirSync(d).some((n) => n.startsWith(".uber-notebook-probe")), drive + ": its probe taken away");
    }
  });

  // The Markdown copy's own files and folders from before made yours alone:
  // what's named and everything in it, never through a link, nothing else
  // in your folder, nor the folder itself.
  check("make-private: the copy's own, all of it, nothing else", () => {
    const v = fs.mkdtempSync(path.join(tmp, "copy-"));
    const out = fs.mkdtempSync(path.join(tmp, "elsewhere-"));
    const mode = (p) => fs.lstatSync(p).mode & 0o777;
    for (const dir of ["Pages", "Notebooks/Trip/assets", "mine"]) fs.mkdirSync(path.join(v, dir), { recursive: true });
    fs.writeFileSync(path.join(v, "Pages", "A.md"), "a");
    fs.writeFileSync(path.join(v, "Notebooks", "Trip", "assets", "pic.png"), "p");
    fs.writeFileSync(path.join(v, "mine", "x.md"), "m");
    fs.writeFileSync(path.join(out, "o.md"), "o");
    fs.symlinkSync(out, path.join(v, "Notebooks", "link"));
    for (const p of [v, path.join(v, "Pages"), path.join(v, "Notebooks"), path.join(v, "Notebooks", "Trip"), path.join(v, "Notebooks", "Trip", "assets"), path.join(v, "mine"), out]) fs.chmodSync(p, 0o755);
    for (const p of [path.join(v, "Pages", "A.md"), path.join(v, "Notebooks", "Trip", "assets", "pic.png"), path.join(v, "mine", "x.md"), path.join(out, "o.md")]) fs.chmodSync(p, 0o644);
    const r = spawnSync("/usr/bin/python3", ["-I", "-S", helper, "make-private", v], { input: JSON.stringify(["Pages", "Notebooks", "sketches", "../x", "/etc"]), encoding: "utf8" });
    assert.equal(r.status, 0, r.stderr);
    assert.deepEqual(JSON.parse(r.stdout), { ok: true, changed: 6, left: 0, keeps: true }, "Pages, A.md, Notebooks, Trip, assets, pic.png; the drive keeps files private");
    assert.ok(!fs.readdirSync(v).some((n) => n.startsWith(".uber-notebook-probe")), "its probe taken away");
    // The drive looked at alone (every copy): it keeps files private, and which folder it is.
    const pr = helperRun(["probe", v]);
    assert.equal(pr.code, 0, pr.err);
    const st = fs.statSync(v);
    assert.deepEqual(JSON.parse(pr.out), { keeps: true, id: st.dev + ":" + st.ino });
    assert.ok(!fs.readdirSync(v).some((n) => n.startsWith(".uber-notebook-probe")));
    assert.equal(helperRun(["probe", "/usr/share"]).code, 3, "a folder that isn't yours");
    assert.equal(mode(path.join(v, "Pages", "A.md")), 0o600);
    assert.equal(mode(path.join(v, "Notebooks", "Trip", "assets", "pic.png")), 0o600, "its pictures too");
    assert.equal(mode(path.join(v, "Notebooks", "Trip", "assets")), 0o700, "its folders too");
    assert.equal(mode(v), 0o755, "the folder you chose, as it was");
    assert.equal(mode(path.join(v, "mine", "x.md")), 0o644, "nothing else in it");
    assert.equal(mode(path.join(out, "o.md")), 0o644, "never through a link");
  });

  // A link's host looked up: its name on the input; only a host name.
  check("lookup: a host name on its input, nothing else", () => {
    const look = (host) => spawnSync("/usr/bin/python3", ["-I", "-S", helper, "lookup"], { input: host, encoding: "utf8" });
    const local = look("localhost");
    assert.equal(local.status, 0, local.stderr);
    assert.ok(/^(127\.0\.0\.1|::1)$/m.test(local.stdout), local.stdout);
    for (const bad of ["", "bad host", "a;b", "-x", "a".repeat(300), "x\ny"]) {
      const r = look(bad);
      assert.equal(r.status, 3, JSON.stringify(bad));
      assert.equal(r.stdout, "");
    }
  });
} finally {
  fs.rmSync(tmp, { recursive: true, force: true });
}

console.log(`files: ${passed} checks passed`);
