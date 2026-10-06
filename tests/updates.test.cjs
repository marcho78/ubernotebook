// Checks the update check (Updates.js): versions compared, the repository
// from the homepage, GitHub's answer read (drafts and pre-releases left
// out), the newer ones and their notes (no pictures or HTML), and the
// version running's notes from CHANGELOG.md.
// Usage (from the plugin directory): node tests/updates.test.cjs

const assert = require("node:assert/strict");
const fs = require("node:fs");
const path = require("node:path");
const { load, plain, root } = require("./load.cjs");

const U = load("Updates.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("versions compared", () => {
  assert.equal(U.compare("1.0.1", "1.0.0"), 1);
  assert.equal(U.compare("v1.2", "1.2.0"), 0);
  assert.equal(U.compare("1.10.0", "1.9.9"), 1, "numbers, not letters");
  assert.equal(U.compare("2.0.0-beta.2", "2.0.0-beta.10"), -1);
  assert.equal(U.compare("2.0.0-beta", "2.0.0"), -1, "a pre-release comes before");
  assert.equal(U.compare("2.0.0-alpha", "2.0.0-alpha.1"), -1);
  assert.equal(U.compare("2.0.0-1", "2.0.0-alpha"), -1, "numbers before words");
  assert.equal(U.compare("1.0.0+build.5", "1.0.0"), 0, "build data doesn't count");
  assert.equal(U.compare("nonsense", "1.0.0"), -1);
  assert.equal(U.parse("1.0.0.0"), null);
});

check("the repository, from the homepage", () => {
  assert.equal(U.repoOf("https://github.com/marcho78/ubernotebook"), "marcho78/ubernotebook");
  assert.equal(U.repoOf("https://github.com/marcho78/ubernotebook.git"), "marcho78/ubernotebook");
  assert.equal(U.repoOf("https://github.com/marcho78/ubernotebook/"), "marcho78/ubernotebook");
  assert.equal(U.repoOf("http://github.com/a/b"), "", "https only");
  assert.equal(U.repoOf("https://gitlab.com/a/b"), "");
  assert.equal(U.repoOf("https://github.com/a/b/../../x"), "");
  assert.equal(U.releasesUrl("a/b"), "https://api.github.com/repos/a/b/releases?per_page=30");
});

check("GitHub's answer", () => {
  assert.deepEqual(plain(U.response("[]\n200")), { code: 200, body: "[]" });
  assert.deepEqual(plain(U.response("{\"message\":\"Not Found\"}\n404")), { code: 404, body: "{\"message\":\"Not Found\"}" });
  assert.equal(U.response("").code, 0);
  const list = plain(U.releases(JSON.stringify([
    { tag_name: "v1.1.0", name: "Spring", body: "Better **search**.\n\n![shot](https://x.example/a.png)\n<img src=\"https://x.example/b.png\">\n<!-- hidden -->\nDone.", html_url: "https://github.com/a/b/releases/tag/v1.1.0", published_at: "2026-11-01T10:00:00Z" },
    { tag_name: "v1.3.0-beta.1", prerelease: true, body: "beta" },
    { tag_name: "v1.2.0", name: "v1.2.0", body: "", html_url: "javascript:alert(1)", published_at: "2026-12-01T10:00:00Z" },
    { tag_name: "v2.0.0", draft: true },
    { tag_name: "nightly" },
    { tag_name: "1.0.0", body: "First" },
    null
  ])));
  assert.deepEqual(list.map((r) => r.version), ["1.2.0", "1.1.0", "1.0.0"], "published, not pre-releases, newest first");
  assert.equal(list[1].notes, "Better **search**.\n\nDone.", "no pictures, no HTML");
  assert.equal(list[0].url, "", "only GitHub's own links");
  assert.equal(list[1].url, "https://github.com/a/b/releases/tag/v1.1.0");
  assert.equal(U.releases("{\"message\":\"Not Found\"}"), null, "not a list");
  assert.equal(U.releases("nope"), null);
  const newer = plain(U.newer(list, "1.0.0"));
  assert.deepEqual(newer.map((r) => r.version), ["1.2.0", "1.1.0"]);
  assert.deepEqual(plain(U.newer(list, "1.2.0")), [], "up to date");
  assert.deepEqual(plain(U.newer(list, "1.5.0")), [], "newer than any: up to date");
  const md = U.combined(newer);
  assert.equal(md, "### Version 1.2.0 (2026-12-01)\n\nNo notes for this release.\n\n### Spring (2026-11-01)\n\nBetter **search**.\n\nDone.");
  assert.equal(U.combined(newer.slice(1)), "Better **search**.\n\nDone.", "one: its notes (the title says which)");
  assert.ok(U.cleanNotes("x".repeat(30000)).length < 20010, "not too long");
});

check("the version running's notes, from CHANGELOG.md", () => {
  const text = "# Changelog\n\nIntro.\n\n## 1.1.0 - 2026-11-01\n\n### Added\n\n- New thing\n\n## 1.0.0 - Unreleased\n\nThe first version.\n\n### Added\n\n- **Shelf.** Notebooks.\n";
  assert.deepEqual(plain(U.fromChangelog(text, "1.1.0")), { title: "1.1.0 — 2026-11-01", notes: "### Added\n\n- New thing" });
  assert.deepEqual(plain(U.fromChangelog(text, "1.0.0")), { title: "1.0.0 — Unreleased", notes: "The first version.\n\n### Added\n\n- **Shelf.** Notebooks." }, "the last one, to the end");
  assert.equal(U.fromChangelog(text, "9.9.9"), null);
  // The real one has the version in the manifest.
  const manifest = JSON.parse(fs.readFileSync(path.join(root, "manifest.json"), "utf8"));
  const real = U.fromChangelog(fs.readFileSync(path.join(root, "CHANGELOG.md"), "utf8"), manifest.version);
  assert.ok(real && real.notes.length > 200, "CHANGELOG.md has notes for " + manifest.version);
});

console.log(`updates: ${passed} checks passed`);
