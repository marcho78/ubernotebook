// Checks meetings in Pages: what's kept, voxtype's export, list and state
// file read, turns, text and Markdown.
// Usage (from the plugin directory): node tests/meeting.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const M = load("Meeting.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const ID = "3f2a9c1e-7b4d-4e2a-9f1c-2b3c4d5e6f70";
const exported = {
  metadata: { id: ID, title: "Weekly sync", startedAt: "2026-10-02T09:30:00+00:00", endedAt: "2026-10-02T10:00:30+00:00", durationSecs: 1830, status: "completed", chunkCount: 61 },
  transcript: {
    segments: [
      { id: 0, startMs: 1200, endMs: 5400, text: " Morning, everyone.", source: "microphone", speaker: "You", chunkId: 0 },
      { id: 1, startMs: 5600, endMs: 9000, text: "Let's start with the release.", source: "microphone", speaker: "You", chunkId: 0 },
      { id: 2, startMs: 10000, endMs: 15000, text: "The notes are done.", source: "loopback", speaker: "Remote", chunkId: 0 },
      { id: 3, startMs: 16000, endMs: 18000, text: "   ", source: "loopback", speaker: "Remote", chunkId: 1 },
      { id: 4, startMs: 40000, endMs: 42000, text: "Great.", source: "microphone", chunkId: 1 },
    ],
    totalChunks: 61, wordCount: 13, durationMs: 1830000, speakers: ["You", "Remote"],
  },
};

check("what's kept", () => {
  assert.deepEqual(plain(M.make()), { id: "", title: "", startedAt: "", duration: 0, segments: [], names: {}, open: true, color: "", background: "" });
  assert.equal(M.clean(null), null);
  const m = plain(M.clean({ id: ID.toUpperCase(), title: "  Sync\n", startedAt: "nope", duration: -4, segments: [{ start: 5, end: 1, speaker: "", text: "hi\u0000there" }, { text: "" }, 7],
    names: { Remote: "Sam", You: "You", x: "" }, open: false, color: "blue", background: "#FF8800" }));
  assert.equal(m.id, ID);
  assert.equal(m.title, "Sync");
  assert.equal(m.startedAt, "");
  assert.equal(m.duration, 0);
  assert.deepEqual(m.segments, [{ start: 5, end: 5, speaker: "You", text: "hi there" }]);
  assert.deepEqual(m.names, { Remote: "Sam" }, "only names that are names");
  assert.equal(m.open, false);
  assert.equal(m.background, "#ff8800");
  assert.equal(M.clean({ id: "../../etc" }).id, "", "only an id");
});

check("voxtype's export", () => {
  const m = plain(M.fromExport(JSON.stringify(exported), { names: { Remote: "Sam" }, color: "green" }));
  assert.equal(m.id, ID);
  assert.equal(m.title, "Weekly sync");
  assert.equal(m.startedAt, "2026-10-02T09:30:00.000Z");
  assert.equal(m.duration, 1830);
  assert.equal(m.segments.length, 4, "not what's empty");
  assert.equal(m.segments[0].text, "Morning, everyone.");
  assert.equal(m.segments[3].speaker, "You", "from the microphone, with no speaker: You");
  assert.deepEqual(m.names, { Remote: "Sam" }, "its names kept");
  assert.equal(m.color, "green");
  assert.equal(M.fromExport("not json"), null);
  assert.equal(M.fromExport("{}"), null);
});

check("turns, names, text and Markdown", () => {
  const m = M.fromExport(exported, { names: { Remote: "Sam" } });
  const t = plain(M.turns(m));
  assert.deepEqual(t.map((x) => x.speaker), ["You", "Remote", "You"], "a speaker's words one after another, one turn");
  assert.equal(t[0].text, "Morning, everyone. Let's start with the release.");
  assert.deepEqual(plain(M.speakers(m)), ["You", "Remote"]);
  assert.equal(M.speakerName(m, "Remote"), "Sam");
  assert.equal(M.speakerName(m, "SPEAKER_01"), "Speaker 2");
  assert.equal(M.text(m).split("\n")[1], "Sam (0:10): The notes are done.");
  assert.equal(M.wordCount(m), 12);
  const md = M.toMarkdown(m);
  assert.ok(md.startsWith("**\u{1f465} Weekly sync** \u00b7 30:30"), md);
  assert.match(md, /\*\*Sam\*\* \(0:10\): The notes are done\./);
  assert.match(M.toMarkdown(M.clean({ id: ID, title: "Later" })), /nothing was written out yet/);
});

check("voxtype's state file and list", () => {
  assert.deepEqual(plain(M.parseState("recording\n" + ID + "\n")), { status: "recording", id: ID });
  assert.deepEqual(plain(M.parseState("paused\n" + ID)), { status: "paused", id: ID });
  assert.deepEqual(plain(M.parseState("")), { status: "idle", id: "" });
  assert.deepEqual(plain(M.parseState("weird")), { status: "idle", id: "" });
  const list = `Recent Meetings
===============

Weekly sync
  ID: ${ID}
  Date: 2026-10-02 09:30
  Duration: 30m 30s
  Status: Completed

Meeting 2026-10-01 14:00
  ID: 11111111-2222-3333-4444-555555555555
  Date: 2026-10-01 14:00
  Duration: 5m 2s
  Status: Completed
`;
  const l = plain(M.parseList(list));
  assert.equal(l.length, 2);
  assert.deepEqual(l[0], { id: ID, title: "Weekly sync", date: "2026-10-02 09:30", duration: "30m 30s", status: "Completed" });
  assert.equal(l[1].title, "Meeting 2026-10-01 14:00");
  assert.deepEqual(plain(M.parseList("No meetings found.")), []);
});

console.log(`meeting: ${passed} checks passed`);
