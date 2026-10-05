// Checks the Markdown copy: file names and the tree, links between files,
// what's written and what goes, and the folders it may use.
// Usage (from the plugin directory): node tests/mirror.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const M = load("Mirror.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("names", () => {
  assert.equal(M.safeName("Plans: 2026/27?"), "Plans 2026 27");
  assert.equal(M.safeName("..hidden"), "hidden", "never a hidden file");
  assert.equal(M.safeName("  "), "Untitled");
  assert.equal(M.safeName("", "Notebook"), "Notebook");
  assert.equal(M.safeName("x".repeat(200)).length, 80);
});

check("Pages' tree as files", () => {
  const index = { top: ["a", "b", "c", "t"], pages: {
    a: { title: "Plans", children: ["a1", "a2"] }, a1: { title: "Trip", children: [] }, a2: { title: "trip", children: ["a21"] },
    a21: { title: "Day 1", children: [] }, b: { title: "Plans", children: [] }, c: { title: "", children: [] },
    t: { title: "Old", trashed: true, children: ["t1"] }, t1: { title: "Inside old", children: [] } } };
  assert.deepEqual(plain(M.pagePaths(index)), {
    a: "Pages/Plans.md", a1: "Pages/Plans/Trip.md", a2: "Pages/Plans/trip 2.md", a21: "Pages/Plans/trip 2/Day 1.md",
    b: "Pages/Plans 2.md", c: "Pages/Untitled.md"
  }, "a page's pages in its folder, one name once (whatever its case), the trash left out");
  assert.deepEqual(plain(M.notebookDirs([{ id: "x", title: "Recipes" }, { id: "y", title: "recipes" }])).map((d) => d.dir), ["Notebooks/Recipes", "Notebooks/recipes 2"]);
  assert.equal(M.notebookFile("Notebooks/Recipes", 4, "Soup.md"), "Notebooks/Recipes/005 Soup.md");
});

check("links and the way to the top", () => {
  assert.equal(M.relative("Pages/A.md", "Pages/B c.md"), "B%20c.md");
  assert.equal(M.relative("Pages/A/B.md", "Pages/C.md"), "../C.md");
  assert.equal(M.relative("Pages/A.md", "Pages/A/B (1).md"), "A/B%20%281%29.md", "brackets too, so the link holds");
  assert.equal(M.relative("Pages/A/B.md", "sketches/x.svg"), "../../sketches/x.svg");
  assert.equal(M.toTop("Pages/A/B.md"), "../../");
  assert.equal(M.toTop("x.md"), "");
});

check("a file of yours is never taken", () => {
  const paths = { a: "Pages/Notes.md", b: "Pages/Mine.md", c: "Pages/Ours.md" };
  M.claim(paths, { "Pages/Ours.md": "h" }, { "Pages/Notes.md": true, "Pages/Notes (2).md": true, "Pages/Ours.md": true });
  assert.deepEqual(paths, { a: "Pages/Notes (3).md", b: "Pages/Mine.md", c: "Pages/Ours.md" });
});

check("what's written, and what goes", () => {
  const desired = { "Pages/A.md": "# A\n", "Pages/B.md": "# B\n", "sketches/s.svg": "<svg/>" };
  const manifest = { "Pages/A.md": M.hash("# A\n"), "Pages/B.md": M.hash("# old\n"), "Pages/Gone.md": M.hash("x") };
  const existing = { "Pages/A.md": true, "Pages/B.md": true, "Pages/Gone.md": true, "notes.txt": true };
  assert.deepEqual(plain(M.plan(manifest, desired, existing)), { write: ["Pages/B.md", "sketches/s.svg"], remove: ["Pages/Gone.md"] },
    "only what changed or is new; only its own files go");
  assert.deepEqual(plain(M.plan(M.manifestOf(desired), desired, { "Pages/A.md": true, "Pages/B.md": true })).write, ["sketches/s.svg"], "a file taken away from the folder comes back");
  assert.notEqual(M.hash("a"), M.hash("b"));
  assert.equal(M.hash("same"), M.hash("same"));
  assert.deepEqual(plain(M.cleanManifest({ files: { "Pages/A.md": "h", "../etc/passwd.md": "h", "Pages/../x.md": "h", "notes.txt": "h", "Pages/B.md": 3 } })), { "Pages/A.md": "h" },
    "a manifest can't make it touch anything else");
});

