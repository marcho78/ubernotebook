// Checks emoji found by name after ":" in Pages.
// Usage (from the plugin directory): node tests/emoji.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const Emoji = load("Emoji.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("by name", () => {
  assert.equal(Emoji.exact("rocket"), "\u{1f680}");
  assert.equal(Emoji.exact("+1"), "\u{1f44d}");
  assert.equal(Emoji.exact("thumbsup"), "\u{1f44d}", "other names too");
  assert.equal(Emoji.exact("Tada"), "\u{1f389}");
  assert.equal(Emoji.exact("heart"), "❤️");
  assert.equal(Emoji.exact("rock"), "", "only a whole name");
  assert.equal(Emoji.exact(""), "");
});

check("found as you type", () => {
  const codes = (q) => plain(Emoji.find(q, 8)).map((e) => e.code);
  assert.equal(codes("rocket")[0], "rocket", "the name itself first");
  assert.equal(codes("sm")[0], "smile");
  assert.equal(codes("ta")[0], "tada", "the ones people use most first");
  const popular = plain(Emoji.POPULAR);
  for (const name of popular) assert.ok(Emoji.exact(name), "a name on the list: " + name);
  assert.ok(codes("check").includes("white_check_mark"), "a part of a name");
  assert.ok(codes("thumbs").includes("thumbsup"), "with the name that matched");
  assert.equal(plain(Emoji.find("done", 8))[0].code, "white_check_mark", "and other words");
  assert.ok(codes("sm").length <= 8);
  assert.deepEqual(plain(Emoji.find("zzzzqq", 8)), []);
  assert.deepEqual(plain(Emoji.find("a b", 8)), [], "no spaces");
  assert.deepEqual(plain(Emoji.find("", 8)), []);
});

check("the list", () => {
  const seen = new Set();
  for (const [names, emoji] of plain(Emoji.LIST)) {
    for (const n of names.split(" ")) {
      assert.ok(Emoji.isQuery(n), n);
      assert.ok(!seen.has(n), "one emoji per name: " + n);
      seen.add(n);
    }
    assert.ok(emoji.length > 0 && !/[\s<>&]/.test(emoji), names);
  }
  assert.ok(seen.size > 500);
});

console.log(`emoji: ${passed} checks passed`);
