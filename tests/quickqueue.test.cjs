// QuickQueue.js: quick notes waiting for Pages, each kept to its profile.
const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");
const Q = load("QuickQueue.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

check("a quick note waits with its profile, and is only ever written into it", () => {
  let list = Q.add([], "Milk", "/home/u/Notes/A");
  list = Q.add(list, "Call Sam", "/home/u/Notes/A");
  list = Q.add(list, "Other's", "/home/u/Notes/B");
  const inB = plain(Q.take(list, "/home/u/Notes/B"));
  assert.deepEqual(inB.mine, ["Other's"], "B takes only its own");
  assert.deepEqual(inB.rest.map((e) => e.text), ["Milk", "Call Sam"], "A's kept for A");
  const inA = plain(Q.take(inB.rest, "/home/u/Notes/A"));
  assert.deepEqual([inA.mine, inA.rest], [["Milk", "Call Sam"], []]);
  assert.deepEqual(plain(Q.take(Q.add([], "x", ""), "/home/u/Notes/A")), { mine: [], rest: [] }, "one with no profile: nowhere");
});

check("flushed: written, or kept (never let go of before it's written)", () => {
  let q = Q.add(Q.add(Q.add([], "one", "/a"), "two", "/a"), "other", "/b");
  const tried = [];
  // Its profile still loading: none written, all kept, under their folder.
  q = Q.flush(q, "/a", (t) => { tried.push(t); return false; });
  assert.deepEqual(tried, ["one", "two"]);
  assert.deepEqual(plain(Q.take(q, "/a").mine), ["one", "two"], "kept, to try again");
  assert.deepEqual(plain(Q.take(q, "/b").mine), ["other"], "another profile's, as it was");
  // Then written: gone from the queue, once each.
  const written = [];
  q = Q.flush(q, "/a", (t) => { written.push(t); return true; });
  assert.deepEqual(written, ["one", "two"]);
  assert.deepEqual(plain(Q.take(q, "/a").mine), []);
  assert.deepEqual(plain(Q.take(q, "/b").mine), ["other"]);
  // One written, one not: only that one kept.
  q = Q.flush(Q.add(Q.add([], "x", "/a"), "y", "/a"), "/a", (t) => t === "x");
  assert.deepEqual(plain(Q.take(q, "/a").mine), ["y"]);
  // No folder open: nothing tried, nothing lost.
  q = Q.flush(Q.add([], "z", "/a"), "", () => { throw new Error("not tried"); });
  assert.deepEqual(plain(Q.take(q, "/a").mine), ["z"]);
});

console.log(`quickqueue: ${passed} checks passed`);
