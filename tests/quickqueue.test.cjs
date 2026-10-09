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

// The open profile and its notes folder, as Service.qml hands them over:
// Work's folder open and read.
const HOME = "/home/u";
function state(o) {
  return Object.assign({ profile: "p-work", folder: "~/Notes/Work", home: HOME, rootPath: HOME + "/Notes/Work", switching: false, ready: true, blockedFolder: "" }, o || {});
}

check("a quick note is written once its profile's folder is the one open and read", () => {
  assert.equal(Q.openProfile(state()), "p-work");
  assert.equal(Q.now(state()), "write");
  // The default place: in Documents, or the home folder when there's none.
  assert.equal(Q.openProfile(state({ folder: "", rootPath: HOME + "/Documents/Uber Notebook" })), "p-work");
  assert.equal(Q.openProfile(state({ folder: "", rootPath: HOME + "/Uber Notebook" })), "p-work");
  assert.equal(Q.openProfile(state({ folder: "/data/Work", rootPath: "/data/Work" })), "p-work", "a full path");
});

check("right after a profile switch, or while it's opening: kept for it, not written, not refused", () => {
  // `profile Work && quick "Call Bob"`: the one before still open a moment.
  const switching = state({ switching: true, ready: false, rootPath: HOME + "/Notes/Personal" });
  assert.equal(Q.openProfile(switching), "", "never into the one being left");
  assert.equal(Q.now(switching), "wait");
  // Its folder being made and checked (none open yet), or read.
  assert.equal(Q.now(state({ rootPath: "", ready: false })), "wait");
  assert.equal(Q.now(state({ ready: false })), "wait");
  // Another profile's folder still there (one that finished opening just
  // after the switch): not this one's.
  const other = state({ rootPath: HOME + "/Notes/Personal" });
  assert.equal(Q.openProfile(other), "");
  assert.equal(Q.now(other), "wait");
});

check("refused only when its folder can't be used, or there's no profile known yet", () => {
  const blocked = state({ rootPath: "", ready: false, blockedFolder: HOME + "/Notes/Work" });
  assert.equal(Q.blocked(blocked), true);
  assert.equal(Q.now(blocked), "refuse");
  assert.equal(Q.now(state({ rootPath: "", ready: false, folder: "", blockedFolder: HOME + "/Documents/Uber Notebook" })), "refuse", "the default place");
  // The one left a moment ago was the one that couldn't be used: this one's
  // being opened, so it's kept for it.
  const left = state({ rootPath: "", ready: false, blockedFolder: HOME + "/Notes/Personal" });
  assert.equal(Q.blocked(left), false);
  assert.equal(Q.now(left), "wait");
  assert.equal(Q.now(state({ profile: "" })), "refuse", "the shell just started: no profile known");
  assert.equal(Q.now(null), "refuse");
});

check("waiting with its profile's id: the same through a new folder, never in another profile", () => {
  // Made right after switching to Work; Personal opens again before Work does.
  let q = Q.add([], "Call Bob", "p-work");
  const personal = Q.openProfile(state({ profile: "p-personal", folder: "~/Notes/Personal", rootPath: HOME + "/Notes/Personal" }));
  assert.equal(personal, "p-personal");
  q = Q.flush(q, personal, () => { throw new Error("not into Personal"); });
  assert.deepEqual(plain(Q.take(q, "p-work").mine), ["Call Bob"]);
  // Work's folder couldn't be used, another picked for it: there, once open.
  const work = Q.openProfile(state({ folder: "~/Private/Work", rootPath: HOME + "/Private/Work" }));
  const written = [];
  q = Q.flush(q, work, (t) => { written.push(t); return true; });
  assert.deepEqual(written, ["Call Bob"]);
  assert.deepEqual(plain(q), []);
});

console.log(`quickqueue: ${passed} checks passed`);