check("folders it may use", () => {
  const root = "/home/u/Documents/Uber Notebook";
  assert.equal(M.folderProblem(root + "/Markdown", root, "/home/u", ["recipes-ab12"]), "");
  assert.equal(M.folderProblem("/home/u/Obsidian/Notes", root, "/home/u", []), "");
  assert.ok(M.folderProblem("/home/u", root, "/home/u", []), "not home");
  assert.ok(M.folderProblem("/", root, "/home/u", []));
  assert.ok(M.folderProblem(root, root, "/home/u", []), "not the notes folder");
  assert.ok(M.folderProblem("/home/u/Documents", root, "/home/u", []), "not a folder it's in");
  assert.ok(M.folderProblem(root + "/Pages", root, "/home/u", []), "not Pages");
  assert.ok(M.folderProblem(root + "/recipes-ab12/x", root, "/home/u", ["recipes-ab12"]), "not a notebook's folder");
  assert.ok(M.folderProblem("relative/path", root, "/home/u", []));
});

check("fingerprints: SHA-256 of the bytes it writes; one from before is never a match", () => {
  const crypto = require("node:crypto");
  for (const t of ["", "# A\n", "\u00e9t\u00e9 \u2713 \u{1f600}\n", "x".repeat(100000)]) {
    assert.equal(M.hash(t), "s256:" + crypto.createHash("sha256").update(Buffer.from(t, "utf8")).digest("hex"), JSON.stringify(t.slice(0, 10)));
  }
  assert.ok(M.isHash(M.hash("a")));
  assert.ok(!M.isHash("57c663da:17"), "the short one from before");
  // The pair Codex found colliding under the old fingerprint: apart now.
  assert.notEqual(M.hash("note r&BZFY4*]Iqg"), M.hash("note 8st(xi`)#Y5;"));
  // A file listed with an old fingerprint is written again (the files helper
  // then takes it as the copy's only if it's exactly what it would write).
  const todo = M.plan({ "Pages/A.md": "0000abcd:4" }, { "Pages/A.md": "# A\n" }, { "Pages/A.md": true });
  assert.deepEqual(plain(todo.write), ["Pages/A.md"]);
  // With the fingerprints Mirror.qml keeps: the same.
  let asked = 0;
  const cached = M.plan({ "Pages/A.md": M.hash("# A\n") }, { "Pages/A.md": "# A\n" }, { "Pages/A.md": true }, (p, t) => { asked++; return M.hash(t); });
  assert.deepEqual([plain(cached.write), asked], [[], 1]);
});

check("a page whose file you took: its copy beside it, at the same name sync after sync", () => {
  const existing = { "Pages/A.md": true };
  const first = plain(M.claim({ a: "Pages/A.md" }, {}, existing));
  assert.deepEqual(first, { a: "Pages/A (2).md" });
  // Written there: the copy's now. The next time, it stays there (not "(3)").
  const again = plain(M.claim({ a: "Pages/A.md" }, { "Pages/A (2).md": M.hash("x") }, { "Pages/A.md": true, "Pages/A (2).md": true }));
  assert.deepEqual(again, { a: "Pages/A (2).md" });
  // A "(2)" that's yours too: the next free one.
  assert.deepEqual(plain(M.claim({ a: "Pages/A.md" }, {}, { "Pages/A.md": true, "Pages/A (2).md": true })), { a: "Pages/A (3).md" });
});

console.log(`mirror: ${passed} checks passed`);
