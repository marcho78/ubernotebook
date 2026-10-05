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

console.log(`quickqueue: ${passed} checks passed`);
